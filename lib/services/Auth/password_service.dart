import '../../models/user.dart';
import '../database/database_service.dart';

class PasswordService {
  final DatabaseService _dbService = DatabaseService();

  /// Overí, či je zadané heslo správne pre daného používateľa
  Future<bool> verifyPassword(String username, String password) async {
    User? user = await _dbService.getUserByUsername(username);
    return user != null && user.password == password;
  }

  /// Zmení heslo pre daného používateľa
  /// Vracia true ak bola zmena úspešná, false ak používateľ neexistuje
  /// Vyhodí výnimku ak nastane chyba
  Future<bool> changePassword(
    String username,
    String currentPassword,
    String newPassword,
  ) async {
    // Overenie používateľa a súčasného hesla
    User? user = await _dbService.getUserByUsername(username);

    if (user == null || user.password != currentPassword) {
      return false;
    }

    // Aktualizácia hesla
    final updatedUser = User(
      id: user.id,
      username: user.username,
      password: newPassword,
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
}
