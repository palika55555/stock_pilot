import 'package:flutter/material.dart';
import '../../screens/login/login_page.dart';
import '../../services/Database/database_service.dart';

class MobileUserInfoWidget extends StatelessWidget {
  final String userName;
  final String userRole;
  final String? avatarUrl;
  final VoidCallback? onProfileTap;
  final Function(String)? onRoleSwitch; // Nový callback

  const MobileUserInfoWidget({
    super.key,
    required this.userName,
    required this.userRole,
    this.avatarUrl,
    this.onProfileTap,
    this.onRoleSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blueAccent.withOpacity(0.1),
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: avatarUrl == null
                  ? Icon(
                      Icons.person_rounded,
                      color: Colors.blueAccent,
                      size: 18,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            // User info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  userRole,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            // Dropdown arrow
            Icon(Icons.keyboard_arrow_down, color: Colors.grey[600], size: 16),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.person, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Profil',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      userName,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          onTap: () {
            Navigator.pop(context);
            onProfileTap?.call();
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.sync_rounded, size: 16, color: Colors.blue[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Prepnúť rolu (${userRole == 'admin' ? 'User' : 'Admin'})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          onTap: () {
            if (onRoleSwitch != null) {
              final newRole = userRole == 'admin' ? 'user' : 'admin';
              onRoleSwitch!(newRole);
            }
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.settings, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nastavenia',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          onTap: () {
            Navigator.pop(context);
            // TODO: Navigate to settings
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.logout, size: 16, color: Colors.red[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Odhlásiť',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          onTap: () async {
            await DatabaseService().clearSavedLogin();
            if (!context.mounted) return;
            Navigator.pop(context);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (Route<dynamic> route) => false,
            );
          },
        ),
      ],
    );
  }
}
