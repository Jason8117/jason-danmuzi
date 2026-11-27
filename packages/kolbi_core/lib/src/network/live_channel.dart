import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

enum LiveStatus { connecting, connected, disconnected }

abstract interface class LiveConnection {
  Stream<Map<String, dynamic>> get messages;
  Stream<LiveStatus> get status;
  void connect();
  Future<void> close();
}

/// A JSON WebSocket that reconnects with capped exponential backoff.
/// The server sends a full snapshot on every connect, so nothing is lost while offline.
class LiveChannel implements LiveConnection {
  LiveChannel(this.uri);

  final Uri uri;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _status = StreamController<LiveStatus>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _closed = false;

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;
  @override
  Stream<LiveStatus> get status => _status.stream;

  @override
  void connect() {
    if (_closed) return;
    _status.add(LiveStatus.connecting);
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

    channel.ready.then((_) {
      _attempt = 0;
      if (!_closed) _status.add(LiveStatus.connected);
    }).catchError((_) {});

    _subscription = channel.stream.listen(
      (raw) {
        final decoded = jsonDecode(raw as String);
        if (decoded is Map<String, dynamic>) _messages.add(decoded);
      },
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
      cancelOnError: true,
    );
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _status.add(LiveStatus.disconnected);
    _subscription?.cancel();
    _retryTimer?.cancel();
    final seconds = min(30, pow(2, _attempt).toInt());
    _attempt++;
    _retryTimer = Timer(Duration(seconds: seconds), connect);
  }

  @override
  Future<void> close() async {
    _closed = true;
    _retryTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _messages.close();
    await _status.close();
  }
}
