import 'event_cache_store.dart';

class UnsupportedEventCacheStore implements EventCacheStore {
  Never _unsupported() =>
      throw UnsupportedError('Event caching is not supported on this platform.');

  @override
  Future<String?> read(String conversationId) async => _unsupported();

  @override
  Future<void> write(String conversationId, String value) async =>
      _unsupported();

  @override
  Future<void> delete(String conversationId) async => _unsupported();
}

EventCacheStore createEventCacheStore(Object? root) {
  if (root != null) {
    throw ArgumentError.value(root, 'root', 'This platform does not use a root');
  }
  return UnsupportedEventCacheStore();
}
