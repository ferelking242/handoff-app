import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../models/conversation_event.dart';

/// A page of conversation history.
class HistoryPage {
  const HistoryPage({
    required this.events,
    required this.hasMore,
    this.nextPageId,
  });

  final List<ConversationEvent> events;
  final bool hasMore;
  final String? nextPageId;
}

/// Talks to one conversation's sandbox agent server.
///
/// This is the piece the Canvas gets wrong: the socket must outlive the screen
/// that opened it. Here the client is a plain object owned by a long-lived
/// service, so navigating between screens never tears the connection down.
class AgentServerClient {
  AgentServerClient({
    required this.baseUrl,
    required this.sessionApiKey,
    required this.conversationId,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: AppConfig.connectTimeout,
           receiveTimeout: AppConfig.requestTimeout,
           headers: {'X-Session-API-Key': sessionApiKey},
         ),
       );

  final String baseUrl;
  final String sessionApiKey;
  final String conversationId;
  final Dio _dio;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _events = StreamController<ConversationEvent>.broadcast();
  final _connection = StreamController<bool>.broadcast();

  int _lastSeq = -1;
  bool _connected = false;

  /// Live events, including replayed ones after a reconnect.
  Stream<ConversationEvent> get events => _events.stream;

  /// Connection state changes, so the UI can show a live indicator.
  Stream<bool> get connectionState => _connection.stream;

  bool get isConnected => _connected;

  int get lastSeq => _lastSeq;

  String get _wsBase {
    if (baseUrl.startsWith('https://')) {
      return 'wss://${baseUrl.substring('https://'.length)}';
    }
    if (baseUrl.startsWith('http://')) {
      return 'ws://${baseUrl.substring('http://'.length)}';
    }
    return baseUrl;
  }

  /// Fetches the newest page of events, in chronological order.
  Future<HistoryPage> fetchHistory({int limit = AppConfig.historyPageSize}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/conversations/$conversationId/events/search',
      queryParameters: {'limit': limit, 'sort_order': 'TIMESTAMP_DESC'},
    );
    final data = response.data ?? const <String, dynamic>{};
    final items = (data['items'] as List<dynamic>?) ?? const [];
    final events = items
        .whereType<Map<String, dynamic>>()
        .map((json) => ConversationEvent.fromJson(json))
        .toList();
    // The server returns newest-first; the UI wants oldest-first.
    final chronological = events.reversed.toList(growable: false);
    return HistoryPage(
      events: chronological,
      hasMore: chronological.length >= limit,
      nextPageId: data['next_page_id'] as String?,
    );
  }

  /// Loads events older than [beforeTimestamp].
  Future<HistoryPage> fetchOlder({
    required String beforeTimestamp,
    int limit = AppConfig.historyPageSize,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/conversations/$conversationId/events/search',
      queryParameters: {
        'limit': limit,
        'sort_order': 'TIMESTAMP_DESC',
        'timestamp__lt': beforeTimestamp,
      },
    );
    final data = response.data ?? const <String, dynamic>{};
    final items = (data['items'] as List<dynamic>?) ?? const [];
    final events = items
        .whereType<Map<String, dynamic>>()
        .map((json) => ConversationEvent.fromJson(json))
        .toList();
    final chronological = events.reversed.toList(growable: false);
    return HistoryPage(
      events: chronological,
      hasMore: chronological.length >= limit,
      nextPageId: data['next_page_id'] as String?,
    );
  }

  /// Opens the live socket. Safe to call repeatedly: an open socket is kept.
  Future<void> connect({int? afterSeq}) async {
    if (_channel != null) return;
    final cursor = afterSeq ?? _lastSeq;
    final query = cursor >= 0 ? '?after_seq=$cursor' : '';
    final channel = IOWebSocketChannel.connect(
      Uri.parse('$_wsBase/sockets/session/$conversationId$query'),
      headers: {'X-Session-API-Key': sessionApiKey},
      pingInterval: const Duration(seconds: 20),
    );
    _channel = channel;
    _subscription = channel.stream.listen(
      _onFrame,
      onDone: _onDisconnected,
      onError: (_) => _onDisconnected(),
      cancelOnError: true,
    );
  }

  void _onFrame(dynamic raw) {
    if (!_connected) {
      _connected = true;
      _connection.add(true);
    }
    Map<String, dynamic> frame;
    try {
      frame = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (frame['type']) {
      case 'durable':
        final seq = frame['seq'];
        if (seq is int && seq > _lastSeq) _lastSeq = seq;
        final event = frame['event'];
        if (event is Map<String, dynamic>) {
          _events.add(
            ConversationEvent.fromJson(event, seq: seq is int ? seq : null),
          );
        }
      case 'transient':
        final event = frame['event'];
        if (event is Map<String, dynamic>) {
          _events.add(ConversationEvent.fromJson(event));
        }
      default:
        // `sync`, `delta`, `item_started`, `item_aborted`, `error` carry no
        // durable event; the UI can ignore them safely.
        break;
    }
  }

  void _onDisconnected() {
    _connected = false;
    _connection.add(false);
    _channel = null;
    _subscription = null;
  }

  /// Sends a user message and starts a run if the agent is idle.
  Future<void> sendMessage(String text) async {
    await _dio.post<void>(
      '/api/conversations/$conversationId/events',
      data: {
        'message': {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': text},
          ],
        },
      },
    );
  }

  /// Interrupts the running agent.
  Future<void> interrupt() async {
    await _dio.post<void>('/api/conversations/$conversationId/interrupt');
  }

  /// Reads the conversation record, including the current execution status.
  Future<Map<String, dynamic>> fetchConversation() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/conversations/$conversationId',
    );
    return response.data ?? const <String, dynamic>{};
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _subscription = null;
    await _events.close();
    await _connection.close();
  }
}
