import 'dart:ui';
import 'package:flutter/material.dart';
import '../profile/user_info_widget.dart';
import '../header/header_actions_widget.dart';
import '../time/time_display_widget.dart';

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
  final Function(String)? onRoleSwitch;

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
        // --- TOP NAV BAR (Fade in + Slide zhora) ---
        _AnimateIn(
          delay: 0,
          direction: AxisDirection.down,
          child: Row(
            children: [
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
              // Sklenený efekt pre čas s upravenými farbami
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const TimeDisplayWidget(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              HeaderActionsWidget(
                notificationCount: notificationCount,
                onNotificationTap: onNotificationTap,
                onSettingsTap: onSettingsTap,
                onSearchTap: onSearchTap,
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // --- WELCOME SECTION ---
        if (showWelcome) ...[
          _AnimateIn(
            delay: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Biely text s jemnou žiarou namiesto šedej
                Text(
                  'Ahoj, $userName 👋',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.2),
                        offset: const Offset(0, 4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vitajte späť v StockPilot. Tu je prehľad vášho skladu.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7), // Priehľadná biela
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],

        // --- SECTION TITLE & ACTION ---
        _AnimateIn(
          delay: 400,
          direction: AxisDirection.right,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        // Výraznejšia neónová fialová pre štítok
                        color: const Color(0xFF9E92FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF9E92FF).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Color(0xFFC4B5FD), // Svetlejšia fialová
                        ),
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null)
                // Akčné tlačidlo so skleneným efektom
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: action!,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- POMOCNÝ ANIMÁČNÝ WIDGET ---
class _AnimateIn extends StatelessWidget {
  final Widget child;
  final int delay;
  final AxisDirection direction;

  const _AnimateIn({
    required this.child,
    required this.delay,
    this.direction = AxisDirection.up,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),

      curve: Interval(
        (delay / 1000).clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeOutExpo,
      ),
      builder: (context, value, child) {
        double offsetX = 0;
        double offsetY = 0;

        if (direction == AxisDirection.up) offsetY = 20 * (1 - value);
        if (direction == AxisDirection.down) offsetY = -20 * (1 - value);
        if (direction == AxisDirection.right) offsetX = -20 * (1 - value);

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(offsetX, offsetY),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
