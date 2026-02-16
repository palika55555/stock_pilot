import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/models/user.dart';

void main() {
  group('User', () {
    test('fromMap vytvorí inštanciu zo všetkých polí', () {
      // Arrange
      final map = {
        'id': 1,
        'username': 'admin',
        'password': 'secret',
        'full_name': 'Admin User',
        'role': 'admin',
        'email': 'admin@test.sk',
        'phone': '+421900000',
        'department': 'IT',
        'avatar_url': '/avatar.png',
        'join_date': '2025-01-01T00:00:00.000',
      };

      // Act
      final user = User.fromMap(map);

      // Assert
      expect(user.id, 1);
      expect(user.username, 'admin');
      expect(user.password, 'secret');
      expect(user.fullName, 'Admin User');
      expect(user.role, 'admin');
      expect(user.email, 'admin@test.sk');
      expect(user.joinDate, DateTime(2025, 1, 1));
    });

    test('fromMap používa prázdny reťazec pre chýbajúce password', () {
      // Arrange
      final map = {
        'id': 1,
        'username': 'u',
        'full_name': 'F',
        'role': 'user',
        'email': 'e@e.sk',
        'phone': '',
        'department': '',
        'avatar_url': '',
        'join_date': '2024-06-15T12:00:00.000',
      };

      // Act
      final user = User.fromMap(map);

      // Assert
      expect(user.password, '');
    });

    test('toMap vráti mapu zhodnú s fromMap', () {
      // Arrange
      final user = User(
        id: 2,
        username: 'john',
        password: 'pass',
        fullName: 'John Doe',
        role: 'user',
        email: 'john@test.sk',
        phone: '0900',
        department: 'Sales',
        avatarUrl: '',
        joinDate: DateTime(2024, 3, 10),
      );

      // Act
      final map = user.toMap();
      final restored = User.fromMap(map);

      // Assert
      expect(restored.id, user.id);
      expect(restored.username, user.username);
      expect(restored.password, user.password);
      expect(restored.fullName, user.fullName);
      expect(restored.role, user.role);
      expect(restored.joinDate, user.joinDate);
    });
  });
}
