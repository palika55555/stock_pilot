import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Hashing hesiel pomocou SHA-256 + náhodný salt.
/// Používa sa len pre lokálnu offline DB cache.
class HashService {
  HashService._();

  static final Random _rng = Random.secure();

  /// Vygeneruje 16-byte náhodný salt ako hex string.
  static String generateSalt() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Zahashuje heslo so saltom: SHA-256(salt + ":" + password).
  /// Vráti hex digest.
  static String hashPassword(String password, String salt) {
    final input = utf8.encode('$salt:$password');
    return sha256.convert(input).toString();
  }

  /// Overí heslo voči uloženému hashu a saltu.
  /// Vráti true ak heslo sedí.
  static bool verifyPassword(String password, String storedHash, String salt) {
    final computed = hashPassword(password, salt);
    // Constant-time comparison aby sme predišli timing útokom.
    if (computed.length != storedHash.length) return false;
    var result = 0;
    for (var i = 0; i < computed.length; i++) {
      result |= computed.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    return result == 0;
  }
}
