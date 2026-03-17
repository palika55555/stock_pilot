import 'Database/database_service.dart';

/// In-memory session for the current user. Primary source of userId so we do not
/// rely on SharedPreferences (unreliable with sqflite_common_ffi on Windows).
class UserSession {
  static String? _userId;
  static String? _username;
  static String? _role;
  static String? _ownerFullName;
  static String? _ownerUsername;

  static void setUser({
    required String userId,
    required String username,
    required String role,
    String? ownerFullName,
    String? ownerUsername,
  }) {
    _userId = userId;
    _username = username;
    _role = role;
    _ownerFullName = ownerFullName;
    _ownerUsername = ownerUsername;
    DatabaseService.setCurrentUser(userId);
    print('DEBUG UserSession.setUser: userId=$userId owner=$_ownerFullName');
  }

  static String? get userId => _userId;
  static String? get username => _username;
  static String? get role => _role;
   /// Nadriadený (iba ak sme sub-user). Preferuje celé meno, fallback username.
  static String? get ownerDisplayName =>
      _ownerFullName?.isNotEmpty == true ? _ownerFullName : _ownerUsername;
  static bool get isLoggedIn => _userId != null && _userId!.isNotEmpty;

  static void clear() {
    _userId = null;
    _username = null;
    _role = null;
    _ownerFullName = null;
    _ownerUsername = null;
    DatabaseService.clearCurrentUser();
  }
}
