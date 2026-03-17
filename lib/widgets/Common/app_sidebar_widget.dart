import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/user_session.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../screens/warehouse/warehouse_supplies.dart';
import '../../screens/Warehouse/warehouses_page.dart';
import '../../screens/Warehouse/warehouse_movements_screen.dart';
import '../../screens/customers/customers_page.dart';
import '../../screens/Suppliers/suppliers_page.dart';
import '../../screens/production/production_list_screen.dart';
import '../../screens/goods_receipt/goods_receipt_screen.dart';
import '../../screens/stock_out/stock_out_screen.dart';
import '../../screens/price_quote/price_quotes_list_screen.dart';
import '../../screens/Reports/reports_list_screen.dart';
import '../../screens/Settings/settings_page.dart';
import '../../screens/Recipe/recipe_list_screen.dart';
import '../../screens/ProductionOrder/production_order_list_screen.dart';
import '../../screens/pallet/customers_pallets_screen.dart';
import '../../services/logout_service.dart';

class _NavItem {
  final IconData icon;
  final String label;
  final int index;

  const _NavItem({required this.icon, required this.label, required this.index});
}

const _navItems = [
  _NavItem(icon: Icons.dashboard_rounded, label: 'Prehľad', index: 0),
  _NavItem(icon: Icons.inventory_2_rounded, label: 'Produkty', index: 1),
  _NavItem(icon: Icons.warehouse_rounded, label: 'Sklady', index: 10),
  _NavItem(icon: Icons.swap_horiz_rounded, label: 'Pohyby skladu', index: 11),
  _NavItem(icon: Icons.people_rounded, label: 'Zákazníci', index: 2),
  _NavItem(icon: Icons.local_shipping_rounded, label: 'Dodávatelia', index: 3),
  _NavItem(icon: Icons.precision_manufacturing_rounded, label: 'Výroba', index: 4),
  _NavItem(icon: Icons.menu_book_rounded, label: 'Receptúry', index: 12),
  _NavItem(icon: Icons.assignment_rounded, label: 'Výrobné príkazy', index: 13),
  _NavItem(icon: Icons.arrow_downward_rounded, label: 'Príjemky', index: 5),
  _NavItem(icon: Icons.arrow_upward_rounded, label: 'Výdajky', index: 6),
  _NavItem(icon: Icons.request_quote_rounded, label: 'Cenové ponuky', index: 7),
  _NavItem(icon: Icons.local_shipping_outlined, label: 'Zákazníci / Palety', index: 14),
  _NavItem(icon: Icons.bar_chart_rounded, label: 'Štatistiky', index: 8),
  _NavItem(icon: Icons.settings_rounded, label: 'Nastavenia', index: 9),
];

class AppSidebar extends StatefulWidget {
  final User? user;
  final String userRole;
  final int activeIndex;
  final void Function(String role)? onSwitchRole;
  /// Otvorí modal na ručné vytvorenie produktu / produktovej karty.
  final VoidCallback? onAddProduct;

  const AppSidebar({
    super.key,
    this.user,
    required this.userRole,
    this.activeIndex = 0,
    this.onSwitchRole,
    this.onAddProduct,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> with SingleTickerProviderStateMixin {
  bool _isCollapsed = false;
  bool _productsExpanded = false;
  late AnimationController _animController;
  late Animation<double> _widthAnim;
  late Animation<double> _labelOpacityAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _widthAnim = Tween<double>(begin: 260, end: 72).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutQuart),
    );
    // Labely vyblednú rýchlejšie než sa sidebar zúži – vyzerá prirodzenejšie
    _labelOpacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleCollapse() {
    setState(() => _isCollapsed = !_isCollapsed);
    if (_isCollapsed) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  void _navigate(BuildContext context, int index) {
    if (index == widget.activeIndex) return;
    switch (index) {
      case 1:
        Navigator.push(context, _fadeRoute(WarehouseSuppliesScreen(userRole: widget.userRole)));
        break;
      case 2:
        Navigator.push(context, _fadeRoute(const CustomersPage()));
        break;
      case 3:
        Navigator.push(context, _fadeRoute(const SuppliersPage()));
        break;
      case 4:
        Navigator.push(context, _fadeRoute(const ProductionListScreen()));
        break;
      case 5:
        Navigator.push(context, _fadeRoute(const GoodsReceiptScreen()));
        break;
      case 6:
        Navigator.push(context, _fadeRoute(StockOutScreen(userRole: widget.userRole)));
        break;
      case 7:
        Navigator.push(context, _fadeRoute(const PriceQuotesListScreen()));
        break;
      case 8:
        Navigator.push(context, _fadeRoute(const ReportsListScreen()));
        break;
      case 9:
        Navigator.push(context, _fadeRoute(SettingsPage(userRole: widget.userRole)));
        break;
      case 10:
        Navigator.push(context, _fadeRoute(const WarehousesPage()));
        break;
      case 11:
        Navigator.push(context, _fadeRoute(WarehouseMovementsScreen(userRole: widget.userRole)));
        break;
      case 12:
        Navigator.push(context, _fadeRoute(RecipeListScreen(userRole: widget.userRole)));
        break;
      case 13:
        Navigator.push(context, _fadeRoute(ProductionOrderListScreen(userRole: widget.userRole)));
        break;
      case 14:
        Navigator.push(context, _fadeRoute(const CustomersPalletsScreen()));
        break;
    }
  }

  PageRoute _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondary) => page,
      transitionsBuilder: (context, animation, secondary, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 200),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final width = _widthAnim.value;
        final labelOpacity = _labelOpacityAnim.value;
        final isNarrow = labelOpacity < 0.01;
        return ClipRect(
          clipBehavior: Clip.hardEdge,
          child: Container(
            width: width,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              border: Border(
                right: BorderSide(color: AppColors.borderSubtle, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(labelOpacity, isNarrow),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: isNarrow ? 4 : 8,
                    ),
                    children: _navItems.map((item) {
                      if (item.index == 1) {
                        return _SidebarProductsExpandable(
                          isActive: widget.activeIndex == 1,
                          labelOpacity: labelOpacity,
                          isExpanded: _productsExpanded,
                          isNarrow: isNarrow,
                          onToggle: () => setState(() => _productsExpanded = !_productsExpanded),
                          onNavigateToSupplies: () => _navigate(context, 1),
                          onAddProduct: widget.onAddProduct,
                        );
                      }
                      return _SidebarNavItem(
                        item: item,
                        isActive: item.index == widget.activeIndex,
                        labelOpacity: labelOpacity,
                        isNarrow: isNarrow,
                        onTap: () => _navigate(context, item.index),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1),
                _buildUserSection(labelOpacity),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(double labelOpacity, bool isNarrow) {
    final hPadding = isNarrow ? 4.0 : 16.0;
    final rPadding = isNarrow ? 4.0 : 8.0;
    final iconSize = isNarrow ? 32.0 : 36.0;
    final btnSize = isNarrow ? 24.0 : 28.0;
    return SizedBox(
      height: 68,
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPadding, 16, rPadding, 12),
        child: Row(
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: AppColors.accentGoldSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.inventory_2_rounded, color: AppColors.accentGold, size: isNarrow ? 18 : 20),
            ),
            Expanded(
              child: labelOpacity < 0.01
                  ? const SizedBox.shrink()
                  : Opacity(
                      opacity: labelOpacity,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: RichText(
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'STOCK ',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              TextSpan(
                                text: 'PILOT',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentGold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            GestureDetector(
              onTap: _toggleCollapse,
              child: Container(
                width: btnSize,
                height: btnSize,
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _isCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                  size: isNarrow ? 16.0 : 18.0,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserInfoSheet(BuildContext context) {
    final user = widget.user;
    final role = widget.userRole;
    final name = user?.fullName ?? 'Používateľ';
    final initials = user != null
        ? user.fullName.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase()
        : '??';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.accentGoldSubtle,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentGold.withOpacity(0.4), width: 2),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentGold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              if (user?.username != null && user!.username.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  user.username,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: role == 'admin' ? AppColors.dangerSubtle : AppColors.infoSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: role == 'admin' ? AppColors.danger : AppColors.info,
                    width: 1,
                  ),
                ),
                child: Text(
                  role == 'admin' ? 'Administrátor' : 'Používateľ',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: role == 'admin' ? AppColors.danger : AppColors.info,
                  ),
                ),
              ),
              if (role == 'user') ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.supervisor_account_rounded, color: AppColors.accentGold, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nadriadený',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              UserSession.ownerDisplayName != null &&
                                      UserSession.ownerDisplayName!.isNotEmpty
                                  ? UserSession.ownerDisplayName!
                                  : 'Odhláste sa a prihláste sa znova cez internet, aby sa zobrazil nadriadený.',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: UserSession.ownerDisplayName != null &&
                                        UserSession.ownerDisplayName!.isNotEmpty
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (user != null && (user.email.isNotEmpty || user.phone.isNotEmpty || user.department.isNotEmpty)) ...[
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderSubtle),
                if (user.email.isNotEmpty)
                  _UserInfoRow(icon: Icons.email_outlined, label: 'E-mail', value: user.email),
                if (user.phone.isNotEmpty)
                  _UserInfoRow(icon: Icons.phone_outlined, label: 'Telefón', value: user.phone),
                if (user.department.isNotEmpty)
                  _UserInfoRow(icon: Icons.business_center_outlined, label: 'Oddelenie', value: user.department),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserSection(double labelOpacity) {
    final user = widget.user;
    final initials = user != null
        ? user.fullName.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase()
        : '??';
    final name = user?.fullName ?? 'Používateľ';
    final role = widget.userRole;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showUserInfoSheet(context),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentGoldSubtle,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accentGold.withOpacity(0.3), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentGold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: labelOpacity < 0.01
                      ? const SizedBox.shrink()
                      : Opacity(
                          opacity: labelOpacity,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  role.toUpperCase(),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.8,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                if (UserSession.ownerDisplayName != null &&
                                    UserSession.ownerDisplayName!.isNotEmpty &&
                                    role == 'user')
                                  Text(
                                    'Nadriadený: ${UserSession.ownerDisplayName}',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          Opacity(
            opacity: labelOpacity,
            child: IgnorePointer(
              ignoring: labelOpacity < 0.1,
              child: Column(
                children: [
                  if (widget.onSwitchRole != null) ...[
                    const SizedBox(height: 8),
                    _SidebarRoleSwitch(
                      currentRole: widget.userRole,
                      onSwitchRole: widget.onSwitchRole!,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _LogoutButton(userRole: widget.userRole),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarProductsExpandable extends StatelessWidget {
  final bool isActive;
  final double labelOpacity;
  final bool isExpanded;
  final bool isNarrow;
  final VoidCallback onToggle;
  final VoidCallback onNavigateToSupplies;
  final VoidCallback? onAddProduct;

  const _SidebarProductsExpandable({
    required this.isActive,
    required this.labelOpacity,
    required this.isExpanded,
    required this.isNarrow,
    required this.onToggle,
    required this.onNavigateToSupplies,
    this.onAddProduct,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SidebarNavItem(
          item: const _NavItem(icon: Icons.inventory_2_rounded, label: 'Produkty', index: 1),
          isActive: isActive && !isExpanded,
          labelOpacity: labelOpacity,
          isNarrow: isNarrow,
          onTap: onToggle,
          trailing: Opacity(
            opacity: labelOpacity,
            child: Icon(
              isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (isExpanded) ...[
          Padding(
            padding: EdgeInsets.only(left: isNarrow ? 4 : 12),
            child: _SidebarSubItem(
              icon: Icons.list_rounded,
              label: 'Skladové zásoby',
              labelOpacity: labelOpacity,
              onTap: onNavigateToSupplies,
            ),
          ),
          if (onAddProduct != null)
            Padding(
              padding: EdgeInsets.only(left: isNarrow ? 4 : 12, top: 4, bottom: 6),
              child: labelOpacity < 0.5
                  ? SizedBox(
                      width: double.infinity,
                      child: IconButton(
                        onPressed: onAddProduct,
                        icon: const Icon(Icons.add_box_rounded, size: 22),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.accentGold,
                          foregroundColor: AppColors.bgPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onAddProduct,
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
      ],
    );
  }
}

class _SidebarSubItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final double labelOpacity;
  final VoidCallback onTap;

  const _SidebarSubItem({
    required this.icon,
    required this.label,
    required this.labelOpacity,
    required this.onTap,
  });

  @override
  State<_SidebarSubItem> createState() => _SidebarSubItemState();
}

class _SidebarSubItemState extends State<_SidebarSubItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _hovered ? AppColors.bgElevated : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(widget.icon, size: 18, color: AppColors.textSecondary),
                Expanded(
                  child: Opacity(
                    opacity: widget.labelOpacity,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        widget.label,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
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

class _SidebarNavItem extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final double labelOpacity;
  final bool isNarrow;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SidebarNavItem({
    required this.item,
    required this.isActive,
    required this.labelOpacity,
    required this.isNarrow,
    required this.onTap,
    this.trailing,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;

    final horizontalPadding = widget.isNarrow ? 4.0 : 8.0;
    final innerPadding = widget.isNarrow ? 4.0 : 10.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accentGoldSubtle
                  : _hovered
                      ? AppColors.bgElevated
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(
                  color: isActive ? AppColors.accentGold : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: innerPadding, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.item.icon,
                  size: 20,
                  color: isActive ? AppColors.accentGold : AppColors.textSecondary,
                ),
                Expanded(
                  child: widget.isNarrow || widget.labelOpacity < 0.01
                      ? const SizedBox.shrink()
                      : Opacity(
                          opacity: widget.labelOpacity,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              widget.item.label,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                color: isActive ? AppColors.accentGold : AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                ),
                if (widget.trailing != null && widget.labelOpacity > 0.01)
                  widget.trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _UserInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarRoleSwitch extends StatelessWidget {
  final String currentRole;
  final void Function(String role) onSwitchRole;

  const _SidebarRoleSwitch({
    required this.currentRole,
    required this.onSwitchRole,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = currentRole == 'admin';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Rola',
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _SidebarRoleChip(
                label: isAdmin ? 'Admin' : 'Používateľ',
                isSelected: true,
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SidebarRoleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarRoleChip({
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
        padding: const EdgeInsets.symmetric(vertical: 6),
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
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppColors.accentGold : AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final String userRole;
  const _LogoutButton({required this.userRole});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => LogoutService.logout(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.dangerSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, size: 16, color: AppColors.danger),
            const SizedBox(width: 8),
            Text(
              'Odhlásiť',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mobile bottom navigation bar
class AppBottomNavBar extends StatelessWidget {
  final int activeIndex;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final String userRole;

  const AppBottomNavBar({
    super.key,
    required this.activeIndex,
    required this.scaffoldKey,
    this.userRole = 'user',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _BottomNavItem(
                icon: Icons.dashboard_rounded,
                label: 'Prehľad',
                isActive: activeIndex == 0,
                onTap: () {},
              ),
              _BottomNavItem(
                icon: Icons.inventory_2_rounded,
                label: 'Produkty',
                isActive: activeIndex == 1,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WarehouseSuppliesScreen(userRole: userRole)),
                  );
                },
              ),
              _BottomNavItem(
                icon: Icons.arrow_downward_rounded,
                label: 'Príjemky',
                isActive: activeIndex == 4,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GoodsReceiptScreen()),
                  );
                },
              ),
              _BottomNavItem(
                icon: Icons.arrow_upward_rounded,
                label: 'Výdajky',
                isActive: activeIndex == 5,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StockOutScreen(userRole: userRole)),
                  );
                },
              ),
              _BottomNavItem(
                icon: Icons.menu_rounded,
                label: 'Menu',
                isActive: false,
                onTap: () => scaffoldKey.currentState?.openDrawer(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? AppColors.accentGold : AppColors.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.accentGold : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
