import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the Cloud bearer token in the platform keystore.
///
/// Tokens never touch plain preferences: on Android this is the Encrypted
/// SharedPreferences / Keystore, on iOS the Keychain.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'openhands_access_token';
  static const _hostKey = 'openhands_cloud_host';

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> readHost() => _storage.read(key: _hostKey);

  Future<void> writeHost(String host) =>
      _storage.write(key: _hostKey, value: host);

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
  }
}
