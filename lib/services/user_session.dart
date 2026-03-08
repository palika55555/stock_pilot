import 'Database/database_service.dart';

/// In-memory session for the current user. Primary source of userId so we do not
/// rely on SharedPreferences (unreliable with sqflite_common_ffi on Windows).
class UserSession {
  static String? _userId;
  static String? _username;
  static String? _role;

  static void setUser({
    required String userId,
    required String username,
    required String role,
  }) {
    _userId = userId;
    _username = username;
    _role = role;
    DatabaseService.setCurrentUser(userId);
    print('DEBUG UserSession.setUser: userId=$userId');
  }

  static String? get userId => _userId;
  static String? get username => _username;
  static String? get role => _role;
  static bool get isLoggedIn => _userId != null && _userId!.isNotEmpty;

  static void clear() {
    _userId = null;
    _username = null;
    _role = null;
    DatabaseService.clearCurrentUser();
  }
}
