import 'dart:convert';

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

  Future<DeviceFlowSession> start() async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConfig.deviceAuthorizePath,
      data: {'client_id': AppConfig.deviceFlowClientId},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final data = response.data ?? const <String, dynamic>{};
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
      interval: (data['interval'] as num?)?.toInt() ?? 5,
    );
  }

  /// Polls once for the token. Throws [AuthorizationPendingException] while the
  /// user has not approved yet, so the caller can keep the loop going.
  Future<String> pollOnce(String deviceCode) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConfig.deviceTokenPath,
        data: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'device_code': deviceCode,
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
      if (error == 'authorization_pending' || error == 'slow_down') {
        throw const AuthorizationPendingException();
      }
      throw DeviceFlowException(
        (data['error_description'] as String?) ??
            'Authorization failed: ${error ?? 'unknown error'}',
        error,
      );
    } on DioException catch (error) {
      // A 4xx without a JSON body still means "not approved yet" in practice.
      if (error.response?.statusCode == 400) {
        final body = error.response?.data;
        if (body is String && body.contains('authorization_pending')) {
          throw const AuthorizationPendingException();
        }
      }
      rethrow;
    }
  }

  /// Drives the full poll loop until approval, expiry, or [timeout].
  Future<String> awaitToken(
    DeviceFlowSession session, {
    Duration? timeout,
  }) async {
    final deadline =
        DateTime.now().add(timeout ?? Duration(seconds: session.expiresIn));
    var interval = Duration(seconds: session.interval.clamp(1, 30));

    while (DateTime.now().isBefore(deadline)) {
      try {
        return await pollOnce(session.deviceCode);
      } on AuthorizationPendingException {
        await Future<void>.delayed(interval);
      }
    }
    throw const DeviceFlowException(
      'The code expired before it was approved. Please try again.',
      'expired_token',
    );
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
