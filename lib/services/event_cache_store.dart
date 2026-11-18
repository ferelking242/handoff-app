abstract interface class EventCacheStore {
  Future<String?> read(String conversationId);

  Future<void> write(String conversationId, String value);

  Future<void> delete(String conversationId);
}
