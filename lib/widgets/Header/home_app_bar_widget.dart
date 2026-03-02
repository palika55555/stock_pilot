import 'dart:ui';
import 'package:flutter/material.dart';
import '../profile/user_info_widget.dart';
import '../profile/user_options_sheet_widget.dart';
import 'header_actions_widget.dart';
import '../Time/time_display_widget.dart';
import '../../models/user.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/Settings/settings_page.dart';
import '../../screens/Search/search_screen.dart';
import '../../screens/Transport/transport_calculator_screen.dart';

const Color _kHomeAppBarBg = Color(0xFF212124);
const Color _kHomeAccent = Color(0xFFFFC107);
const Color _kHomeAppBarText = Color(0xFFFFFFFF);

class HomeAppBar extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final User user;
  final String currentRole;
  final ValueChanged<String> onRoleChanged;
  final RouteObserver<ModalRoute<void>>? routeObserver;
  final int notificationUnreadCount;
  final VoidCallback? onNotificationTap;

  const HomeAppBar({
    super.key,
    required this.scaffoldKey,
    required this.user,
    required this.currentRole,
    required this.onRoleChanged,
    this.routeObserver,
    this.notificationUnreadCount = 0,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: _kHomeAppBarBg.withOpacity(0.95),
            border: Border(
              bottom: BorderSide(
                color: _kHomeAccent.withOpacity(0.25),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
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
                  TimeDisplayWidget(routeObserver: routeObserver),
                  const SizedBox(width: 12),
                  HeaderActionsWidget(
                    notificationCount: notificationUnreadCount,
                    onNotificationTap: onNotificationTap ?? () {},
                    onSettingsTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsPage(userRole: currentRole),
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
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _kHomeAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: _kHomeAppBarText, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
