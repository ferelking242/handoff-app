import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/conversation_event.dart';

/// On-disk event cache, one JSON file per conversation.
///
/// The Canvas refetches the newest page over REST every time a conversation
/// screen mounts, which is what makes the history feel like it "reloads again
/// and again". Persisting events here lets the UI paint instantly and only ask
/// the network for what it does not already have.
class EventCache {
  EventCache([this._root]);

  Directory? _root;

  Future<Directory> _dir() async {
    final base = _root ??= await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/events');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String conversationId) async {
    final dir = await _dir();
    return File('${dir.path}/$conversationId.json');
  }

  Future<List<ConversationEvent>> load(String conversationId) async {
    try {
      final file = await _file(conversationId);
      if (!await file.exists()) return const [];
      final content = await file.readAsString();
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
      final file = await _file(conversationId);
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
      await file.writeAsString(jsonEncode(payload));
    } catch (_) {
      // A cache write failure must never break the live experience.
    }
  }

  Future<void> clear(String conversationId) async {
    try {
      final file = await _file(conversationId);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
