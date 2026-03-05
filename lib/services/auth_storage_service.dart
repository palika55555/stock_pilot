import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for JWT access and refresh tokens (not SharedPreferences).
class AuthStorageService {
  AuthStorageService._();
  static final AuthStorageService instance = AuthStorageService._();

  static const _keyAccessToken = 'stock_pilot_access_token';
  static const _keyRefreshToken = 'stock_pilot_refresh_token';
  static const _keyUserId = 'stock_pilot_user_id';

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
  }

  Future<bool> hasStoredTokens() async {
    final access = await getAccessToken();
    return access != null && access.isNotEmpty;
  }

  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }
}
