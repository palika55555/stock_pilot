import 'package:flutter/material.dart';
import 'user_info_widget.dart';
import 'header_actions_widget.dart';
import 'time_display_widget.dart';

class DashboardHeader extends StatelessWidget {
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

  const DashboardHeader({
    super.key,
    required this.title,
    this.subtitle = '',
    this.action,
    this.showWelcome = false,
    this.userName = 'Používateľ',
    this.userRole = 'Skladník',
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
          children: [
            // User section expands and handles long names
            Expanded(
              child: UserInfoWidget(
                userName: userName,
                userRole: userRole,
                avatarUrl: avatarUrl,
                onProfileTap: onProfileTap,
                onRoleSwitch: onRoleSwitch,
              ),
            ),
            const SizedBox(width: 12),
            // Time and Quick Actions stay pinned to the right
            const TimeDisplayWidget(),
            const SizedBox(width: 12),
            HeaderActionsWidget(
              notificationCount: notificationCount,
              onNotificationTap: onNotificationTap,
              onSettingsTap: onSettingsTap,
              onSearchTap: onSearchTap,
            ),
          ],
        ),
        
        const SizedBox(height: 32),

        // --- WELCOME SECTION ---
        if (showWelcome) ...[
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF1A1A1A), Color(0xFF4A4A4A)],
            ).createShader(bounds),
            child: Text(
              'Ahoj, $userName 👋',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
                color: Colors.white, // Color is managed by ShaderMask
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vitajte späť v StockPilot. Tu je prehľad vášho skladu.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 32),
        ],

        // --- SECTION TITLE & ACTION ---
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
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) 
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: action!,
              ),
          ],
        ),
      ],
    );
  }
}