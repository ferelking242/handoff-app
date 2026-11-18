import 'dart:async';
import 'dart:convert';

import '../models/conversation_event.dart';

import 'event_cache_store.dart';
import 'event_cache_store_stub.dart'
    if (dart.library.io) 'event_cache_store_io.dart'
    if (dart.library.js_interop) 'event_cache_store_web.dart' as platform;

/// Persistent event cache, one JSON snapshot per conversation.
///
/// The Canvas refetches the newest page over REST every time a conversation
/// screen mounts, which is what makes the history feel like it "reloads again
/// and again". Persisting events here lets the UI paint instantly and only ask
/// the network for what it does not already have.
class EventCache {
  EventCache([Object? root]) : _store = platform.createEventCacheStore(root);

  final EventCacheStore _store;

  Future<List<ConversationEvent>> load(String conversationId) async {
    try {
      final content = await _store.read(conversationId);
      if (content == null) return const [];
      final decoded = jsonDecode(content);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((json) => ConversationEvent.fromJson(json))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(
    String conversationId,
    List<ConversationEvent> events,
  ) async {
    try {
      // Keep the tail bounded so a very long conversation cannot grow without
      // limit on a phone.
      final tail = events.length > 500
          ? events.sublist(events.length - 500)
          : events;
      final payload = tail
          .map(
            (event) => {
              'id': event.id,
              'kind': event.kind,
              'source': event.source,
              'timestamp': event.timestamp?.toIso8601String(),
              ...event.raw,
            },
          )
          .toList();
      await _store.write(conversationId, jsonEncode(payload));
    } catch (_) {
      // A cache write failure must never break the live experience.
    }
  }

  Future<void> clear(String conversationId) async {
    try {
      await _store.delete(conversationId);
    } catch (_) {}
  }
}
