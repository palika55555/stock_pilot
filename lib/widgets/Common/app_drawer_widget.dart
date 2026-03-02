import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:stock_pilot/screens/scanner/scan_product.dart';
import 'package:stock_pilot/screens/warehouse/warehouse_supplies.dart';
import 'package:stock_pilot/screens/warehouse/warehouses_page.dart';
import 'package:stock_pilot/screens/login/login_page.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/screens/customers/customers_page.dart';
import 'package:stock_pilot/screens/suppliers/suppliers_page.dart';
import 'package:stock_pilot/screens/production/production_list_screen.dart';
import 'package:stock_pilot/screens/Recipe/recipe_list_screen.dart';
import 'package:stock_pilot/screens/ProductionOrder/production_order_list_screen.dart';
import 'package:stock_pilot/screens/pallet/customers_pallets_screen.dart';
import 'package:stock_pilot/screens/warehouse/warehouse_movements_screen.dart';
import 'package:stock_pilot/screens/stock_out/stock_out_screen.dart';
import 'package:stock_pilot/screens/Reports/reports_list_screen.dart';
import 'package:stock_pilot/screens/Settings/settings_page.dart';
import 'package:stock_pilot/l10n/app_localizations.dart';
import 'package:stock_pilot/services/logout_service.dart';

const Color _kDrawerBg = Color(0xFF212124);
const Color _kDrawerText = Color(0xFFFFFFFF);
const Color _kDrawerTextMuted = Color(0xFFB0B0B5);
const Color _kDrawerAccent = Color(0xFFFFC107);

class AppDrawer extends StatelessWidget {
  final String userRole;
  const AppDrawer({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _kDrawerBg,
      elevation: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _AnimatedDrawerHeader(userRole: userRole),
              const SizedBox(height: 10),
              Expanded(child: _MenuItemsList(userRole: userRole)),
              Divider(color: _kDrawerTextMuted.withOpacity(0.3), indent: 20, endIndent: 20),
              _LogoutItem(),
              const SizedBox(height: 10),
            ],
          ),
        ),
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kDrawerTextMuted.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: _kDrawerAccent.withOpacity(0.4), width: 1),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              size: 40,
              color: _kDrawerAccent,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'StockPilot v1.0',
            style: TextStyle(
              color: _kDrawerText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userRole.toUpperCase(),
            style: const TextStyle(
              color: _kDrawerTextMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
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
          delay: 350,
          icon: Icons.output_rounded,
          title: l10n.outboundReceipts,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StockOutScreen(userRole: userRole),
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
        _AnimatedMenuItem(
          delay: 475,
          icon: Icons.precision_manufacturing_rounded,
          title: 'Výroba',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProductionListScreen()),
            );
          },
        ),
        _AnimatedMenuItem(
          delay: 478,
          icon: Icons.menu_book_rounded,
          title: 'Receptúry',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecipeListScreen(userRole: userRole),
              ),
            );
          },
        ),
        _AnimatedMenuItem(
          delay: 480,
          icon: Icons.assignment_rounded,
          title: 'Výrobné príkazy',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductionOrderListScreen(userRole: userRole),
              ),
            );
          },
        ),
        _AnimatedMenuItem(
          delay: 485,
          icon: Icons.local_shipping_rounded,
          title: 'Zákazníci / Palety',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CustomersPalletsScreen()),
            );
          },
        ),
        _AnimatedMenuItem(
          delay: 480,
          icon: Icons.assessment_rounded,
          title: 'Reporty',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportsListScreen()),
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
      color: const Color(0xFFEF4444),
      onTap: () async {
        await LogoutService.logout(context);
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
    final iconColor = color ?? _kDrawerAccent;
    final textColor = color ?? _kDrawerText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: _kDrawerAccent.withOpacity(0.2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _kDrawerTextMuted.withOpacity(0.08),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      fontSize: 16,
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
