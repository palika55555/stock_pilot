import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../screens/warehouse/warehouse_supplies.dart';
import '../../screens/customers/customers_page.dart';
import '../../screens/Suppliers/suppliers_page.dart';
import '../../screens/production/production_list_screen.dart';
import '../../screens/goods_receipt/goods_receipt_screen.dart';
import '../../screens/stock_out/stock_out_screen.dart';
import '../../screens/price_quote/price_quotes_list_screen.dart';
import '../../screens/Reports/reports_list_screen.dart';
import '../../screens/Settings/settings_page.dart';
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
  _NavItem(icon: Icons.people_rounded, label: 'Zákazníci', index: 2),
  _NavItem(icon: Icons.local_shipping_rounded, label: 'Dodávatelia', index: 3),
  _NavItem(icon: Icons.precision_manufacturing_rounded, label: 'Výroba', index: 4),
  _NavItem(icon: Icons.arrow_downward_rounded, label: 'Príjemky', index: 5),
  _NavItem(icon: Icons.arrow_upward_rounded, label: 'Výdajky', index: 6),
  _NavItem(icon: Icons.request_quote_rounded, label: 'Cenové ponuky', index: 7),
  _NavItem(icon: Icons.bar_chart_rounded, label: 'Štatistiky', index: 8),
  _NavItem(icon: Icons.settings_rounded, label: 'Nastavenia', index: 9),
];

class AppSidebar extends StatefulWidget {
  final User? user;
  final String userRole;
  final int activeIndex;
  final void Function(String role)? onSwitchRole;

  const AppSidebar({
    super.key,
    this.user,
    required this.userRole,
    this.activeIndex = 0,
    this.onSwitchRole,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> with SingleTickerProviderStateMixin {
  bool _isCollapsed = false;
  late AnimationController _animController;
  late Animation<double> _widthAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _widthAnim = Tween<double>(begin: 260, end: 72).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
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
      animation: _widthAnim,
      builder: (context, _) {
        final width = _widthAnim.value;
        final showLabels = width > 140;
        return Container(
          width: width,
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            border: Border(
              right: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(showLabels),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: _navItems.map((item) {
                    return _SidebarNavItem(
                      item: item,
                      isActive: item.index == widget.activeIndex,
                      showLabel: showLabels,
                      onTap: () => _navigate(context, item.index),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
              _buildUserSection(showLabels),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool showLabels) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentGoldSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: AppColors.accentGold, size: 20),
          ),
          if (showLabels) ...[
            const SizedBox(width: 10),
            Flexible(
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
          ] else ...[
            const SizedBox(width: 4),
            Text(
              'SP',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.accentGold,
                letterSpacing: 0.5,
              ),
            ),
          ],
          const Spacer(),
          GestureDetector(
            onTap: _toggleCollapse,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSection(bool showLabels) {
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
          Row(
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
              if (showLabels) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (showLabels) ...[
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
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final bool showLabel;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.item,
    required this.isActive,
    required this.showLabel,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final showLabel = widget.showLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              border: Border(
                left: BorderSide(
                  color: isActive ? AppColors.accentGold : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: showLabel ? 12 : 14,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  widget.item.icon,
                  size: 20,
                  color: isActive ? AppColors.accentGold : AppColors.textSecondary,
                ),
                if (showLabel) ...[
                  const SizedBox(width: 12),
                  Expanded(
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
                ],
              ],
            ),
          ),
        ),
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
          'Pracovať ako',
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
                label: 'Používateľ',
                isSelected: !isAdmin,
                onTap: () => onSwitchRole('user'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _SidebarRoleChip(
                label: 'Admin',
                isSelected: isAdmin,
                onTap: () => onSwitchRole('admin'),
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

  const AppBottomNavBar({
    super.key,
    required this.activeIndex,
    required this.scaffoldKey,
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
                    MaterialPageRoute(builder: (_) => const GoodsReceiptScreen()),
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
                onTap: () {},
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
