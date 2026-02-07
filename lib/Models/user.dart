class User {
  final int? id;
  final String username;
  final String password;
  final String fullName;
  final String role; // 'admin' or 'user'
  final String email;
  final String phone;
  final String department;
  final String avatarUrl;
  final DateTime joinDate;

  User({
    this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.role,
    required this.email,
    required this.phone,
    required this.department,
    required this.avatarUrl,
    required this.joinDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'full_name': fullName,
      'role': role,
      'email': email,
      'phone': phone,
      'department': department,
      'avatar_url': avatarUrl,
      'join_date': joinDate.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      password: map['password'] ?? '',
      fullName: map['full_name'],
      role: map['role'],
      email: map['email'],
      phone: map['phone'],
      department: map['department'],
      avatarUrl: map['avatar_url'],
      joinDate: DateTime.parse(map['join_date']),
    );
  }
}
