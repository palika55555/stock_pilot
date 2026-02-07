import 'package:flutter/material.dart';
import '../../widgets/common/app_drawer_widget.dart';
import '../../widgets/header/home_app_bar_widget.dart';
import '../../widgets/home/home_overview_widget.dart';
import '../../models/user.dart';

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
        ),
      ),
      body: const RepaintBoundary(child: HomeOverview()),
    );
  }
}
