import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/models/change_password_request.dart';

void main() {
  group('ChangePasswordRequest', () {
    test('validate vráti null pri platných údajoch', () {
      // Arrange
      final request = ChangePasswordRequest(
        username: 'user1',
        currentPassword: 'oldPass123',
        newPassword: 'newPass456',
        confirmPassword: 'newPass456',
      );

      // Act
      final error = request.validate();

      // Assert
      expect(error, isNull);
    });

    test('validate vráti chybu keď je username prázdny', () {
      // Arrange
      final request = ChangePasswordRequest(
        username: '',
        currentPassword: 'old',
        newPassword: 'new1234',
        confirmPassword: 'new1234',
      );

      // Act
      final error = request.validate();

      // Assert
      expect(error, 'Username is required');
    });

    test('validate vráti chybu keď je currentPassword prázdny', () {
      // Arrange
      final request = ChangePasswordRequest(
        username: 'user',
        currentPassword: '',
        newPassword: 'new1234',
        confirmPassword: 'new1234',
      );

      // Act
      final error = request.validate();

      // Assert
      expect(error, 'Current password is required');
    });

    test('validate vráti chybu keď je newPassword prázdny', () {
      // Arrange
      final request = ChangePasswordRequest(
        username: 'user',
        currentPassword: 'old',
        newPassword: '',
        confirmPassword: '',
      );

      // Act
      final error = request.validate();

      // Assert
      expect(error, 'New password is required');
    });

    test('validate vráti chybu keď je newPassword kratší ako 4 znaky', () {
      // Arrange
      final request = ChangePasswordRequest(
        username: 'user',
        currentPassword: 'old',
        newPassword: '123',
        confirmPassword: '123',
      );

      // Act
      final error = request.validate();

      // Assert
      expect(error, 'Password must be at least 4 characters');
    });

    test('validate vráti chybu keď sa newPassword a confirmPassword nezhodujú', () {
      // Arrange
      final request = ChangePasswordRequest(
        username: 'user',
        currentPassword: 'old',
        newPassword: 'new1234',
        confirmPassword: 'new5678',
      );

      // Act
      final error = request.validate();

      // Assert
      expect(error, 'Passwords do not match');
    });

    test('validate vráti chybu keď je newPassword rovnaké ako currentPassword', () {
      // Arrange
      final request = ChangePasswordRequest(
        username: 'user',
        currentPassword: 'samePass',
        newPassword: 'samePass',
        confirmPassword: 'samePass',
      );

      // Act
      final error = request.validate();

      // Assert
      expect(error, 'New password must be different from current password');
    });

    test('validate prijíma nové heslo s presne 4 znakmi', () {
      // Arrange
      final request = ChangePasswordRequest(
        username: 'user',
        currentPassword: 'old',
        newPassword: '1234',
        confirmPassword: '1234',
      );

      // Act
      final error = request.validate();

      // Assert
      expect(error, isNull);
    });
  });
}
