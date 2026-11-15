/// A conversation record from the OpenHands Cloud app server.
///
/// Mirrors the subset of `/api/v1/app-conversations/search` the mobile client
/// needs. `conversationUrl` and `sessionApiKey` are what let the client talk
/// to the sandbox agent server directly.
class CloudConversation {
  const CloudConversation({
    required this.id,
    required this.title,
    this.conversationUrl,
    this.sessionApiKey,
    this.sandboxId,
    this.sandboxStatus,
    this.executionStatus,
    this.llmModel,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? conversationUrl;
  final String? sessionApiKey;
  final String? sandboxId;
  final String? sandboxStatus;
  final String? executionStatus;
  final String? llmModel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Base URL of the sandbox agent server, derived from [conversationUrl].
  ///
  /// The Cloud returns e.g. `https://host/api/conversations/`; the agent
  /// server root is everything before `/api/conversations`.
  String? get agentServerBaseUrl {
    final url = conversationUrl;
    if (url == null || url.isEmpty) return null;
    final idx = url.indexOf('/api/conversations');
    final base = idx >= 0 ? url.substring(0, idx) : url;
    return base.replaceAll(RegExp(r'/+$'), '');
  }

  bool get isRunning => executionStatus == 'running';

  bool get isReady =>
      sandboxStatus == 'RUNNING' &&
      agentServerBaseUrl != null &&
      (sessionApiKey?.isNotEmpty ?? false);

  static CloudConversation fromJson(Map<String, dynamic> json) {
    return CloudConversation(
      id: (json['id'] ?? '') as String,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : 'Untitled conversation',
      conversationUrl: json['conversation_url'] as String?,
      sessionApiKey: json['session_api_key'] as String?,
      sandboxId: json['sandbox_id'] as String?,
      sandboxStatus: json['sandbox_status'] as String?,
      executionStatus: json['execution_status'] as String?,
      llmModel: json['llm_model'] as String?,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
