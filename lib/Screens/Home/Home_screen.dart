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
import '../../services/Notifications/notification_service.dart';
import '../../screens/Notifications/notification_center_screen.dart';

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
  final NotificationService _notificationService = NotificationService();
  late String _currentRole;
  StreamSubscription<void>? _syncSubscription;
  int _notificationUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _currentRole = 'user';
    _persistCurrentUser();
    _refreshNotificationCount();
    WidgetsBinding.instance.addObserver(this);
    SyncCheckService.instance.start();
    _syncSubscription = SyncCheckService.instance.syncNeeded.listen((_) {
      if (!mounted) return;
      _showSyncNeededSnackBar();
    });
    // Automatická synchronizácia produktov s webom (push na web + pull EAN) – ticho na pozadí
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncProductsWithBackend());
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
      _syncProductsWithBackend();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      SyncCheckService.instance.stop();
    }
  }

  /// Automatická synchronizácia produktov s webom: nahratie produktov na web + stiahnutie EAN priradených na webe.
  Future<void> _syncProductsWithBackend() async {
    final token = getBackendToken();
    if (token == null || !mounted) return;
    try {
      final products = await _db.getProducts();
      syncProductsToBackend(products);
      final backendProducts = await fetchProductsFromBackendWithToken(token);
      if (backendProducts != null && backendProducts.isNotEmpty && mounted) {
        await _db.updateProductEanFromBackend(backendProducts);
      }
    } catch (_) {
      // ticho – offline alebo chyba
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
    int eanUpdated = 0;
    if (mounted && token != null) {
      final backendProducts = await fetchProductsFromBackendWithToken(token);
      if (backendProducts != null && backendProducts.isNotEmpty) {
        eanUpdated = await _db.updateProductEanFromBackend(backendProducts);
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            eanUpdated > 0
                ? 'Dáta synchronizované. EAN z webu: aktualizovaných $eanUpdated produktov.'
                : 'Dáta boli synchronizované s webom (zákazníci + produkty + EAN)',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _persistCurrentUser() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('current_user_fullname', widget.user.fullName);
      prefs.setString('current_user_username', widget.user.username);
      prefs.setString('current_user_role', widget.user.role);
    });
  }

  Future<void> _refreshNotificationCount() async {
    final c = await _notificationService.getUnreadCount(widget.user.username);
    if (mounted) setState(() => _notificationUnreadCount = c);
  }

  static const Color _homeBgDark = Color(0xFF111114);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _homeBgDark,
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
          notificationUnreadCount: _notificationUnreadCount,
          onNotificationTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationCenterScreen(),
              ),
            );
            _refreshNotificationCount();
          },
        ),
      ),
      body: RepaintBoundary(
        child: HomeOverview(userRole: _currentRole),
      ),
    );
  }
}
