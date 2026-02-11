import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/common/app_drawer_widget.dart';
import '../../widgets/Header/home_app_bar_widget.dart';
import '../../widgets/Home/home_overview_widget.dart';
import '../../models/user.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  final RouteObserver<ModalRoute<void>>? routeObserver;

  const HomeScreen({super.key, required this.user, this.routeObserver});

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
    _persistCurrentUser();
  }

  void _persistCurrentUser() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('current_user_fullname', widget.user.fullName);
      prefs.setString('current_user_username', widget.user.username);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawerScrimColor: Colors.black54,
      drawer: AppDrawer(userRole: _currentRole),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: HomeAppBar(
          scaffoldKey: _scaffoldKey,
          user: widget.user,
          currentRole: _currentRole,
          onRoleChanged: (newRole) => setState(() => _currentRole = newRole),
          routeObserver: widget.routeObserver,
        ),
      ),
      body: RepaintBoundary(
        child: HomeOverview(userRole: _currentRole),
      ),
    );
  }
}
