import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/models/conversation_event.dart';
import 'package:handoff/services/event_cache.dart';

void main() {
  late Directory tempDir;
  late EventCache cache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aivos_cache_test');
    cache = EventCache(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  ConversationEvent event(String id, String kind, {String? text}) {
    return ConversationEvent.fromJson({
      'id': id,
      'kind': kind,
      'source': 'agent',
      'timestamp': '2026-01-01T00:00:00Z',
      if (text != null) 'message': text,
    });
  }

  test('returns an empty list for an unknown conversation', () async {
    expect(await cache.load('missing'), isEmpty);
  });

  test('round-trips events through disk', () async {
    final events = [
      event('e1', 'MessageEvent', text: 'first'),
      event('e2', 'ActionEvent'),
      event('e3', 'ObservationEvent'),
    ];
    await cache.save('c1', events);

    final loaded = await cache.load('c1');
    expect(loaded.map((e) => e.id), ['e1', 'e2', 'e3']);
    expect(loaded.first.text, 'first');
    expect(loaded[1].kind, 'ActionEvent');
  });

  test('keeps conversations isolated from each other', () async {
    await cache.save('c1', [event('a', 'MessageEvent')]);
    await cache.save('c2', [event('b', 'MessageEvent')]);
    expect((await cache.load('c1')).single.id, 'a');
    expect((await cache.load('c2')).single.id, 'b');
  });

  test('a later save replaces the previous snapshot', () async {
    await cache.save('c1', [event('e1', 'MessageEvent')]);
    await cache.save('c1', [
      event('e1', 'MessageEvent'),
      event('e2', 'MessageEvent'),
    ]);
    expect((await cache.load('c1')).length, 2);
  });

  test('bounds the stored tail so a long chat cannot grow forever', () async {
    final many = List.generate(600, (i) => event('e$i', 'MessageEvent'));
    await cache.save('c1', many);
    final loaded = await cache.load('c1');
    expect(loaded.length, 500);
    // The tail is kept: the newest event survives.
    expect(loaded.last.id, 'e599');
  });

  test('clear removes a conversation snapshot', () async {
    await cache.save('c1', [event('e1', 'MessageEvent')]);
    await cache.clear('c1');
    expect(await cache.load('c1'), isEmpty);
  });
}
