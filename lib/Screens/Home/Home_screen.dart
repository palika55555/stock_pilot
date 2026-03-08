import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/common/app_drawer_widget.dart';
import '../../widgets/common/app_sidebar_widget.dart';
import '../../widgets/Home/home_overview_widget.dart';
import '../../models/user.dart';
import '../../services/Database/database_service.dart';
import '../../services/user_session.dart';
import '../../services/api_sync_service.dart';
import '../../services/sync_check_service.dart';
import '../../services/sync_service.dart';
import '../../services/Notifications/notification_service.dart';
import '../../screens/Notifications/notification_center_screen.dart';
import '../../screens/Search/search_screen.dart';
import '../../theme/app_theme.dart';

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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasOffline = true;
  int _notificationUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.user.role;
    // Použiť userId zo session (z backendu = 1), inak fallback na lokálne user.id – aby zákazníci/dáta sedeli s backendom
    final userId = UserSession.userId ?? widget.user.id?.toString() ?? widget.user.username;
    if (UserSession.userId == null || UserSession.userId!.isEmpty) {
      UserSession.setUser(
        userId: userId,
        username: widget.user.username,
        role: widget.user.role,
      );
    } else {
      DatabaseService.setCurrentUser(userId);
    }
    print('DEBUG HomeScreen.initState: userId=$userId (session=${UserSession.userId})');
    _persistCurrentUser();
    _refreshNotificationCount();
    WidgetsBinding.instance.addObserver(this);
    SyncCheckService.instance.start();
    SyncService.startSync(userId);
    _syncSubscription = SyncCheckService.instance.syncNeeded.listen((_) {
      if (!mounted) return;
      _showSyncNeededSnackBar();
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncProductsWithBackend();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        _pullCustomersFromBackend(silent: true);
      });
    });
  }

  void _onConnectivityChanged(List<ConnectivityResult> result) {
    final isOnline = result.isNotEmpty &&
        result.any((r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth);
    if (isOnline && _wasOffline) {
      _wasOffline = false;
      _pullCustomersFromBackend(silent: true);
    }
    if (!isOnline) _wasOffline = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncSubscription?.cancel();
    _connectivitySubscription?.cancel();
    SyncCheckService.instance.stop();
    SyncService.stopSync();
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

  Future<void> _syncProductsWithBackend() async {
    final token = getBackendToken();
    if (token == null || !mounted) return;
    try {
      final backendProducts = await fetchProductsFromBackendWithToken(token);
      if (backendProducts != null && backendProducts.isNotEmpty && mounted) {
        await _db.mergeProductsFromBackend(backendProducts);
      }
      if (!mounted) return;
      final products = await _db.getProducts();
      syncProductsToBackend(products);
    } catch (_) {}
  }

  void _showSyncNeededSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade200, size: 20),
            const SizedBox(width: 10),
            const Expanded(child: Text('Na webe boli zmeny v zákazníkoch. Obnoviť dáta?')),
          ],
        ),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Obnoviť',
          textColor: AppColors.accentGold,
          onPressed: _pullCustomersFromBackend,
        ),
      ),
    );
  }

  Future<void> _pullCustomersFromBackend({bool silent = false}) async {
    if (!silent) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final token = getBackendToken();
    if (token == null) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Obnova z webu vyžaduje prihlásenie')),
        );
      }
      return;
    }
    final list = await fetchCustomersFromBackendWithToken(token);
    if (list != null && list.isNotEmpty && mounted) {
      await _db.replaceCustomersFromBackend(list);
    }
    if (mounted && token != null) {
      final backendProducts = await fetchProductsFromBackendWithToken(token);
      if (backendProducts != null && backendProducts.isNotEmpty) {
        await _db.mergeProductsFromBackend(backendProducts);
      }
    }
    if (mounted) {
      final products = await _db.getProducts();
      syncProductsToBackend(products);
    }
    if (mounted && !silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dáta synchronizované s webom'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _persistCurrentUser() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('current_user_fullname', widget.user.fullName);
      prefs.setString('current_user_username', widget.user.username);
      prefs.setString('current_user_role', _currentRole);
    });
  }

  /// Dočasne prepne rolu (user ↔ admin): aktualizuje lokálnu DB, synchronizuje na backend a obnoví JWT.
  Future<void> _switchRole(String newRole) async {
    if (newRole == _currentRole) return;
    final username = UserSession.username ?? widget.user.username;
    final user = await _db.getUserByUsername(username);
    if (user == null || !mounted) return;
    final updatedUser = User(
      id: user.id,
      username: user.username,
      password: user.password,
      fullName: user.fullName,
      role: newRole,
      email: user.email,
      phone: user.phone,
      department: user.department,
      avatarUrl: user.avatarUrl,
      joinDate: user.joinDate,
    );
    await _db.updateUser(updatedUser);
    if (!mounted) return;
    await syncUserToBackend(updatedUser);
    if (!mounted) return;
    final newToken = await refreshAccessToken();
    if (newToken != null && mounted) {
      UserSession.setUser(
        userId: UserSession.userId ?? widget.user.id?.toString() ?? widget.user.username,
        username: username,
        role: newRole,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_role', newRole);
      setState(() => _currentRole = newRole);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rola zmenená na ${newRole == 'admin' ? 'administrátora' : 'používateľa'}. Synchronizované s backendom.'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rola sa zmenila lokálne. Obnovte pripojenie alebo sa znova prihláste pre sync s backendom.'),
          backgroundColor: Colors.orange,
        ),
      );
      UserSession.setUser(
        userId: UserSession.userId ?? widget.user.id?.toString() ?? widget.user.username,
        username: username,
        role: newRole,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_role', newRole);
      setState(() => _currentRole = newRole);
    }
  }

  Future<void> _refreshNotificationCount() async {
    final c = await _notificationService.getUnreadCount(widget.user.username);
    if (mounted) setState(() => _notificationUnreadCount = c);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    if (isDesktop) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Row(
        children: [
          AppSidebar(
            user: widget.user,
            userRole: _currentRole,
            activeIndex: 0,
            onSwitchRole: _switchRole,
          ),
          Expanded(
            child: HomeOverview(
              userRole: _currentRole,
              user: widget.user,
              notificationUnreadCount: _notificationUnreadCount,
              onNotificationTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
                );
                _refreshNotificationCount();
              },
              onSyncFromBackend: _pullCustomersFromBackend,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bgPrimary,
      drawerScrimColor: Colors.black54,
      drawer: AppDrawer(
        userRole: _currentRole,
        onSwitchRole: _switchRole,
      ),
      appBar: _buildMobileAppBar(),
      body: HomeOverview(
        userRole: _currentRole,
        user: widget.user,
        notificationUnreadCount: _notificationUnreadCount,
        onNotificationTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
          );
          _refreshNotificationCount();
        },
        onSyncFromBackend: _pullCustomersFromBackend,
      ),
      bottomNavigationBar: AppBottomNavBar(
        activeIndex: 0,
        scaffoldKey: _scaffoldKey,
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        height: 64 + MediaQuery.of(context).padding.top,
        decoration: const BoxDecoration(
          color: AppColors.bgPrimary,
          border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _MobileIconButton(
                  icon: Icons.menu_rounded,
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const SizedBox(width: 12),
                Text(
                  'Prehľad',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                _MobileIconButton(
                  icon: Icons.search_rounded,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _MobileIconButton(
                      icon: Icons.notifications_outlined,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
                        );
                        _refreshNotificationCount();
                      },
                    ),
                    if (_notificationUnreadCount > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.bgPrimary, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              _notificationUnreadCount > 9 ? '9+' : '$_notificationUnreadCount',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MobileIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderDefault, width: 1),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}
