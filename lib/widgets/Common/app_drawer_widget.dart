import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stock_pilot/screens/scanner/scan_product.dart';
import 'package:stock_pilot/screens/warehouse/warehouse_supplies.dart';
import 'package:stock_pilot/screens/warehouse/warehouses_page.dart';
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
import 'package:stock_pilot/screens/goods_receipt/goods_receipt_screen.dart';
import 'package:stock_pilot/l10n/app_localizations.dart';
import 'package:stock_pilot/services/logout_service.dart';
import '../../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  final String userRole;
  final void Function(String role)? onSwitchRole;
  /// Otvorí modal na ručné vytvorenie produktu / produktovej karty.
  final VoidCallback? onAddProduct;

  const AppDrawer({
    super.key,
    required this.userRole,
    this.onSwitchRole,
    this.onAddProduct,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Drawer(
      backgroundColor: AppColors.bgCard,
      elevation: 0,
      width: 280,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(),
            if (onSwitchRole != null) ...[
              _RoleSwitchRow(
                currentRole: userRole,
                onSwitchRole: onSwitchRole!,
              ),
              const SizedBox(height: 4),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerMenuItem(
                    icon: Icons.dashboard_rounded,
                    title: l10n.overview,
                    isActive: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _DrawerMenuItem(
                    icon: Icons.qr_code_scanner_rounded,
                    title: l10n.scanProduct,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanProductScreen()));
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.warehouse_rounded,
                    title: l10n.warehouses,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehousesPage()));
                    },
                  ),
                  _ProductsDrawerSection(
                    userRole: userRole,
                    onAddProduct: onAddProduct,
                    l10nWarehouseSupplies: l10n.warehouseSupplies,
                  ),
                  _DrawerMenuItem(
                    icon: Icons.swap_horiz_rounded,
                    title: l10n.warehouseMovements,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => WarehouseMovementsScreen(userRole: userRole)));
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.arrow_downward_rounded,
                    title: 'Príjemky',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const GoodsReceiptScreen()));
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.arrow_upward_rounded,
                    title: l10n.outboundReceipts,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => StockOutScreen(userRole: userRole)));
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.business_center_rounded,
                    title: l10n.suppliers,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersPage()));
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.people_rounded,
                    title: l10n.customers,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersPage()));
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.precision_manufacturing_rounded,
                    title: 'Výroba',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionListScreen()));
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.menu_book_rounded,
                    title: 'Receptúry',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeListScreen(userRole: userRole)));
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.assignment_rounded,
                    title: 'Výrobné príkazy',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProductionOrderListScreen(userRole: userRole)));
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.local_shipping_rounded,
                    title: 'Zákazníci / Palety',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersPalletsScreen()));
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.bar_chart_rounded,
                    title: 'Reporty',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsListScreen()));
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(color: AppColors.borderSubtle),
                  ),
                  _DrawerMenuItem(
                    icon: Icons.settings_rounded,
                    title: l10n.settings,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(userRole: userRole)));
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSubtle),
            _LogoutItem(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _RoleSwitchRow extends StatelessWidget {
  final String currentRole;
  final void Function(String role) onSwitchRole;

  const _RoleSwitchRow({
    required this.currentRole,
    required this.onSwitchRole,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = currentRole == 'admin';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Rola',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _RoleChip(
                  label: isAdmin ? 'Admin' : 'Používateľ',
                  isSelected: true,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentGoldSubtle : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accentGold : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppColors.accentGold : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentGoldSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: AppColors.accentGold, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            'STOCK PILOT',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 22),
          ),
        ],
      ),
    );
  }
}

class _ProductsDrawerSection extends StatelessWidget {
  final String userRole;
  final VoidCallback? onAddProduct;
  final String l10nWarehouseSupplies;

  const _ProductsDrawerSection({
    required this.userRole,
    required this.l10nWarehouseSupplies,
    this.onAddProduct,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ExpansionTile(
        leading: Icon(Icons.inventory_2_rounded, size: 20, color: AppColors.textSecondary),
        title: Text(
          'Produkty',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textSecondary,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _DrawerMenuItem(
              icon: Icons.list_rounded,
              title: l10nWarehouseSupplies,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => WarehouseSuppliesScreen(userRole: userRole)));
              },
            ),
          ),
          if (onAddProduct != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4, bottom: 6),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onAddProduct!();
                  },
                  icon: const Icon(Icons.add_box_rounded, size: 18),
                  label: const Text('Nový produkt'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: AppColors.bgPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrawerMenuItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isActive;

  const _DrawerMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<_DrawerMenuItem> createState() => _DrawerMenuItemState();
}

class _DrawerMenuItemState extends State<_DrawerMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final iconColor = isActive ? AppColors.accentGold : AppColors.textSecondary;
    final textColor = isActive ? AppColors.accentGold : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accentGoldSubtle
                  : _hovered
                      ? AppColors.bgElevated
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: AppColors.accentGold.withOpacity(0.2), width: 1)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(widget.icon, size: 20, color: iconColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: textColor,
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

class _LogoutItem extends StatelessWidget {
  const _LogoutItem();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: GestureDetector(
        onTap: () => LogoutService.logout(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.dangerSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.danger.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 20, color: AppColors.danger),
              const SizedBox(width: 14),
              Text(
                'Odhlásiť sa',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
