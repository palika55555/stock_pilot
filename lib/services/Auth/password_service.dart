import '../../models/user.dart';
import '../Database/database_service.dart';
import 'hash_service.dart';

class PasswordService {
  final DatabaseService _dbService = DatabaseService();

  /// Overí, či je zadané heslo správne pre daného používateľa.
  /// Podporuje starý plaintext aj nový SHA-256+salt formát.
  Future<bool> verifyPassword(String username, String password) async {
    final user = await _dbService.getUserByUsername(username);
    if (user == null) return false;
    return _verifyUserPassword(user, password);
  }

  /// Zmení heslo pre daného používateľa.
  /// Vracia true ak bola zmena úspešná.
  Future<bool> changePassword(
    String username,
    String currentPassword,
    String newPassword,
  ) async {
    final user = await _dbService.getUserByUsername(username);
    if (user == null || !_verifyUserPassword(user, currentPassword)) {
      return false;
    }

    // Nové heslo vždy hashujeme — nikdy neukladáme plaintext.
    final newSalt = HashService.generateSalt();
    final newHash = HashService.hashPassword(newPassword, newSalt);

    final updatedUser = User(
      id: user.id,
      username: user.username,
      password: newHash,
      passwordSalt: newSalt,
      fullName: user.fullName,
      role: user.role,
      email: user.email,
      phone: user.phone,
      department: user.department,
      avatarUrl: user.avatarUrl,
      joinDate: user.joinDate,
    );

    await _dbService.updateUser(updatedUser);
    return true;
  }

  /// Overí heslo — podporuje plaintext (starý) aj hash (nový).
  /// Plaintext fallback je tu len pre migráciu; po prvom logine
  /// je záznam automaticky konvertovaný na hash.
  bool _verifyUserPassword(User user, String rawPassword) {
    final salt = user.passwordSalt;
    if (salt == null || salt.isEmpty) {
      // Starý plaintext záznam — porovnaj priamo.
      return user.password == rawPassword;
    }
    return HashService.verifyPassword(rawPassword, user.password, salt);
  }
}
