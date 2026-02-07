class ChangePasswordRequest {
  final String username;
  final String currentPassword;
  final String newPassword;
  final String confirmPassword;

  ChangePasswordRequest({
    required this.username,
    required this.currentPassword,
    required this.newPassword,
    required this.confirmPassword,
  });

  /// Validuje požiadavku na zmenu hesla
  /// Vracia null ak je validná, inak vráti chybovú správu
  String? validate() {
    if (username.isEmpty) {
      return 'Username is required';
    }
    if (currentPassword.isEmpty) {
      return 'Current password is required';
    }
    if (newPassword.isEmpty) {
      return 'New password is required';
    }
    if (newPassword.length < 4) {
      return 'Password must be at least 4 characters';
    }
    if (newPassword != confirmPassword) {
      return 'Passwords do not match';
    }
    if (currentPassword == newPassword) {
      return 'New password must be different from current password';
    }
    return null;
  }
}
