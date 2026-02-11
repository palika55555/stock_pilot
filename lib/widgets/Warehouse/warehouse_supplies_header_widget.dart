import 'package:flutter/material.dart';

class WarehouseSuppliesHeader extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onFilterTap;
  final VoidCallback? onColumnsTap;
  final String? selectedWarehouseName;

  const WarehouseSuppliesHeader({
    super.key,
    required this.isAdmin,
    required this.onFilterTap,
    this.onColumnsTap,
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
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Skladové zásoby',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (onColumnsTap != null)
            IconButton(
              icon: const Icon(
                Icons.view_column_rounded,
                color: Colors.white,
                size: 24,
              ),
              onPressed: onColumnsTap,
              tooltip: 'Zobrazenie stĺpcov',
            ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                if (hasFilter)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
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
