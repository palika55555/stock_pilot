import 'package:flutter/material.dart';

class UserInfoWidget extends StatelessWidget {
  final String userName;
  final String userRole;
  final String? avatarUrl;
  final VoidCallback? onProfileTap;
  final Function(String)? onRoleSwitch; // Nový callback

  const UserInfoWidget({
    super.key,
    required this.userName,
    required this.userRole,
    this.avatarUrl,
    this.onProfileTap,
    this.onRoleSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onProfileTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20), // Zaoblenejšie rohy sú modernejšie
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar s jemným Glow efektom
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 2),
                ),
                child: CircleAvatar(
                  radius: 22,
                  
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person_rounded, color: Colors.blueAccent, size: 24)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // Textové informácie
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      if (onRoleSwitch != null) {
                        final newRole = userRole == 'admin' ? 'user' : 'admin';
                        onRoleSwitch!(newRole);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (userRole == 'admin' ? Colors.redAccent : Colors.blueAccent).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            userRole.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 0.5,
                              color: userRole == 'admin' ? Colors.redAccent : Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.sync_rounded,
                            size: 10,
                            color: userRole == 'admin' ? Colors.redAccent : Colors.blueAccent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Decentná šípka v krúžku
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blueAccent[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: Colors.blueAccent[400],
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}