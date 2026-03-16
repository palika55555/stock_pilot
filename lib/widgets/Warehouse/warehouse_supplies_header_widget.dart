import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class WarehouseSuppliesHeader extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onFilterTap;
  final VoidCallback? onColumnsTap;
  final VoidCallback? onAddRecipeTap;
  final String? selectedWarehouseName;

  const WarehouseSuppliesHeader({
    super.key,
    required this.isAdmin,
    required this.onFilterTap,
    this.onColumnsTap,
    this.onAddRecipeTap,
    this.selectedWarehouseName,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilter = selectedWarehouseName != null && selectedWarehouseName!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: AppColors.textPrimary,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Skladové zásoby',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (onColumnsTap != null)
            IconButton(
              icon: Icon(
                Icons.view_column_rounded,
                color: AppColors.textPrimary,
                size: 24,
              ),
              onPressed: onColumnsTap,
              tooltip: 'Zobrazenie stĺpcov',
            ),
          if (onAddRecipeTap != null)
            IconButton(
              icon: Icon(
                Icons.restaurant_menu_rounded,
                color: AppColors.textPrimary,
                size: 24,
              ),
              onPressed: onAddRecipeTap,
              tooltip: 'Vytvoriť receptúru',
            ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
                if (hasFilter)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.accentGold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: onFilterTap,
            tooltip: 'Filtrovať podľa skladu',
          ),
        ],
      ),
    );
  }
}
