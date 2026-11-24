import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/openhands_models.dart';

/// Thrown when the OpenHands server answers with an error.
class OpenHandsApiException implements Exception {
  OpenHandsApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

/// Device authorization is still pending; poll again.
class DeviceFlowPending implements Exception {
  const DeviceFlowPending();
}

/// The server asked us to slow the polling down.
class DeviceFlowSlowDown implements Exception {
  const DeviceFlowSlowDown(this.interval);

  final int? interval;
}

class ConversationPage {
  const ConversationPage({required this.items, this.nextPageId});

  final List<OpenHandsConversation> items;
  final String? nextPageId;
}

class EventPage {
  const EventPage({required this.items, this.nextPageId});

  final List<OpenHandsEvent> items;
  final String? nextPageId;
}

/// Thin client for the OpenHands app server and the per-conversation agent
/// server.
class OpenHandsApi {
  OpenHandsApi({String baseUrl = defaultBaseUrl, http.Client? client})
      : _baseUrl = normalizeBaseUrl(baseUrl),
        _client = client ?? http.Client();

  static const String defaultBaseUrl = 'https://app.all-hands.dev';
  static const String clientSource = 'handoff';
  static const String clientVersion = '1.0.0';

  static const Map<String, String> _clientHeaders = {
    'X-OpenHands-Client': clientSource,
    'X-OpenHands-Client-Version': clientVersion,
  };

  final http.Client _client;
  String _baseUrl;
  String? token;

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String value) {
    _baseUrl = normalizeBaseUrl(value);
  }

  static String normalizeBaseUrl(String value) {
    var text = value.trim();
    if (text.isEmpty) return defaultBaseUrl;
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      text = 'https://$text';
    }
    while (text.endsWith('/')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  Map<String, String> get _authHeaders {
    final token = this.token;
    if (token == null || token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json', ..._clientHeaders, ...?headers},
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Object? body, {
    Map<String, String>? headers,
  }) async {
    final response = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        ..._clientHeaders,
        ...?headers,
      },
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final raw = response.body.trim();
    Map<String, dynamic> data = const {};
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        } else if (decoded is Map) {
          data = decoded.cast<String, dynamic>();
        } else if (decoded is List) {
          data = {'items': decoded};
        }
      } catch (_) {
        data = {'detail': raw};
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = data['detail'] ?? data['error'] ?? data['message'];
      final message = detail is String && detail.trim().isNotEmpty
          ? detail
          : 'OpenHands request failed (HTTP ${response.statusCode})';
      throw OpenHandsApiException(
        message,
        statusCode: response.statusCode,
        code: data['error']?.toString(),
      );
    }
    return data;
  }

  // ---------------------------------------------------------------------
  // Authentication (OAuth 2.0 device flow)
  // ---------------------------------------------------------------------

  Future<DeviceCode> startDeviceFlow() async {
    final data = await _postJson(
      _uri('/oauth/device/authorize'),
      const <String, dynamic>{},
    );
    final code = DeviceCode.fromJson(data);
    if (code.deviceCode.isEmpty || code.userCode.isEmpty) {
      throw OpenHandsApiException(
        'The OpenHands server did not return a device code.',
      );
    }
    return code;
  }

  /// Polls the token endpoint once.
  ///
  /// Returns the access token, or throws [DeviceFlowPending] /
  /// [DeviceFlowSlowDown] while the user has not finished authorizing.
  Future<String> pollDeviceToken(String deviceCode) async {
    final response = await _client.post(
      _uri('/oauth/device/token'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
        ..._clientHeaders,
      },
      body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        'device_code': deviceCode,
      },
    );

    Map<String, dynamic> data = const {};
    final raw = response.body.trim();
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) data = decoded.cast<String, dynamic>();
      } catch (_) {}
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final accessToken = data['access_token']?.toString();
      if (accessToken == null || accessToken.isEmpty) {
        throw OpenHandsApiException(
          'The OpenHands server returned an empty access token.',
        );
      }
      return accessToken;
    }

    switch (data['error']?.toString()) {
      case 'authorization_pending':
        throw const DeviceFlowPending();
      case 'slow_down':
        final interval = data['interval'];
        throw DeviceFlowSlowDown(interval is num ? interval.toInt() : null);
      case 'expired_token':
      case 'invalid_grant':
        throw OpenHandsApiException(
          'This sign-in code is no longer valid. Start again.',
          statusCode: response.statusCode,
          code: 'expired_token',
        );
      case 'access_denied':
        throw OpenHandsApiException(
          'Sign-in was denied on the OpenHands side.',
          statusCode: response.statusCode,
          code: 'access_denied',
        );
      default:
        final detail = data['error_description'] ?? data['error'] ?? raw;
        throw OpenHandsApiException(
          detail.toString().isEmpty
              ? 'OpenHands sign-in failed (HTTP ${response.statusCode})'
              : detail.toString(),
          statusCode: response.statusCode,
        );
    }
  }

  Future<OpenHandsUser> me() async {
    final data = await _getJson(
      _uri('/api/v1/users/me'),
      headers: _authHeaders,
    );
    return OpenHandsUser.fromJson(data);
  }

  // ---------------------------------------------------------------------
  // Conversations
  // ---------------------------------------------------------------------

  Future<ConversationPage> searchConversations({
    int limit = 50,
    String? pageId,
  }) async {
    final data = await _getJson(
      _uri('/api/v1/app-conversations/search', {
        'limit': '$limit',
        if (pageId != null && pageId.isNotEmpty) 'page_id': pageId,
      }),
      headers: _authHeaders,
    );
    final items = (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => OpenHandsConversation.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
    return ConversationPage(
      items: items,
      nextPageId: data['next_page_id']?.toString(),
    );
  }

  Future<OpenHandsConversation> getConversation(String id) async {
    final data = await _getJson(
      _uri('/api/v1/app-conversations', {'ids': id}),
      headers: _authHeaders,
    );
    final items = data['items'] as List? ?? const [];
    if (items.isEmpty) {
      throw OpenHandsApiException('Conversation not found.', statusCode: 404);
    }
    final first = items.first;
    if (first is Map) {
      return OpenHandsConversation.fromJson(first.cast<String, dynamic>());
    }
    throw OpenHandsApiException('Unexpected conversation payload.');
  }

  /// Starts a new app conversation and waits for its sandbox to be ready.
  Future<OpenHandsConversation> createConversation({
    required String message,
    String? repository,
    String? branch,
    String? title,
  }) async {
    final data = await _postJson(
      _uri('/api/v1/app-conversations'),
      {
        'initial_message': {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': message},
          ],
          'run': true,
        },
        if (repository != null && repository.trim().isNotEmpty)
          'selected_repository': repository.trim(),
        if (branch != null && branch.trim().isNotEmpty)
          'selected_branch': branch.trim(),
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      },
      headers: _authHeaders,
    );

    final directId = data['app_conversation_id']?.toString();
    if (directId != null && directId.isNotEmpty) {
      return getConversation(directId);
    }

    final taskId = data['id']?.toString();
    if (taskId == null || taskId.isEmpty) {
      throw OpenHandsApiException(
        'OpenHands did not return a start task for the conversation.',
      );
    }

    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final task = await _getJson(
        _uri('/api/v1/app-conversations/start-tasks', {'ids': taskId}),
        headers: _authHeaders,
      );
      final items = task['items'] as List? ?? const [];
      if (items.isEmpty) continue;
      final first = items.first;
      if (first is! Map) continue;
      final status = (first['status'] ?? '').toString().toUpperCase();
      final conversationId = first['app_conversation_id']?.toString();
      if (status == 'READY' && conversationId != null) {
        return getConversation(conversationId);
      }
      if (status == 'ERROR') {
        final detail = first['detail']?.toString();
        throw OpenHandsApiException(
          detail?.isNotEmpty == true
              ? detail!
              : 'OpenHands could not start the conversation.',
        );
      }
    }
    throw OpenHandsApiException(
      'Timed out while OpenHands was starting the conversation.',
    );
  }

  // ---------------------------------------------------------------------
  // Agent server (per conversation)
  // ---------------------------------------------------------------------

  Map<String, String> _sessionHeaders(OpenHandsConversation conversation) {
    final key = conversation.sessionApiKey;
    if (key == null || key.isEmpty) return const {};
    return {'X-Session-API-Key': key};
  }

  String _conversationBase(OpenHandsConversation conversation) {
    var base = conversation.conversationUrl ?? '';
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  Future<EventPage> searchEvents(
    OpenHandsConversation conversation, {
    int limit = 100,
    String? pageId,
    String sortOrder = 'TIMESTAMP',
  }) async {
    final base = _conversationBase(conversation);
    if (base.isEmpty) {
      throw OpenHandsApiException(
        'This conversation has no live sandbox. Wake it up in OpenHands first.',
      );
    }
    final uri = Uri.parse('$base/events/search').replace(
      queryParameters: {
        'limit': '$limit',
        'sort_order': sortOrder,
        if (pageId != null && pageId.isNotEmpty) 'page_id': pageId,
      },
    );
    final data = await _getJson(uri, headers: _sessionHeaders(conversation));
    final items = (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => OpenHandsEvent.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
    return EventPage(items: items, nextPageId: data['next_page_id']?.toString());
  }

  Future<void> sendMessage(
    OpenHandsConversation conversation,
    String text,
  ) async {
    final base = _conversationBase(conversation);
    if (base.isEmpty) {
      throw OpenHandsApiException(
        'This conversation has no live sandbox. Wake it up in OpenHands first.',
      );
    }
    await _postJson(
      Uri.parse('$base/events'),
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': text},
        ],
        'run': true,
      },
      headers: _sessionHeaders(conversation),
    );
  }

  Future<void> interruptConversation(OpenHandsConversation conversation) async {
    final base = _conversationBase(conversation);
    if (base.isEmpty) return;
    await _postJson(
      Uri.parse('$base/interrupt'),
      const <String, dynamic>{},
      headers: _sessionHeaders(conversation),
    );
  }

  void close() => _client.close();
}
