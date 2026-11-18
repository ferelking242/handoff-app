import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'event_cache_store.dart';

class IoEventCacheStore implements EventCacheStore {
  IoEventCacheStore([this._root]);

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

  @override
  Future<String?> read(String conversationId) async {
    final file = await _file(conversationId);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String conversationId, String value) async {
    final file = await _file(conversationId);
    await file.writeAsString(value);
  }

  @override
  Future<void> delete(String conversationId) async {
    final file = await _file(conversationId);
    if (await file.exists()) await file.delete();
  }
}

EventCacheStore createEventCacheStore(Object? root) {
  if (root != null && root is! Directory) {
    throw ArgumentError.value(root, 'root', 'Expected a Directory');
  }
  return IoEventCacheStore(root as Directory?);
}
