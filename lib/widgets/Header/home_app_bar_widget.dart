import 'dart:ui';
import 'package:flutter/material.dart';
import '../profile/user_info_widget.dart';
import '../profile/user_options_sheet_widget.dart';
import 'header_actions_widget.dart';
import '../time/time_display_widget.dart';
import '../notifications/notifications_sheet_widget.dart';
import '../../models/user.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/Settings/settings_page.dart';
import '../../screens/Search/search_screen.dart';
import '../../screens/Transport/transport_calculator_screen.dart';

class HomeAppBar extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final User user;
  final String currentRole;
  final ValueChanged<String> onRoleChanged;

  const HomeAppBar({
    super.key,
    required this.scaffoldKey,
    required this.user,
    required this.currentRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.topRight,
              colors: [
                const Color(0xFF4F46E5).withOpacity(0.9),
                const Color(0xFF6366F1).withOpacity(0.9),
                const Color(0xFF818CF8).withOpacity(0.9),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  _GlassIconButton(
                    icon: Icons.menu_rounded,
                    onTap: () => scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    flex: 0,
                    fit: FlexFit.loose,
                    child: UserInfoWidget(
                      userName: user.fullName,
                      userRole: currentRole,
                      avatarUrl: user.avatarUrl,
                      onProfileTap: () => _showUserOptions(context),
                      onRoleSwitch: (newRole) {
                        onRoleChanged(newRole);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(context)!
                                  .roleChangedTo(newRole.toUpperCase()),
                            ),
                            backgroundColor: newRole == 'admin'
                                ? Colors.redAccent
                                : Colors.blueAccent,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  _GlassIconButton(
                    icon: Icons.directions_car_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const TransportCalculatorScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  const Spacer(),
                  const TimeDisplayWidget(),
                  const SizedBox(width: 12),
                  HeaderActionsWidget(
                    notificationCount: 3,
                    onNotificationTap: () {
                      showDialog(
                        context: context,
                        barrierColor: Colors.black.withOpacity(0.5),
                        builder: (context) => const NotificationsSheet(),
                      );
                    },
                    onSettingsTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                    },
                    onSearchTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SearchScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showUserOptions(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => UserOptionsSheet(
        user: user,
        currentRole: currentRole,
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
