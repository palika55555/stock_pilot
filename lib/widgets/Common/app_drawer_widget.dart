import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:stock_pilot/screens/scanner/scan_product.dart';
import 'package:stock_pilot/screens/warehouse/warehouse_supplies.dart';
import 'package:stock_pilot/screens/warehouse/warehouses_page.dart';
import 'package:stock_pilot/screens/login/login_page.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/screens/customers/customers_page.dart';
import 'package:stock_pilot/screens/suppliers/suppliers_page.dart';
import 'package:stock_pilot/screens/warehouse/warehouse_movements_screen.dart';
import 'package:stock_pilot/screens/Settings/settings_page.dart';
import 'package:stock_pilot/l10n/app_localizations.dart';

class AppDrawer extends StatelessWidget {
  final String userRole;
  const AppDrawer({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent, // Nutne pre Glassmorphism
      elevation: 0,
      child: Stack(
        children: [
          // 1. Sklenený efekt (Blur a jemné šedé pozadie)
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(
                    0.4,
                  ), // Jemná šedá/biela priehľadnosť
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.6),
                      Colors.grey.withOpacity(0.1),
                    ],
                  ),
                  border: Border(
                    right: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                ),
              ),
            ),
          ),

          // 2. Obsah menu
          SafeArea(
            child: Column(
              children: [
                _AnimatedDrawerHeader(userRole: userRole),
                const SizedBox(height: 10),
                Expanded(child: _MenuItemsList(userRole: userRole)),
                const Divider(color: Colors.white30, indent: 20, endIndent: 20),
                _LogoutItem(),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Konštantné widgety pre lepší výkon
class _DrawerHeader extends StatelessWidget {
  final String userRole;
  const _DrawerHeader({required this.userRole});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          // Ikona s jemným tieňom
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(
                0xFF3F3D56,
              ).withOpacity(0.8), // Tmavošedá/modrá z loga
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'StockPilot v1.0',
            style: TextStyle(
              color: Color(0xFF2F2E41),
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          Text(
            userRole.toUpperCase(),
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Animovaná hlavička draweru
class _AnimatedDrawerHeader extends StatefulWidget {
  final String userRole;
  const _AnimatedDrawerHeader({required this.userRole});

  @override
  State<_AnimatedDrawerHeader> createState() => _AnimatedDrawerHeaderState();
}

class _AnimatedDrawerHeaderState extends State<_AnimatedDrawerHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Spustíme animáciu okamžite
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: _DrawerHeader(userRole: widget.userRole),
          ),
        );
      },
    );
  }
}

class _MenuItemsList extends StatelessWidget {
  final String userRole;
  const _MenuItemsList({required this.userRole});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: EdgeInsets.zero,
      cacheExtent: 250.0,
      children: [
        _AnimatedMenuItem(
          delay: 100,
          icon: Icons.dashboard_rounded,
          title: l10n.overview,
          onTap: () => Navigator.pop(context),
        ),
        _AnimatedMenuItem(
          delay: 150,
          icon: Icons.qr_code_scanner_rounded,
          title: l10n.scanProduct,
          onTap: () {
            // 1. Najprv zavrieme Drawer
            Navigator.pop(context);
            // 2. Potom navigujeme na obrazovku skenera
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ScanProductScreen(),
              ),
            );
          },
        ),
        _AnimatedMenuItem(
          delay: 200,
          icon: Icons.warehouse_rounded,
          title: l10n.warehouses,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WarehousesPage()),
            );
          },
        ),
        _AnimatedMenuItem(
          delay: 250,
          icon: Icons.storage_rounded,
          title: l10n.warehouseSupplies,
          onTap: () {
            Navigator.pop(context); // Zavrie menu
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    WarehouseSuppliesScreen(userRole: userRole),
              ),
            );
          },
        ),
        _AnimatedMenuItem(
          delay: 300,
          icon: Icons.swap_horiz_rounded,
          title: l10n.warehouseMovements,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WarehouseMovementsScreen(userRole: userRole),
              ),
            );
          },
        ),
        _AnimatedMenuItem(
          delay: 400,
          icon: Icons.business_center_rounded,
          title: l10n.suppliers,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SuppliersPage()),
            );
          },
        ),
        _AnimatedMenuItem(
          delay: 450,
          icon: Icons.people_rounded,
          title: l10n.customers,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CustomersPage()),
            );
          },
        ),
        const Divider(),
        _AnimatedMenuItem(
          delay: 500,
          icon: Icons.settings_rounded,
          title: l10n.settings,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SettingsPage(userRole: userRole)),
            );
          },
        ),
      ],
    );
  }
}

class _LogoutItem extends StatelessWidget {
  const _LogoutItem();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _AnimatedMenuItem(
      delay: 500,
      icon: Icons.logout_rounded,
      title: l10n.logout,
      color: Colors.redAccent.withOpacity(0.8),
      onTap: () async {
        await DatabaseService().clearSavedLogin();
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      },
    );
  }
}

// Optimalizovaný menu item widget s lepšími transitionmi
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          splashColor: Colors.white.withOpacity(0.3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              // Efekt aktívnej položky (voliteľné)
              color: Colors.white.withOpacity(0.2),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color:
                      color ?? const Color(0xFF575ED8), // Moderná modro-fialová
                  size: 24,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color ?? const Color(0xFF2F2E41),
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Animovaný menu item s postupným zobrazením
class _AnimatedMenuItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;
  final int delay;

  const _AnimatedMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
    required this.delay,
  });

  @override
  State<_AnimatedMenuItem> createState() => _AnimatedMenuItemState();
}

class _AnimatedMenuItemState extends State<_AnimatedMenuItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -30.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Spustíme animáciu s oneskorením
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value, 0),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: _MenuItem(
              icon: widget.icon,
              title: widget.title,
              onTap: widget.onTap,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}
