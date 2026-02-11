import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../screens/profile/profile_page.dart';
import '../../screens/login/login_page.dart';
import '../../services/Database/database_service.dart';
import '../../screens/Settings/settings_page.dart';
import '../notifications/notifications_sheet_widget.dart';

class UserOptionsSheet extends StatelessWidget {
  final User user;
  final String currentRole;

  const UserOptionsSheet({
    super.key,
    required this.user,
    required this.currentRole,
  });

  @override
  Widget build(BuildContext context) {
    return _buildGlassUserModal(context);
  }

  Widget _buildGlassUserModal(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 30),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: -5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profilová sekcia
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: user.avatarUrl.isNotEmpty
                              ? NetworkImage(user.avatarUrl)
                              : null,
                          child: user.avatarUrl.isEmpty
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 30,
                                )
                              : null,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.fullName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.redAccent.withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  currentRole.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const Divider(color: Colors.white12),
                    _buildModalItem(
                      context,
                      Icons.person_outline,
                      "Profil",
                      Colors.white,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfilePage(
                              userId: user.id,
                              userName: user.fullName,
                              userRole: currentRole,
                              email: user.email,
                              phone: user.phone,
                              department: user.department,
                              avatarUrl: user.avatarUrl,
                              joinDate: user.joinDate,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildModalItem(
                      context,
                      Icons.settings_outlined,
                      "Nastavenia",
                      Colors.white,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SettingsPage(userRole: currentRole),
                          ),
                        );
                      },
                    ),
                    _buildModalItem(
                      context,
                      Icons.notifications_outlined,
                      "Notifikácie",
                      Colors.white,
                      trailing: "3",
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) => const NotificationsSheet(),
                        );
                      },
                    ),
                    const Divider(color: Colors.white12),
                    _buildModalItem(
                      context,
                      Icons.logout_rounded,
                      "Odhlásiť sa",
                      Colors.redAccent,
                      onTap: () async {
                        await DatabaseService().clearSavedLogin();
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalItem(
    BuildContext context,
    IconData icon,
    String title,
    Color color, {
    String? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: color.withOpacity(0.9),
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing != null
          ? Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: Text(
                trailing,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: onTap,
    );
  }
}
