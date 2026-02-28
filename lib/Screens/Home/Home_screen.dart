import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/common/app_drawer_widget.dart';
import '../../widgets/Header/home_app_bar_widget.dart';
import '../../widgets/Home/home_overview_widget.dart';
import '../../models/user.dart';
import '../../services/Database/database_service.dart';
import '../../services/api_sync_service.dart';
import '../../services/sync_check_service.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  final RouteObserver<ModalRoute<void>>? routeObserver;

  const HomeScreen({super.key, required this.user, this.routeObserver});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DatabaseService _db = DatabaseService();
  late String _currentRole;
  StreamSubscription<void>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _currentRole = 'user';
    _persistCurrentUser();
    WidgetsBinding.instance.addObserver(this);
    SyncCheckService.instance.start();
    _syncSubscription = SyncCheckService.instance.syncNeeded.listen((_) {
      if (!mounted) return;
      _showSyncNeededSnackBar();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncSubscription?.cancel();
    SyncCheckService.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SyncCheckService.instance.start();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      SyncCheckService.instance.stop();
    }
  }

  void _showSyncNeededSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade200, size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Na webe boli zmeny v zákazníkoch. Obnoviť dáta?'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Obnoviť',
          textColor: Colors.amber,
          onPressed: () => _pullCustomersFromBackend(),
        ),
      ),
    );
  }

  Future<void> _pullCustomersFromBackend() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final token = getBackendToken();
    if (token == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Obnova z webu vyžaduje prihlásenie (odhlásite sa a prihláste znova)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final list = await fetchCustomersFromBackendWithToken(token);
    if (list != null && list.isNotEmpty && mounted) {
      await _db.replaceCustomersFromBackend(list);
    }
    // Nahratie produktov na web – skenovanie na webe potom zobrazí názov a množstvo
    if (mounted) {
      final products = await _db.getProducts();
      syncProductsToBackend(products);
    }
    // Stiahnutie EAN z webu – priradenia z webového skenera sa prejavia v apke
    if (mounted && token != null) {
      final backendProducts = await fetchProductsFromBackendWithToken(token);
      if (backendProducts != null && backendProducts.isNotEmpty) {
        await _db.updateProductEanFromBackend(backendProducts);
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dáta boli synchronizované s webom (zákazníci + produkty + EAN)'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
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
