import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:stock_pilot/theme/app_theme.dart';
import 'package:stock_pilot/l10n/app_localizations.dart';
import 'package:stock_pilot/screens/goods_receipt/goods_receipt_screen.dart';
import 'package:stock_pilot/screens/stock_out/stock_out_screen.dart';
import 'package:stock_pilot/widgets/warehouse/warehouse_transfer_modal_widget.dart';
import 'package:stock_pilot/screens/Warehouse/warehouse_movements_list_screen.dart';

/// Obrazovka „Pohyby na sklade“ – výber typu pohybu a odkaz na všetky pohyby.
class WarehouseMovementsScreen extends StatelessWidget {
  final String userRole;

  const WarehouseMovementsScreen({super.key, this.userRole = 'user'});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                l10n.warehouseMovements,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _MovementCard(
                icon: Icons.south_west_rounded,
                title: 'Príjem tovaru',
                subtitle: 'Evidovať príjem tovaru na sklad',
                color: const Color(0xFF6366F1),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GoodsReceiptScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _MovementCard(
                icon: Icons.north_east_rounded,
                title: 'Výdaj tovaru',
                subtitle: 'Evidovať výdaj tovaru zo skladu',
                color: const Color(0xFFDC2626),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StockOutScreen(userRole: userRole),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _MovementCard(
                icon: Icons.swap_horiz_rounded,
                title: 'Presun medzi skladmi',
                subtitle: 'Presun tovaru z jedného skladu do druhého',
                color: const Color(0xFF0D9488),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const WarehouseTransferModal(),
                  );
                },
              ),
              const SizedBox(height: 16),
              _MovementCard(
                icon: Icons.list_alt_rounded,
                title: 'Všetky pohyby na sklade',
                subtitle: 'Zobraziť históriu príjmov, výdajov a presunov',
                color: const Color(0xFF64748B),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WarehouseMovementsListScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MovementCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppColors.cardDecoration,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
