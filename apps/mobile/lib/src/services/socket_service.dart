import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';
import 'app_logger.dart';

typedef SocketEventHandler = void Function(dynamic payload);

class SocketService {
  SocketService._();

  static final SocketService instance = SocketService._();

  WebSocket? _socket;
  String? _activeToken;
  String? _socketId;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  final Map<String, List<SocketEventHandler>> _handlers = <String, List<SocketEventHandler>>{};

  bool get isConnected => _socket?.readyState == WebSocket.open;
  String? get socketId => _socketId;

  Future<void> connect(String token) async {
    if (token.isEmpty) {
      await AppLogger.instance.warning('socket', 'Socket connect skipped: missing token');
      return;
    }

    if (isConnected && _activeToken == token) {
      await AppLogger.instance.info('socket', 'Socket already connected', data: {'id': _socketId});
      return;
    }

    if (_isConnecting) {
      await AppLogger.instance.info('socket', 'Socket connect skipped: connection already in progress');
      return;
    }

    _activeToken = token;
    _reconnectTimer?.cancel();
    _isConnecting = true;

    final uri = _socketUri();
    await AppLogger.instance.info('socket', 'Socket connect requested', data: {'url': uri.toString()});

    try {
      final socket = await WebSocket.connect(uri.toString()).timeout(const Duration(seconds: 20));
      _socket = socket;
      _isConnecting = false;
      socket.listen(
        _handleMessage,
        onError: (Object error) {
          unawaited(AppLogger.instance.error('socket', 'Socket stream error', data: {'error': error.toString()}));
          _scheduleReconnect();
        },
        onDone: () {
          unawaited(
            AppLogger.instance.warning(
              'socket',
              'Socket disconnected',
              data: {'code': socket.closeCode, 'reason': socket.closeReason},
            ),
          );
          _socket = null;
          _socketId = null;
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (error) {
      _isConnecting = false;
      await AppLogger.instance.error('socket', 'Socket connect error', data: {'message': error.toString()});
      _scheduleReconnect();
    }
  }

  void disconnect() {
    unawaited(AppLogger.instance.info('socket', 'Socket disconnect requested', data: {'id': _socketId}));
    _activeToken = null;
    _socketId = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final socket = _socket;
    _socket = null;
    unawaited(socket?.close());
  }

  void on(String event, SocketEventHandler handler) {
    final handlers = _handlers.putIfAbsent(event, () => <SocketEventHandler>[]);
    if (!handlers.contains(handler)) {
      handlers.add(handler);
    }
  }

  void off(String event, [SocketEventHandler? handler]) {
    if (handler == null) {
      _handlers.remove(event);
      return;
    }

    final handlers = _handlers[event];
    handlers?.remove(handler);
    if (handlers != null && handlers.isEmpty) {
      _handlers.remove(event);
    }
  }

  void joinUser() {
    unawaited(AppLogger.instance.info('socket', 'Joining user room'));
    _emit('join:user');
  }

  void joinGroup(String groupId) {
    unawaited(AppLogger.instance.info('socket', 'Joining group room', data: {'groupId': groupId}));
    _emit('join:group', <String, dynamic>{'groupId': groupId});
  }

  void leaveGroup(String groupId) {
    unawaited(AppLogger.instance.info('socket', 'Leaving group room', data: {'groupId': groupId}));
    _emit('leave:group', <String, dynamic>{'groupId': groupId});
  }

  void sendLocationUpdate(Map<String, dynamic> payload) {
    unawaited(AppLogger.instance.info('socket', 'Sending live location update', data: payload));
    _emit('location:update', payload);
  }

  Uri _socketUri() {
    final apiUri = Uri.parse(AppConfig.socketUrl);
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    return apiUri.replace(
      scheme: scheme,
      path: '/socket.io/',
      queryParameters: <String, String>{'EIO': '4', 'transport': 'websocket'},
    );
  }

  void _handleMessage(dynamic message) {
    try {
      _handlePacket(message);
    } catch (error) {
      unawaited(AppLogger.instance.error('socket', 'Socket packet handling failed', data: {'error': error.toString()}));
    }
  }

  void _handlePacket(dynamic message) {
    final text = message?.toString() ?? '';
    if (text.isEmpty) {
      return;
    }

    unawaited(AppLogger.instance.info('socket', 'Socket packet received', data: {'packetType': text[0]}));

    if (text.startsWith('0')) {
      final payload = _decodeObject(text.substring(1));
      _socketId = payload == null ? null : payload['sid']?.toString();
      _socket?.add('40${jsonEncode(<String, dynamic>{'token': _activeToken})}');
      unawaited(AppLogger.instance.info('socket', 'Socket engine opened', data: {'id': _socketId}));
      return;
    }

    if (text == '2') {
      _socket?.add('3');
      return;
    }

    if (text.startsWith('40')) {
      unawaited(AppLogger.instance.info('socket', 'Socket connected', data: {'id': _socketId}));
      joinUser();
      return;
    }

    if (text.startsWith('44')) {
      unawaited(AppLogger.instance.error('socket', 'Socket namespace error', data: {'packet': text}));
      return;
    }

    if (text.startsWith('42')) {
      _handleEventPacket(text.substring(2));
    }
  }

  void _handleEventPacket(String payloadText) {
    final decoded = jsonDecode(payloadText);
    if (decoded is! List || decoded.isEmpty) {
      return;
    }

    final event = decoded.first?.toString() ?? '';
    final payload = decoded.length > 1 ? decoded[1] : null;
    unawaited(AppLogger.instance.info('socket', 'Socket event received', data: {'event': event, 'payload': payload}));

    final handlers = List<SocketEventHandler>.from(_handlers[event] ?? const <SocketEventHandler>[]);
    for (final handler in handlers) {
      try {
        handler(payload);
      } catch (error) {
        unawaited(
          AppLogger.instance.error(
            'socket',
            'Socket event handler failed',
            data: {'event': event, 'error': error.toString()},
          ),
        );
      }
    }
  }

  void _emit(String event, [dynamic payload]) {
    if (!isConnected) {
      unawaited(AppLogger.instance.warning('socket', 'Socket emit skipped: not connected', data: {'event': event}));
      return;
    }

    final packet = payload == null ? <dynamic>[event] : <dynamic>[event, payload];
    _socket?.add('42${jsonEncode(packet)}');
    unawaited(AppLogger.instance.info('socket', 'Socket event emitted', data: {'event': event, 'payload': payload}));
  }

  Map<String, dynamic>? _decodeObject(String value) {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  void _scheduleReconnect() {
    final token = _activeToken;
    if (token == null || token.isEmpty) {
      return;
    }

    if (_reconnectTimer?.isActive == true) {
      return;
    }

    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      unawaited(AppLogger.instance.info('socket', 'Socket reconnect scheduled attempt'));
      unawaited(connect(token));
    });
  }
}
