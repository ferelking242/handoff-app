/// Static configuration for the OpenHands Cloud client.
class AppConfig {
  AppConfig._();

  static const String appName = 'AIVOS';
  static const String appTagline = 'OpenHands on mobile';

  /// OpenHands Cloud host used for auth and account-level endpoints.
  static const String cloudHost = 'https://app.all-hands.dev';

  /// OAuth device-flow endpoints (RFC 8628) exposed by the Cloud app server.
  static const String deviceAuthorizePath = '/oauth/device/authorize';
  static const String deviceTokenPath = '/oauth/device/token';

  /// REST surface of the Cloud app server (V1).
  static const String appConversationsPath = '/api/v1/app-conversations';
  static const String sandboxesPath = '/api/v1/sandboxes';

  /// Path prefix of the per-conversation agent server (sandbox).
  static const String agentServerConversationsPath = '/api/conversations';

  /// How many events a history page holds. The agent server caps `limit` at 100.
  static const int historyPageSize = 50;

  /// Device-flow client identifier. The Cloud accepts requests without one.
  static const String deviceFlowClientId = 'aivos-mobile';

  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 15);
}
