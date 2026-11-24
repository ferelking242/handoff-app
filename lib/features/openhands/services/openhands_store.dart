import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/openhands_models.dart';
import 'openhands_api.dart';

/// Persists the OpenHands token and the small amount of client configuration.
///
/// The token is a real credential, so it goes to the platform keychain when
/// available. Linux/desktop keychains are often locked in headless sessions,
/// so a preferences fallback keeps the client usable there.
class OpenHandsStore {
  OpenHandsStore({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String tokenKey = 'handoff.openhands.token';
  static const String baseUrlKey = 'handoff.openhands.base_url';
  static const String guardUrlKey = 'handoff.guard.url';
  static const String guardKeyKey = 'handoff.guard.key';

  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<String?> readToken() async {
    try {
      final value = await _secureStorage.read(key: tokenKey);
      if (value != null && value.isNotEmpty) return value;
    } catch (error) {
      debugPrint('OpenHandsStore: secure read failed: $error');
    }
    final prefs = await _preferences;
    final value = prefs.getString(tokenKey);
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> writeToken(String token) async {
    var stored = false;
    try {
      await _secureStorage.write(key: tokenKey, value: token);
      stored = true;
    } catch (error) {
      debugPrint('OpenHandsStore: secure write failed: $error');
    }
    if (!stored) {
      final prefs = await _preferences;
      await prefs.setString(tokenKey, token);
    }
  }

  Future<void> clearToken() async {
    try {
      await _secureStorage.delete(key: tokenKey);
    } catch (error) {
      debugPrint('OpenHandsStore: secure delete failed: $error');
    }
    final prefs = await _preferences;
    await prefs.remove(tokenKey);
  }

  Future<String> readBaseUrl() async {
    final prefs = await _preferences;
    final value = prefs.getString(baseUrlKey);
    return value == null || value.trim().isEmpty
        ? OpenHandsApi.defaultBaseUrl
        : value;
  }

  Future<void> writeBaseUrl(String value) async {
    final prefs = await _preferences;
    await prefs.setString(
      baseUrlKey,
      OpenHandsApi.normalizeBaseUrl(value),
    );
  }

  Future<GuardConfig> readGuardConfig() async {
    final prefs = await _preferences;
    return GuardConfig(
      url: prefs.getString(guardUrlKey) ?? '',
      key: prefs.getString(guardKeyKey) ?? '',
    );
  }

  Future<void> writeGuardConfig(GuardConfig config) async {
    final prefs = await _preferences;
    await prefs.setString(guardUrlKey, config.url.trim());
    await prefs.setString(guardKeyKey, config.key.trim());
  }
}
