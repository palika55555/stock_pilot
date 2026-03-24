import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for JWT access and refresh tokens (not SharedPreferences).
class AuthStorageService {
  AuthStorageService._();
  static final AuthStorageService instance = AuthStorageService._();

  static const _keyAccessToken = 'stock_pilot_access_token';
  static const _keyRefreshToken = 'stock_pilot_refresh_token';
  static const _keyUserId = 'stock_pilot_user_id';
  /// Platnosť 24h – po úspešnom 2FA; ďalšie prihlásenie heslom nevyžaduje 2FA.
  static const _keyTwoFactorTrust = 'stock_pilot_twofa_trust_24h';
  /// Stabilné ID inštalácie – väzba trust tokenu na zariadenie (nemazať pri odhlásení).
  static const _keyClientDeviceId = 'stock_pilot_client_device_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);
  Future<String?> getUserId() => _storage.read(key: _keyUserId);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyTwoFactorTrust);
  }

  Future<String?> getTwoFactorTrustToken() => _storage.read(key: _keyTwoFactorTrust);

  Future<void> saveTwoFactorTrustToken(String token) async {
    await _storage.write(key: _keyTwoFactorTrust, value: token);
  }

  Future<bool> hasStoredTokens() async {
    final access = await getAccessToken();
    return access != null && access.isNotEmpty;
  }

  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  /// Jednoznačné ID tejto inštalácie (rovnaké pri každom prihlásení na tomto zariadení).
  Future<String> getOrCreateClientDeviceId() async {
    final existing = await _storage.read(key: _keyClientDeviceId);
    if (existing != null && existing.length >= 8) return existing;
    final rnd = Random.secure();
    final b = List<int>.generate(24, (_) => rnd.nextInt(256));
    final id = base64UrlEncode(b).replaceAll('=', '');
    await _storage.write(key: _keyClientDeviceId, value: id);
    return id;
  }
}
