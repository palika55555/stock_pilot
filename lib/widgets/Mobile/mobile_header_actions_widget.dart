import 'package:flutter/material.dart';

class MobileHeaderActionsWidget extends StatelessWidget {
  final int notificationCount;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onSearchTap;

  const MobileHeaderActionsWidget({
    super.key,
    this.notificationCount = 0,
    this.onNotificationTap,
    this.onSettingsTap,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search
            _buildActionButton(Icons.search_rounded, onSearchTap, 'Hľadať'),
            const SizedBox(width: 2),
            // Notifications
            _buildNotificationButton(),
            const SizedBox(width: 2),
            // Settings
            _buildActionButton(
              Icons.settings_outlined,
              onSettingsTap,
              'Nastavenia',
            ),
            const SizedBox(width: 2),
            // More
            _buildActionButton(Icons.more_vert, null, 'Viac'),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Hľadať',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          onTap: () {
            Navigator.pop(context);
            onSearchTap?.call();
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 18,
                color: Colors.grey[700],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Notifikácie',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          onTap: () {
            Navigator.pop(context);
            onNotificationTap?.call();
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nastavenia',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          onTap: () {
            Navigator.pop(context);
            onSettingsTap?.call();
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    VoidCallback? onTap,
    String tooltip,
  ) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.grey[700], size: 18),
      ),
    );
  }

  Widget _buildNotificationButton() {
    return Stack(
      children: [
        Tooltip(
          message: 'Notifikácie',
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: Colors.grey[700],
              size: 18,
            ),
          ),
        ),
        if (notificationCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
              child: Center(
                child: Text(
                  notificationCount > 9 ? '9+' : notificationCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
