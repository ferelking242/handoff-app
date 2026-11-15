import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/conversation.dart';

/// Reads and writes conversation metadata through the OpenHands Cloud app
/// server (`https://app.all-hands.dev/api/v1/...`).
///
/// Account-level calls use the user's bearer token. Per-conversation live data
/// does *not* go through here — it goes straight to the sandbox agent server
/// (see [AgentServerClient]).
class CloudApiService {
  CloudApiService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.cloudHost,
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.requestTimeout,
            ),
          );

  final Dio _dio;

  void setToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<List<CloudConversation>> searchConversations({
    int limit = 50,
    String? status,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppConfig.appConversationsPath}/search',
      queryParameters: {
        'limit': limit,
        if (status != null) 'status': status,
      },
    );
    final items = (response.data?['items'] as List<dynamic>?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(CloudConversation.fromJson)
        .toList(growable: false);
  }

  Future<CloudConversation?> getConversation(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppConfig.appConversationsPath,
      queryParameters: {
        'ids': id,
      },
    );
    final data = response.data;
    if (data == null) return null;
    final items = data['items'];
    if (items is List && items.isNotEmpty) {
      return CloudConversation.fromJson(items.first as Map<String, dynamic>);
    }
    // Some deployments return the record directly.
    if (data['id'] == id) return CloudConversation.fromJson(data);
    return null;
  }

  /// Creates a conversation from an initial prompt. Returns the new record.
  Future<CloudConversation> createConversation({
    required String initialMessage,
    String? repository,
    String? branch,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConfig.appConversationsPath,
      data: {
        'initial_message': {
          'content': [
            {'type': 'text', 'text': initialMessage},
          ],
        },
        if (repository != null) 'selected_repository': repository,
        if (branch != null) 'selected_branch': branch,
      },
    );
    final data = response.data ?? const <String, dynamic>{};

    // Creation is asynchronous on some deployments: the response may be a
    // start-task that must be polled for the final conversation id.
    final directId = data['id'] as String?;
    final appConversationId = data['app_conversation_id'] as String?;
    final startTaskId = data['start_task_id'] as String? ?? data['task_id'] as String?;

    if (appConversationId != null) {
      return (await getConversation(appConversationId)) ??
          CloudConversation(id: appConversationId, title: 'New conversation');
    }
    if (directId != null && data['conversation_url'] != null) {
      return CloudConversation.fromJson(data);
    }
    if (startTaskId != null) {
      return _pollStartTask(startTaskId);
    }
    if (directId != null) {
      return (await getConversation(directId)) ??
          CloudConversation(id: directId, title: 'New conversation');
    }
    throw const CloudApiException('The server did not return a conversation id.');
  }

  Future<CloudConversation> _pollStartTask(String startTaskId) async {
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    while (DateTime.now().isBefore(deadline)) {
      final response = await _dio.get<Map<String, dynamic>>(
        '${AppConfig.appConversationsPath}/start-tasks',
        queryParameters: {
          'ids': startTaskId,
        },
      );
      final data = response.data ?? const <String, dynamic>{};
      final items = data['items'];
      final task = (items is List && items.isNotEmpty)
          ? items.first as Map<String, dynamic>
          : data;
      final status = task['status'] as String?;
      final conversationId = task['app_conversation_id'] as String?;
      if (conversationId != null) {
        return (await getConversation(conversationId)) ??
            CloudConversation(id: conversationId, title: 'New conversation');
      }
      if (status == 'ERROR' || status == 'FAILED') {
        throw CloudApiException(
          'Conversation failed to start: ${task['detail'] ?? status}',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    throw const CloudApiException('Timed out waiting for the conversation to start.');
  }

  /// Validates the bearer token and returns the account payload.
  Future<Map<String, dynamic>> currentUser() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/users/me');
    return response.data ?? const <String, dynamic>{};
  }
}

class CloudApiException implements Exception {
  const CloudApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
