import 'package:flutter/material.dart';

class HeaderActionsWidget extends StatelessWidget {
  final int notificationCount;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onSearchTap;

  const HeaderActionsWidget({
    super.key,
    this.notificationCount = 0,
    this.onNotificationTap,
    this.onSettingsTap,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
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
          _buildActionButton(
            icon: Icons.search_rounded,
            onTap: onSearchTap,
            tooltip: 'Hľadať',
          ),
          const SizedBox(width: 2),
          _buildActionButton(
            icon: Icons.settings_outlined,
            onTap: onSettingsTap,
            tooltip: 'Nastavenia',
          ),
          const SizedBox(width: 2),
          _buildNotificationButton(),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              color: const Color(0xFF4A4A4A),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
        _buildActionButton(
          icon: Icons.notifications_none_rounded,
          onTap: onNotificationTap,
          tooltip: 'Notifikácie',
        ),
        if (notificationCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444), // Moderná červená
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
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