/// A single event in a conversation, as delivered by the agent server
/// (REST `events/search` and the `/sockets/session/{id}` WebSocket).
///
/// The wire shape varies by `kind`; the client keeps the raw map so nothing is
/// lost, and exposes typed getters for the fields the UI renders.
class ConversationEvent {
  ConversationEvent({
    required this.id,
    required this.kind,
    required this.source,
    required this.timestamp,
    required this.raw,
    this.seq,
  });

  final String id;
  final String kind;
  final String source;
  final DateTime? timestamp;
  final Map<String, dynamic> raw;

  /// Log index on the agent server. Present for durable WebSocket frames and
  /// used as the `after_seq` resume cursor.
  final int? seq;

  String? get toolName => raw['tool_name'] as String?;

  Map<String, dynamic> get action =>
      (raw['action'] as Map<String, dynamic>?) ?? const {};

  Map<String, dynamic> get observation =>
      (raw['observation'] as Map<String, dynamic>?) ?? const {};

  String? get toolCallId => raw['tool_call_id'] as String?;

  /// Free-form message text, whatever the event kind stores it under.
  String get text {
    final message = raw['message'];
    if (message is String) return message;
    if (message is Map) {
      final content = message['content'];
      if (content is String) return content;
      if (content is List) {
        final buffer = StringBuffer();
        for (final part in content) {
          if (part is Map && part['text'] is String) {
            buffer.write(part['text']);
          }
        }
        return buffer.toString();
      }
    }
    final llmMessage = raw['llm_message'];
    if (llmMessage is Map) {
      final content = llmMessage['content'];
      if (content is String) return content;
      if (content is List) {
        final buffer = StringBuffer();
        for (final part in content) {
          if (part is Map && part['text'] is String) {
            buffer.write(part['text']);
          }
        }
        return buffer.toString();
      }
    }
    return '';
  }

  bool get isUserMessage => kind == 'MessageEvent' && source == 'user';

  bool get isAssistantMessage => kind == 'MessageEvent' && source == 'agent';

  bool get isAction => kind == 'ActionEvent';

  bool get isObservation => kind == 'ObservationEvent';

  bool get isStateUpdate => kind == 'ConversationStateUpdateEvent';

  bool get isError => kind == 'ConversationErrorEvent';

  ConversationEvent copyWithSeq(int seq) => ConversationEvent(
    id: id,
    kind: kind,
    source: source,
    timestamp: timestamp,
    raw: raw,
    seq: seq,
  );

  static ConversationEvent fromJson(Map<String, dynamic> json, {int? seq}) {
    return ConversationEvent(
      id: (json['id'] ?? '') as String,
      kind: (json['kind'] ?? '') as String,
      source: (json['source'] ?? '') as String,
      timestamp: json['timestamp'] is String
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
      raw: json,
      seq: seq ?? (json['seq'] is int ? json['seq'] as int : null),
    );
  }
}
