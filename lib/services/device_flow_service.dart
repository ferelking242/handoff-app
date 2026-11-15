import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Credentials returned once the user approves a device-flow request.
class DeviceFlowSession {
  const DeviceFlowSession({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.verificationUriComplete,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final String verificationUriComplete;
  final int expiresIn;
  final int interval;
}

/// Raised while the user has not yet approved the request.
class AuthorizationPendingException implements Exception {
  const AuthorizationPendingException();
}

/// Raised when the server asks the client to poll more slowly. The server
/// advertises a 5s interval but enforces 10s, so the returned interval must be
/// honoured rather than the advertised one.
class SlowDownException implements Exception {
  const SlowDownException(this.interval);

  final int? interval;
}

/// Raised for a recoverable transport failure (DNS, timeout, connection
/// reset). The poll loop retries these instead of failing the whole sign-in.
class TransientNetworkException implements Exception {
  const TransientNetworkException(this.cause);

  final Object cause;

  @override
  String toString() => '$cause';
}

/// Raised when the device code expired or the user denied the request.
class DeviceFlowException implements Exception {
  const DeviceFlowException(this.message, [this.code]);

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// OAuth 2.0 device authorization grant (RFC 8628) against OpenHands Cloud.
///
/// This is how the mobile client signs in: the app shows a short code, the
/// user approves it in a browser, and the app polls for a bearer token. No
/// password is ever typed into or stored by the app.
class DeviceFlowService {
  DeviceFlowService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.cloudHost,
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.requestTimeout,
            ),
          );

  final Dio _dio;

  /// The server enforces at least this many seconds between polls.
  static const int minPollSeconds = 10;

  /// How many consecutive transport failures to ride out before giving up.
  /// A phone on a flaky network hits these regularly; abandoning sign-in on
  /// the first DNS hiccup is what made the flow look broken.
  static const int maxTransportRetries = 8;

  Future<DeviceFlowSession> start() async {
    final data = await _post(AppConfig.deviceAuthorizePath, {
      'client_id': AppConfig.deviceFlowClientId,
    });
    final deviceCode = data['device_code'] as String?;
    final userCode = data['user_code'] as String?;
    final verificationUri = data['verification_uri'] as String?;
    if (deviceCode == null || userCode == null || verificationUri == null) {
      throw const DeviceFlowException(
        'The server returned an incomplete device authorization response.',
      );
    }
    return DeviceFlowSession(
      deviceCode: deviceCode,
      userCode: userCode,
      verificationUri: verificationUri,
      verificationUriComplete:
          (data['verification_uri_complete'] as String?) ?? verificationUri,
      expiresIn: (data['expires_in'] as num?)?.toInt() ?? 600,
      interval: (data['interval'] as num?)?.toInt() ?? minPollSeconds,
    );
  }

  /// Polls once for the token.
  ///
  /// Throws [AuthorizationPendingException] while the user has not approved
  /// yet, [SlowDownException] when the server wants a longer gap, and
  /// [TransientNetworkException] on a recoverable transport error.
  Future<String> pollOnce(String deviceCode) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConfig.deviceTokenPath,
        data: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'device_code': deviceCode,
          'client_id': AppConfig.deviceFlowClientId,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final data = response.data ?? const <String, dynamic>{};
      final token = data['access_token'] as String?;
      if (response.statusCode == 200 && token != null) return token;

      final error = data['error'] as String?;
      final description = data['error_description'] as String?;
      switch (error) {
        case 'authorization_pending':
          throw const AuthorizationPendingException();
        case 'slow_down':
          throw SlowDownException((data['interval'] as num?)?.toInt());
        case 'expired_token':
          throw const DeviceFlowException(
            'The code expired before it was approved. Please try again.',
            'expired_token',
          );
        case 'access_denied':
          throw const DeviceFlowException(
            'Sign-in was denied on the website.',
            'access_denied',
          );
      }
      throw DeviceFlowException(
        description ?? 'Authorization failed: ${error ?? 'unknown error'}',
        error,
      );
    } on DioException catch (error) {
      if (_isTransient(error)) {
        throw TransientNetworkException(error.error ?? error.message ?? error);
      }
      // A 400 without a parseable body still means "not approved yet".
      final body = error.response?.data;
      if (error.response?.statusCode == 400 &&
          body is String &&
          body.contains('authorization_pending')) {
        throw const AuthorizationPendingException();
      }
      rethrow;
    }
  }

  bool _isTransient(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        return status != null && status >= 500;
      case DioExceptionType.unknown:
        // A SocketException (DNS failure, connection reset) arrives here.
        return error.error is SocketException || error.error is HttpException;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return false;
    }
  }

  /// Drives the full poll loop until approval, expiry, or [timeout].
  ///
  /// Transient network failures are retried so a brief DNS or connectivity
  /// blip does not throw away an authorization the user already completed.
  Future<String> awaitToken(
    DeviceFlowSession session, {
    Duration? timeout,
    void Function(String status)? onStatus,
    Duration minInterval = const Duration(seconds: minPollSeconds),
  }) async {
    final deadline = DateTime.now().add(
      timeout ?? Duration(seconds: session.expiresIn),
    );
    var interval = Duration(
      seconds: session.interval < minInterval.inSeconds
          ? minInterval.inSeconds
          : session.interval,
    );
    var transportFailures = 0;

    while (DateTime.now().isBefore(deadline)) {
      try {
        return await pollOnce(session.deviceCode);
      } on AuthorizationPendingException {
        transportFailures = 0;
      } on SlowDownException catch (error) {
        interval = Duration(
          seconds: (error.interval ?? interval.inSeconds + 5).clamp(
            minInterval.inSeconds,
            60,
          ),
        );
      } on TransientNetworkException {
        transportFailures++;
        if (transportFailures >= maxTransportRetries) {
          throw const DeviceFlowException(
            'Could not reach app.all-hands.dev. Check your connection and try again.',
            'network_error',
          );
        }
        onStatus?.call(
          'Network problem, retrying… ($transportFailures/$maxTransportRetries)',
        );
      }
      if (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(interval);
      }
    }
    throw const DeviceFlowException(
      'The code expired before it was approved. Please try again.',
      'expired_token',
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: body,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return response.data ?? const <String, dynamic>{};
  }
}

/// Decodes a JWT payload without verifying the signature. Used only to read
/// non-sensitive display claims such as the user's email.
Map<String, dynamic>? decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final json = jsonDecode(decoded);
    return json is Map<String, dynamic> ? json : null;
  } catch (_) {
    return null;
  }
}
