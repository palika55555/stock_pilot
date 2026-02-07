import 'package:flutter/material.dart';
import '../profile/mobile_user_info_widget.dart';
import '../header/header_actions_widget.dart';
import '../time/mobile_time_display_widget.dart';

class MobileDashboardHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  final bool showWelcome;
  final String userName;
  final String userRole;
  final String? avatarUrl;
  final int notificationCount;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onSearchTap;
  final Function(String)? onRoleSwitch; // Nový callback

  const MobileDashboardHeader({
    super.key,
    required this.title,
    this.subtitle = '',
    this.action,
    this.showWelcome = false,
    required this.userName,
    required this.userRole,
    this.avatarUrl,
    this.notificationCount = 0,
    this.onProfileTap,
    this.onNotificationTap,
    this.onSettingsTap,
    this.onSearchTap,
    this.onRoleSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- TOP NAV BAR ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // User info with dropdown
            Expanded(
              child: MobileUserInfoWidget(
                userName: userName,
                userRole: userRole,
                avatarUrl: avatarUrl,
                onProfileTap: onProfileTap,
                onRoleSwitch: onRoleSwitch,
              ),
            ),
            const SizedBox(width: 8),
            // Time display (compact)
            const MobileTimeDisplayWidget(),
            const SizedBox(width: 8),
            // Actions with dropdown
            HeaderActionsWidget(
              notificationCount: notificationCount,
              onNotificationTap: onNotificationTap,
              onSettingsTap: onSettingsTap,
              onSearchTap: onSearchTap,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // --- WELCOME SECTION ---
        if (showWelcome) ...[
          Text(
            'Ahoj, $userName 👋',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Vitajte späť v StockPilot. Tu je prehľad vášho skladu.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 20),
        ],

        // --- SECTION TITLE ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null)
              Padding(padding: const EdgeInsets.only(left: 12), child: action!),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
