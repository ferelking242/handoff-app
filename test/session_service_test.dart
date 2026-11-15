import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aivos/models/conversation.dart';
import 'package:aivos/services/event_cache.dart';
import 'package:aivos/services/notification_service.dart';
import 'package:aivos/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the alerts the session decides to raise.
class RecordingNotifier implements AgentNotifier {
  final calls = <String>[];

  @override
  Future<void> showAgentState({
    required String conversationId,
    required String title,
    required String body,
  }) async {
    calls.add('$conversationId|$body');
  }
}

/// A real HTTP + WebSocket server standing in for one sandbox agent server.
///
/// Nothing here is mocked: the service talks to it over an actual socket, so
/// the test exercises the same code path as production.
class FakeAgentServer {
  FakeAgentServer._(this._server, this.conversationId, this.apiKey);

  final HttpServer _server;
  final String conversationId;
  final String apiKey;

  final sockets = <WebSocket>[];
  final requests = <String>[];

  /// Events returned by the REST history endpoint, oldest-first.
  List<Map<String, dynamic>> history = [];
  String executionStatus = 'idle';

  static Future<FakeAgentServer> start({
    String conversationId = 'conv-1',
    String apiKey = 'key-1',
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeAgentServer._(server, conversationId, apiKey);
    server.listen(fake._handle);
    return fake;
  }

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  CloudConversation get conversation => CloudConversation(
    id: conversationId,
    title: 'Test conversation',
    conversationUrl: '$baseUrl/api/conversations/',
    sessionApiKey: apiKey,
    sandboxStatus: 'RUNNING',
    executionStatus: executionStatus,
  );

  Future<void> _handle(HttpRequest request) async {
    requests.add('${request.method} ${request.uri.path}');
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      if (request.headers.value('X-Session-API-Key') != apiKey) {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      return;
    }
    final path = request.uri.path;
    if (path.endsWith('/events/search')) {
      _json(request, {'items': history.reversed.toList()});
      return;
    }
    if (path.endsWith('/api/conversations/$conversationId')) {
      _json(request, {'id': conversationId, 'execution_status': executionStatus});
      return;
    }
    if (path.endsWith('/events')) {
      _json(request, {'ok': true});
      return;
    }
    _json(request, {'ok': true});
  }

  void _json(HttpRequest request, Map<String, dynamic> body) {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    unawaited(request.response.close());
  }

  /// Pushes a durable frame to every connected client, exactly as the agent
  /// server does.
  void pushEvent(Map<String, dynamic> event, {required int seq}) {
    final frame = jsonEncode({'type': 'durable', 'seq': seq, 'event': event});
    for (final socket in sockets) {
      socket.add(frame);
    }
  }

  Map<String, dynamic> messageEvent(String id, String source, String text) => {
    'id': id,
    'kind': 'MessageEvent',
    'source': source,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'message': text,
  };

  Future<void> stop() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await _server.close(force: true);
  }
}

void main() {
  late Directory tempDir;
  late FakeAgentServer server;
  late SessionService service;
  late RecordingNotifier notifier;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aivos_session_test');
    server = await FakeAgentServer.start();
    notifier = RecordingNotifier();
    service = SessionService(
      cache: EventCache(tempDir),
      notifications: notifier,
    );
  });

  tearDown(() async {
    await service.disposeAll();
    await server.stop();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// Waits until [predicate] holds, polling briefly. The socket path is
  /// genuinely asynchronous, so a fixed sleep would be flaky.
  Future<void> waitFor(
    bool Function() predicate, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (predicate()) return;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    fail('Timed out waiting for condition.');
  }

  test('open() loads history over HTTP and connects the socket', () async {
    server.history = [
      server.messageEvent('m1', 'user', 'hello'),
      server.messageEvent('m2', 'agent', 'hi there'),
    ];

    await service.open(server.conversation);

    final state = service.stateOf(server.conversationId);
    expect(state.events.map((e) => e.id), ['m1', 'm2']);
    expect(state.loadingHistory, isFalse);
    expect(state.connected, isTrue);
    expect(state.agentState.label, isNotEmpty);
  });

  test('live events arrive while a session is open', () async {
    await service.open(server.conversation);
    await waitFor(() => server.sockets.isNotEmpty);

    server.pushEvent(server.messageEvent('m3', 'agent', 'working'), seq: 7);
    await waitFor(() => service.stateOf(server.conversationId).events.length == 1);

    expect(service.stateOf(server.conversationId).events.single.text, 'working');
  });

  test(
    'the session keeps streaming after the screen is gone',
    () async {
      await service.open(server.conversation);
      await waitFor(() => server.sockets.isNotEmpty);

      // Opening the same session again is what happens when the user
      // navigates back into the conversation. The socket must be reused, not
      // recreated, and the history must NOT be refetched.
      final fetchesBefore = server.requests
          .where((r) => r.contains('events/search'))
          .length;
      await service.open(server.conversation);
      final fetchesAfter = server.requests
          .where((r) => r.contains('events/search'))
          .length;
      expect(fetchesAfter, fetchesBefore);

      server.pushEvent(server.messageEvent('m4', 'agent', 'still here'), seq: 1);
      await waitFor(
        () => service.stateOf(server.conversationId).events.length == 1,
      );
      expect(server.sockets.length, 1);
    },
  );

  test('replayed events are not duplicated in the transcript', () async {
    await service.open(server.conversation);
    await waitFor(() => server.sockets.isNotEmpty);

    final event = server.messageEvent('dup', 'agent', 'once');
    server.pushEvent(event, seq: 1);
    await waitFor(() => service.stateOf(server.conversationId).events.length == 1);

    // A reconnect replays the tail from the cursor; the same event must not
    // appear twice.
    server.pushEvent(event, seq: 1);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(service.stateOf(server.conversationId).events.length, 1);
  });

  test('a cached transcript is painted before the network answers', () async {
    server.history = [server.messageEvent('m1', 'user', 'from cache')];
    await service.open(server.conversation);
    await waitFor(() => service.stateOf(server.conversationId).events.isNotEmpty);
    // open() writes the snapshot asynchronously; wait for the file so the
    // "restart" below genuinely reads it back.
    final cacheFile = File('${tempDir.path}/events/${server.conversationId}.json');
    await waitFor(() => cacheFile.existsSync());

    // A brand-new service (app restart) must surface the cached transcript
    // immediately, before its HTTP call completes.
    final restarted = SessionService(
      cache: EventCache(tempDir),
      notifications: notifier,
    );
    addTearDown(restarted.disposeAll);

    final painted = Completer<int>();
    restarted.watch(server.conversationId).listen((state) {
      if (state.events.isNotEmpty && !painted.isCompleted) {
        painted.complete(state.events.length);
      }
    });
    unawaited(restarted.open(server.conversation));

    expect(await painted.future, 1);
  });

  test('notifies only when the app is backgrounded and input is needed', () async {
    await service.open(server.conversation);
    await waitFor(() => server.sockets.isNotEmpty);

    // Foreground: the user is already looking at the conversation.
    service.setForeground(true);
    server.pushEvent({
      'id': 's1',
      'kind': 'ConversationStateUpdateEvent',
      'source': 'agent',
      'key': 'execution_status',
      'value': 'awaiting_user_input',
    }, seq: 1);
    await waitFor(
      () => service.stateOf(server.conversationId).agentState.name ==
          'awaitingUserInput',
    );
    expect(notifier.calls, isEmpty);

    // Background: the alert is what makes the phone buzz.
    service.setForeground(false);
    server.pushEvent({
      'id': 's2',
      'kind': 'ConversationStateUpdateEvent',
      'source': 'agent',
      'key': 'execution_status',
      'value': 'finished',
    }, seq: 2);
    await waitFor(() => notifier.calls.isNotEmpty);
    expect(notifier.calls.single, contains('finished the task'));
  });
}
