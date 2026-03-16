import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class WarehouseQuickStats extends StatelessWidget {
  final int totalQty;
  final double totalValue;
  final int lowStockCount;
  final VoidCallback? onLowStockTap;

  const WarehouseQuickStats({
    super.key,
    required this.totalQty,
    required this.totalValue,
    required this.lowStockCount,
    this.onLowStockTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      child: Row(
        children: [
          _StatCard(
            label: "Celkovo",
            value: "$totalQty ks",
            icon: Icons.inventory_2,
            color: AppColors.info,
          ),
          _StatCard(
            label: "Hodnota",
            value: "${totalValue.toStringAsFixed(0)} €",
            icon: Icons.euro,
            color: AppColors.accentGold,
          ),
          _StatCard(
            label: "Nízky stav",
            value: "$lowStockCount položiek",
            icon: Icons.warning_amber_rounded,
            color: AppColors.warning,
            onTap: lowStockCount > 0 ? onLowStockTap : null,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );

    return Container(
      width: 150,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(12),
      decoration: AppColors.cardDecorationSmall(16),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: cardContent,
            )
          : cardContent,
    );
  }
}
