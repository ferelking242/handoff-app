import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/services/device_flow_service.dart';

/// A real HTTP server implementing the device-flow contract, including the
/// behaviours that broke sign-in in the field: a 10s polling floor (answered
/// with `slow_down`) and recoverable transport failures.
class FakeOAuthServer {
  FakeOAuthServer._(this._server);

  final HttpServer _server;
  final tokenRequests = <String>[];

  /// Responses to hand back for successive /token calls, in order.
  final responses = <_Reply>[];
  int _index = 0;

  /// When set, the server closes the connection without answering, which the
  /// client sees as a transport failure (like a DNS hiccup).
  bool dropConnections = false;

  static Future<FakeOAuthServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeOAuthServer._(server);
    server.listen(fake._handle);
    return fake;
  }

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Dio dio() => Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2),
    ),
  );

  Future<void> _handle(HttpRequest request) async {
    if (dropConnections) {
      await request.response.close();
      return;
    }
    if (request.uri.path.endsWith('/authorize')) {
      _json(request, {
        'device_code': 'dev-code',
        'user_code': 'ABCD-1234',
        'verification_uri': '$baseUrl/verify',
        'verification_uri_complete': '$baseUrl/verify?user_code=ABCD-1234',
        'expires_in': 600,
        'interval': 5,
      });
      return;
    }
    final body = await utf8.decoder.bind(request).join();
    tokenRequests.add(body);
    final reply = _index < responses.length
        ? responses[_index++]
        : const _Reply(400, {'error': 'authorization_pending'});
    _json(request, reply.body, status: reply.status);
  }

  void _json(HttpRequest request, Map<String, dynamic> body, {int status = 200}) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    unawaited(request.response.close());
  }

  Future<void> stop() => _server.close(force: true);
}

class _Reply {
  const _Reply(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;
}

void main() {
  late FakeOAuthServer server;
  late DeviceFlowService service;

  setUp(() async {
    server = await FakeOAuthServer.start();
    service = DeviceFlowService(dio: server.dio());
  });

  tearDown(() => server.stop());

  test('start() parses the authorization response', () async {
    final session = await service.start();
    expect(session.userCode, 'ABCD-1234');
    expect(session.verificationUriComplete, contains('user_code=ABCD-1234'));
    expect(session.expiresIn, 600);
  });

  test('pollOnce returns the token once the server approves', () async {
    server.responses.addAll([
      const _Reply(400, {'error': 'authorization_pending'}),
      const _Reply(200, {'access_token': 'tok-123'}),
    ]);

    expect(
      () => service.pollOnce('dev-code'),
      throwsA(isA<AuthorizationPendingException>()),
    );
    expect(await service.pollOnce('dev-code'), 'tok-123');
  });

  test('slow_down is surfaced instead of treated as a failure', () async {
    server.responses.add(const _Reply(400, {
      'error': 'slow_down',
      'error_description': 'Polling too frequently.',
      'interval': 10,
    }));

    await expectLater(
      service.pollOnce('dev-code'),
      throwsA(isA<SlowDownException>()),
    );
  });

  test('expired_token and access_denied are terminal', () async {
    server.responses.add(const _Reply(400, {'error': 'expired_token'}));
    await expectLater(
      service.pollOnce('dev-code'),
      throwsA(isA<DeviceFlowException>()),
    );
  });

  test(
    'repeated transport failures are retried rather than fatal',
    () async {
      // Simulate a flaky link: every other poll fails at the transport layer,
      // and the poll that gets through is answered with the token.
      var calls = 0;
      final dio = server.dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls++;
            if (calls % 2 == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                  error: const SocketException('Failed host lookup'),
                ),
              );
              return;
            }
            handler.next(options);
          },
        ),
      );
      final flaky = DeviceFlowService(dio: dio);
      server.responses.add(const _Reply(200, {'access_token': 'tok-ok'}));

      final statuses = <String>[];
      final token = await flaky.awaitToken(
        const DeviceFlowSession(
          deviceCode: 'dev-code',
          userCode: 'ABCD-1234',
          verificationUri: '',
          verificationUriComplete: '',
          expiresIn: 600,
          interval: 1,
        ),
        timeout: const Duration(seconds: 30),
        minInterval: const Duration(milliseconds: 10),
        onStatus: statuses.add,
      );

      expect(token, 'tok-ok');
      expect(statuses.single, contains('Network problem'));
    },
  );

  test('giving up after too many transport failures is a clear error', () async {
    final dio = server.dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: const SocketException('Failed host lookup'),
          ),
        ),
      ),
    );
    final offline = DeviceFlowService(dio: dio);

    await expectLater(
      offline.awaitToken(
        const DeviceFlowSession(
          deviceCode: 'dev-code',
          userCode: 'ABCD-1234',
          verificationUri: '',
          verificationUriComplete: '',
          expiresIn: 600,
          interval: 1,
        ),
        timeout: const Duration(seconds: 30),
        minInterval: const Duration(milliseconds: 10),
      ),
      throwsA(
        isA<DeviceFlowException>().having(
          (e) => e.message,
          'message',
          contains('Check your connection'),
        ),
      ),
    );
  });

  test('the token poll carries the client id', () async {
    server.responses.add(const _Reply(200, {'access_token': 'tok'}));
    await service.pollOnce('dev-code');
    expect(server.tokenRequests.single, contains('client_id='));
    expect(server.tokenRequests.single, contains('device_code=dev-code'));
  });
}
