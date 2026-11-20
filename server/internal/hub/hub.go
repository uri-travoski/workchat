package hub

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/uri-travoski/workchat/server/internal/db"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for clients & admin web
	},
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
}

type Client struct {
	hub           *Hub
	conn          *websocket.Conn
	userID        string
	sessionID     string
	send          chan []byte
	clientVersion string
	cursor        int64
}

type Hub struct {
	mu         sync.RWMutex
	clients    map[*Client]bool
	userConns  map[string]map[*Client]bool
	presences  map[string]string // userID -> presence ("online", "away", "dnd", "offline")
	database   *db.DB
	register   chan *Client
	unregister chan *Client
}

func New(database *db.DB) *Hub {
	return &Hub{
		clients:    make(map[*Client]bool),
		userConns:  make(map[string]map[*Client]bool),
		presences:  make(map[string]string),
		database:   database,
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			if _, ok := h.userConns[client.userID]; !ok {
				h.userConns[client.userID] = make(map[*Client]bool)
			}
			h.userConns[client.userID][client] = true
			h.presences[client.userID] = "online"
			h.mu.Unlock()

			// Broadcast presence update
			go h.BroadcastPresence(client.userID, "online")

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
				if conns, exists := h.userConns[client.userID]; exists {
					delete(conns, client)
					if len(conns) == 0 {
						delete(h.userConns, client.userID)
						h.presences[client.userID] = "offline"
						go h.BroadcastPresence(client.userID, "offline")
					}
				}
			}
			h.mu.Unlock()
		}
	}
}

func (h *Hub) BroadcastPresence(userID, presence string) {
	evtData, _ := json.Marshal(map[string]string{
		"user_id":  userID,
		"presence": presence,
	})
	h.BroadcastAll("presence", string(evtData))
}

func (h *Hub) BroadcastAll(kind, data string) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	msg, _ := json.Marshal(map[string]interface{}{
		"t":    "event",
		"kind": kind,
		"data": json.RawMessage(data),
	})

	for client := range h.clients {
		select {
		case client.send <- msg:
		default:
		}
	}
}

// EmitEvent stores an event in the events table for the target user and delivers it to active WebSockets.
func (h *Hub) EmitEvent(targetUserID, kind, ref string, dataObj interface{}) (int64, error) {
	dataBytes, err := json.Marshal(dataObj)
	if err != nil {
		return 0, err
	}
	dataStr := string(dataBytes)
	now := db.NowMs()

	res, err := h.database.Exec("INSERT INTO events (user_id, ts, kind, ref, data) VALUES (?, ?, ?, ?, ?)",
		targetUserID, now, kind, ref, dataStr)
	if err != nil {
		return 0, err
	}

	eventID, err := res.LastInsertId()
	if err != nil {
		return 0, err
	}

	// Forward to connected user WebSockets
	h.mu.RLock()
	conns, exists := h.userConns[targetUserID]
	if exists {
		wsPayload, _ := json.Marshal(map[string]interface{}{
			"t":    "event",
			"id":   eventID,
			"kind": kind,
			"ref":  ref,
			"data": json.RawMessage(dataStr),
			"ts":   now,
		})
		for client := range conns {
			select {
			case client.send <- wsPayload:
			default:
			}
		}
	}
	h.mu.RUnlock()

	return eventID, nil
}

// EmitToMembers emits an event to all members of a conversation.
func (h *Hub) EmitToMembers(convID, kind, ref string, dataObj interface{}) error {
	rows, err := h.database.Query("SELECT user_id FROM members WHERE conv_id = ?", convID)
	if err != nil {
		return err
	}
	defer rows.Close()

	var userIDs []string
	for rows.Next() {
		var uid string
		if err := rows.Scan(&uid); err == nil {
			userIDs = append(userIDs, uid)
		}
	}

	for _, uid := range userIDs {
		h.EmitEvent(uid, kind, ref, dataObj)
	}
	return nil
}

// HandleWS upgrades HTTP connection to WebSocket and services reads/writes.
func (h *Hub) HandleWS(w http.ResponseWriter, r *http.Request, userID, sessionID string, initialCursor int64) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WS upgrade error: %v", err)
		return
	}

	client := &Client{
		hub:       h,
		conn:      conn,
		userID:    userID,
		sessionID: sessionID,
		send:      make(chan []byte, 256),
		cursor:    initialCursor,
	}

	h.register <- client

	// Deliver backlog events since cursor
	go h.deliverBacklog(client)

	go client.writePump()
	go client.readPump()
}

func (h *Hub) deliverBacklog(c *Client) {
	rows, err := h.database.Query("SELECT id, ts, kind, ref, data FROM events WHERE user_id = ? AND id > ? ORDER BY id ASC LIMIT 500",
		c.userID, c.cursor)
	if err != nil {
		return
	}
	defer rows.Close()

	for rows.Next() {
		var id, ts int64
		var kind, ref, data string
		if err := rows.Scan(&id, &ts, &kind, &ref, &data); err == nil {
			wsPayload, _ := json.Marshal(map[string]interface{}{
				"t":    "event",
				"id":   id,
				"kind": kind,
				"ref":  ref,
				"data": json.RawMessage(data),
				"ts":   ts,
			})
			select {
			case c.send <- wsPayload:
				c.cursor = id
			default:
				return
			}
		}
	}
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(1024 * 1024)
	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			break
		}

		var msg map[string]interface{}
		if err := json.Unmarshal(message, &msg); err == nil {
			msgType, _ := msg["t"].(string)
			switch msgType {
			case "ping":
				pong, _ := json.Marshal(map[string]string{"t": "pong"})
				c.send <- pong
			case "ack":
				if cursorFloat, ok := msg["cursor"].(float64); ok {
					c.cursor = int64(cursorFloat)
					c.hub.database.Exec("UPDATE users SET acked_cursor = ? WHERE id = ?", c.cursor, c.userID)
				}
			case "typing":
				if convID, ok := msg["conv_id"].(string); ok {
					c.broadcastTyping(convID)
				}
			case "idle":
				if isIdle, ok := msg["idle"].(bool); ok {
					presence := "online"
					if isIdle {
						presence = "away"
					}
					c.hub.BroadcastPresence(c.userID, presence)
				}
			}
		}
	}
}

func (c *Client) broadcastTyping(convID string) {
	rows, err := c.hub.database.Query("SELECT user_id FROM members WHERE conv_id = ? AND user_id != ?", convID, c.userID)
	if err != nil {
		return
	}
	defer rows.Close()

	typingMsg, _ := json.Marshal(map[string]interface{}{
		"t":       "typing",
		"conv_id": convID,
		"user_id": c.userID,
	})

	c.hub.mu.RLock()
	defer c.hub.mu.RUnlock()

	for rows.Next() {
		var uid string
		if err := rows.Scan(&uid); err == nil {
			if conns, exists := c.hub.userConns[uid]; exists {
				for client := range conns {
					select {
					case client.send <- typingMsg:
					default:
					}
				}
			}
		}
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(30 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)
			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
