import 'dart:async';
import 'dart:convert';

import 'package:tienda/core/app_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class LocalServerWebSocketClient {
  LocalServerWebSocketClient({Uri? endpoint})
      : _endpoint = endpoint ??
            Uri.parse(
                'ws://${AppConfig.serverHost}:${AppConfig.serverPort}/ws');

  final Uri _endpoint;
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> connect() async {
    if (_channel != null) return;
    final channel = WebSocketChannel.connect(_endpoint);
    _channel = channel;
    try {
      await channel.ready;
      _subscription = channel.stream.listen(
        (message) {
          if (message is! String) return;
          final decoded = jsonDecode(message);
          if (decoded is Map<String, dynamic>) {
            _events.add(decoded);
          }
        },
        onDone: _clearChannel,
        onError: (_, __) => _clearChannel(),
      );
    } catch (_) {
      _clearChannel();
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _clearChannel();
    await _events.close();
  }

  void _clearChannel() {
    _subscription = null;
    _channel = null;
  }
}
