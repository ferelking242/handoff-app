import 'package:shared_preferences/shared_preferences.dart';

import 'event_cache_store.dart';

class WebEventCacheStore implements EventCacheStore {
  static const _keyPrefix = 'handoff.event_cache.';

  Future<SharedPreferences> get _preferences =>
      SharedPreferences.getInstance();

  String _key(String conversationId) => '$_keyPrefix$conversationId';

  @override
  Future<String?> read(String conversationId) async {
    final preferences = await _preferences;
    return preferences.getString(_key(conversationId));
  }

  @override
  Future<void> write(String conversationId, String value) async {
    final saved = await (await _preferences).setString(
      _key(conversationId),
      value,
    );
    if (!saved) throw StateError('Could not save the conversation cache.');
  }

  @override
  Future<void> delete(String conversationId) async {
    final removed = await (await _preferences).remove(_key(conversationId));
    if (!removed) throw StateError('Could not clear the conversation cache.');
  }
}

EventCacheStore createEventCacheStore(Object? root) {
  if (root != null) {
    throw ArgumentError.value(root, 'root', 'Web storage does not use a root');
  }
  return WebEventCacheStore();
}
