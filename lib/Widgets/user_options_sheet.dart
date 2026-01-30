import 'package:flutter/material.dart';
import '../Models/user.dart';
import 'profile_page.dart';
import 'login_page.dart';

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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header s user info
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  backgroundImage: NetworkImage(user.avatarUrl),
                  child: user.avatarUrl.isEmpty
                      ? const Icon(Icons.person_rounded, color: Colors.blueAccent, size: 30)
                      : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        currentRole.toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          color: currentRole == 'admin' ? Colors.red : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Možnosti
          ListTile(
            leading: const Icon(Icons.person_outline, color: Colors.blue),
            title: const Text('Profil'),
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
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Colors.grey),
            title: const Text('Nastavenia'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nastavenia - v príprave')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined, color: Colors.orange),
            title: const Text('Notifikácie'),
            trailing: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
              child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifikácie - v príprave')),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Odhlásiť sa'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (Route<dynamic> route) => false,
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}




