import '../../models/change_password_request.dart';
import 'password_service.dart';

/// Service pre zmenu hesla - obsahuje len business logiku bez UI
class ChangePasswordService {
  final PasswordService _passwordService = PasswordService();

  /// ZmenĂ­ heslo pouĹľĂ­vateÄľa
  /// VrĂˇti true ak bola zmena ĂşspeĹˇnĂˇ, false inak
  /// VyhodĂ­ vĂ˝nimku pri chybe
  Future<bool> changePassword({
    required String username,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    // ValidĂˇcia pomocou modelu
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

    // SkĂşsime zmeniĹĄ heslo
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
