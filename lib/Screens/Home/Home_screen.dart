import 'package:flutter/material.dart';
import '../../Widgets/user_info_widget.dart';
import '../../Widgets/header_actions_widget.dart';
import '../../Widgets/time_display_widget.dart';
import '../../Widgets/app_drawer.dart';
import '../../Widgets/user_options_sheet.dart';
import '../../Widgets/home_overview.dart';
import '../../Models/user.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late String _currentRole;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.user.role;
  }

  void _showUserOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => UserOptionsSheet(
        user: widget.user,
        currentRole: _currentRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawerScrimColor: Colors.black54,
      drawer: AppDrawer(userRole: _currentRole),
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        elevation: 0,
        title: Row(
          children: [
            UserInfoWidget(
              userName: widget.user.fullName,
              userRole: _currentRole,
              avatarUrl: widget.user.avatarUrl,
              onProfileTap: () => _showUserOptions(context),
              onRoleSwitch: (newRole) {
                setState(() => _currentRole = newRole);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Rola zmenená na ${newRole.toUpperCase()}'),
                    backgroundColor: newRole == 'admin' ? Colors.redAccent : Colors.blueAccent,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            const Spacer(),
            const TimeDisplayWidget(),
            const SizedBox(width: 12),
            HeaderActionsWidget(
              notificationCount: 3,
              onNotificationTap: () {},
              onSettingsTap: () {},
              onSearchTap: () {},
            ),
            const SizedBox(width: 16),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: const RepaintBoundary(
        child: HomeOverview(),
      ),
    );
  }
}
