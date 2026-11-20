package storage

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"image"
	"image/jpeg"
	"image/png"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/uuid"
	"github.com/uri-travoski/workchat/server/internal/db"
)

type Storage struct {
	dataDir  string
	filesDir string
	thumbDir string
}

func New(dataDir string) (*Storage, error) {
	filesDir := filepath.Join(dataDir, "files")
	thumbDir := filepath.Join(dataDir, "thumbs")

	if err := os.MkdirAll(filesDir, 0755); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(thumbDir, 0755); err != nil {
		return nil, err
	}

	return &Storage{
		dataDir:  dataDir,
		filesDir: filesDir,
		thumbDir: thumbDir,
	}, nil
}

func (s *Storage) SaveFile(database *db.DB, uploaderID, fileName, contentType string, r io.Reader) (*db.Attachment, error) {
	tempFile, err := os.CreateTemp(s.filesDir, "upload-*")
	if err != nil {
		return nil, err
	}
	defer os.Remove(tempFile.Name())
	defer tempFile.Close()

	hasher := sha256.New()
	tee := io.TeeReader(r, hasher)

	size, err := io.Copy(tempFile, tee)
	if err != nil {
		return nil, err
	}

	sha := hex.EncodeToString(hasher.Sum(nil))
	finalPath := filepath.Join(s.filesDir, sha)

	// Deduplication: if file with same sha exists, we reuse it!
	if _, err := os.Stat(finalPath); os.IsNotExist(err) {
		tempFile.Close()
		if err := os.Rename(tempFile.Name(), finalPath); err != nil {
			return nil, err
		}
	}

	attID := uuid.New().String()
	now := db.NowMs()

	// Generate thumbnail if image
	s.generateThumbnail(finalPath, attID, contentType)

	att := &db.Attachment{
		ID:          attID,
		UploaderID:  uploaderID,
		Name:        fileName,
		ContentType: contentType,
		Size:        size,
		Sha256:      sha,
		StorageKey:  sha,
		Purpose:     "file",
		CreatedMs:   now,
		Removed:     false,
	}

	query := `INSERT INTO attachments (id, uploader_id, name, content_type, size, sha256, storage_key, purpose, created_ms, removed)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)`

	_, err = database.Exec(query, att.ID, att.UploaderID, att.Name, att.ContentType, att.Size, att.Sha256, att.StorageKey, att.Purpose, att.CreatedMs)
	if err != nil {
		return nil, err
	}

	return att, nil
}

func (s *Storage) generateThumbnail(filePath, attID, contentType string) {
	if !strings.HasPrefix(contentType, "image/") {
		return
	}

	f, err := os.Open(filePath)
	if err != nil {
		return
	}
	defer f.Close()

	img, _, err := image.Decode(f)
	if err != nil {
		return
	}

	bounds := img.Bounds()
	w := bounds.Dx()
	h := bounds.Dy()
	if w <= 0 || h <= 0 {
		return
	}

	maxDim := 256
	thumbW, thumbH := maxDim, maxDim
	if w > h {
		thumbH = (h * maxDim) / w
	} else {
		thumbW = (w * maxDim) / h
	}

	thumbImg := image.NewRGBA(image.Rect(0, 0, thumbW, thumbH))
	for y := 0; y < thumbH; y++ {
		for x := 0; x < thumbW; x++ {
			srcX := (x * w) / thumbW
			srcY := (y * h) / thumbH
			thumbImg.Set(x, y, img.At(bounds.Min.X+srcX, bounds.Min.Y+srcY))
		}
	}

	outPath := filepath.Join(s.thumbDir, fmt.Sprintf("%s.png", attID))
	outFile, err := os.Create(outPath)
	if err != nil {
		return
	}
	defer outFile.Close()

	png.Encode(outFile, thumbImg)
}

func (s *Storage) GetFilePath(storageKey string) string {
	return filepath.Join(s.filesDir, storageKey)
}

func (s *Storage) GetThumbPath(attID string) string {
	return filepath.Join(s.thumbDir, fmt.Sprintf("%s.png", attID))
}

func (s *Storage) SaveAvatar(database *db.DB, userID string, r io.Reader) (string, error) {
	buf := new(bytes.Buffer)
	hasher := sha256.New()
	tee := io.TeeReader(r, io.MultiWriter(buf, hasher))

	img, format, err := image.Decode(tee)
	if err != nil {
		return "", fmt.Errorf("invalid image format: %w", err)
	}

	sha := hex.EncodeToString(hasher.Sum(nil))
	finalPath := filepath.Join(s.filesDir, sha)

	if _, err := os.Stat(finalPath); os.IsNotExist(err) {
		outFile, err := os.Create(finalPath)
		if err != nil {
			return "", err
		}
		defer outFile.Close()

		if format == "png" {
			png.Encode(outFile, img)
		} else {
			jpeg.Encode(outFile, img, &jpeg.Options{Quality: 90})
		}
	}

	attID := uuid.New().String()
	now := db.NowMs()
	mime := "image/jpeg"
	if format == "png" {
		mime = "image/png"
	}

	query := `INSERT INTO attachments (id, uploader_id, name, content_type, size, sha256, storage_key, purpose, created_ms, removed)
              VALUES (?, ?, ?, ?, ?, ?, ?, 'avatar', ?, 0)`

	_, err = database.Exec(query, attID, userID, "avatar."+format, mime, int64(buf.Len()), sha, sha, now)
	if err != nil {
		return "", err
	}

	// Update user avatar
	_, err = database.Exec("UPDATE users SET avatar_attachment = ? WHERE id = ?", attID, userID)
	if err != nil {
		return "", err
	}

	return attID, nil
}
