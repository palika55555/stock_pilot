import '../../models/change_password_request.dart';
import 'password_service.dart';

/// Service pre zmenu hesla - obsahuje len business logiku bez UI
class ChangePasswordService {
  final PasswordService _passwordService = PasswordService();

  /// Zmení heslo používateľa
  /// Vráti true ak bola zmena úspešná, false inak
  /// Vyhodí výnimku pri chybe
  Future<bool> changePassword({
    required String username,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    // Validácia pomocou modelu
    final request = ChangePasswordRequest(
      username: username,
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );

    final validationError = request.validate();
    if (validationError != null) {
      throw Exception(validationError);
    }

    // Skúsime zmeniť heslo
    final success = await _passwordService.changePassword(
      username,
      currentPassword,
      newPassword,
    );

    if (!success) {
      throw Exception('Invalid current password');
    }

    return true;
  }
}
