import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef EventHandler = void Function(String kind, dynamic data);

class WsService {
  final String serverUrl;
  final String token;
  final EventHandler onEvent;

  WebSocketChannel? _channel;
  Timer? _pingTimer;
  bool _isDisposed = false;

  WsService({
    required this.serverUrl,
    required this.token,
    required this.onEvent,
  });

  void connect(int cursor) {
    if (_isDisposed) return;

    final wsScheme = serverUrl.startsWith('https') ? 'wss' : 'ws';
    final host = serverUrl.replaceFirst(RegExp(r'^https?://'), '');
    final uri = Uri.parse('$wsScheme://$host/api/v1/ws?token=$token&cursor=$cursor');

    try {
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        (data) {
          _handleMessage(data);
        },
        onError: (err) {
          _reconnect(cursor);
        },
        onDone: () {
          _reconnect(cursor);
        },
      );

      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (t) {
        sendPing();
      });
    } catch (e) {
      _reconnect(cursor);
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type = msg['t'] as String?;

      if (type == 'event') {
        final kind = msg['kind'] as String;
        final data = msg['data'];
        onEvent(kind, data);
      }
    } catch (_) {}
  }

  void sendTyping(String convId) {
    _sendJson({'t': 'typing', 'conv_id': convId});
  }

  void sendAck(int cursor) {
    _sendJson({'t': 'ack', 'cursor': cursor});
  }

  void sendPing() {
    _sendJson({'t': 'ping'});
  }

  void _sendJson(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {}
  }

  void _reconnect(int cursor) {
    if (_isDisposed) return;
    _channel?.sink.close();
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isDisposed) {
        connect(cursor);
      }
    });
  }

  void dispose() {
    _isDisposed = true;
    _pingTimer?.cancel();
    _channel?.sink.close();
  }
}
