import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../purchase/purchase_price_history_sheet_widget.dart';

/// Kartové zobrazenie skladových zásob – mriežka kariet s PLU, názvom, cenou a množstvom.
class WarehouseSuppliesCardView extends StatelessWidget {
  final List<Product> products;
  final ScrollController? scrollController;
  final ValueChanged<Product>? onEditProduct;
  final ValueChanged<Product>? onDeleteProduct;

  const WarehouseSuppliesCardView({
    super.key,
    required this.products,
    this.scrollController,
    this.onEditProduct,
    this.onDeleteProduct,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 56,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Žiadne produkty',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Skúste zmeniť vyhľadávanie alebo pridať produkt',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth > 900
            ? 3
            : (constraints.maxWidth > 600 ? 2 : 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.32,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _ProductCard(
                    product: product,
                    onEditTap: onEditProduct != null
                        ? () => onEditProduct!(product)
                        : null,
                    onDeleteTap: onDeleteProduct != null
                        ? () => onDeleteProduct!(product)
                        : null,
                    onHistoryTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (context) =>
                            PurchasePriceHistorySheet(product: product),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onEditTap;
  final VoidCallback? onDeleteTap;
  final VoidCallback onHistoryTap;

  const _ProductCard({
    required this.product,
    this.onEditTap,
    this.onDeleteTap,
    required this.onHistoryTap,
  });

  bool get _lowStock =>
      product.minQuantity > 0 && product.qty < product.minQuantity;

  static const _cardRadius = 16.0;

  Widget _buildStatusBadges() {
    final badges = <Widget>[];
    if (!product.isActive) {
      badges.add(
        const _StatusBadge(
          icon: Icons.block_rounded,
          label: 'Neaktívna',
          color: AppColors.danger,
        ),
      );
    }
    if (product.temporarilyUnavailable) {
      badges.add(
        const _StatusBadge(
          icon: Icons.pause_circle_outline_rounded,
          label: 'Nedostupná',
          color: AppColors.textSecondary,
        ),
      );
    }
    if (product.hasExtendedPricing) {
      badges.add(
        const _StatusBadge(
          icon: Icons.auto_awesome_rounded,
          label: 'Cenotvorba',
          color: AppColors.accentPurple,
        ),
      );
    }
    if (badges.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 4, runSpacing: 4, children: badges),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: !product.isActive ? 0.55 : 1.0,
      child: Material(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(_cardRadius),
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(
              color: AppColors.borderSubtle,
              width: 1,
            ),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Horná časť: PLU badge, názov, ikona histórie
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // PLU ako kompaktný badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentGoldSubtle,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              product.plu,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.3,
                                color: AppColors.accentGold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            product.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              height: 1.3,
                              color: !product.isActive
                                  ? AppColors.textMuted
                                  : product.temporarilyUnavailable
                                  ? AppColors.textSecondary
                                  : product.hasExtendedPricing
                                  ? AppColors.accentPurple
                                  : AppColors.textPrimary,
                              decoration: !product.isActive
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: AppColors.textMuted,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          _buildStatusBadges(),
                        ],
                      ),
                    ),
                    if (onEditTap != null)
                      Tooltip(
                        message: 'Upraviť produkt',
                        child: Material(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: onEditTap,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 22,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (onEditTap != null) const SizedBox(width: 6),
                    if (onDeleteTap != null)
                      Tooltip(
                        message: 'Vymazať produkt',
                        child: Material(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: onDeleteTap,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Icons.delete_outline,
                                size: 22,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (onDeleteTap != null) const SizedBox(width: 6),
                    Tooltip(
                      message: 'História nákupných cien',
                      child: Material(
                        color: AppColors.bgInput,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: onHistoryTap,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.history_edu_rounded,
                              size: 22,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Oddeľovač nad cenou
                Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),
                const SizedBox(height: 12),
                // Cena a množstvo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${product.price.toStringAsFixed(2)} €',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              letterSpacing: -0.3,
                              color: AppColors.accentGold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bez DPH ${product.withoutVat.toStringAsFixed(2)} € · DPH ${product.vat}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.2,
                            ),
                          ),
                          if (product.lastPurchasePriceWithoutVat > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Posl. nákup bez DPH: ${product.lastPurchasePriceWithoutVat.toStringAsFixed(2)} €',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.2,
                              ),
                            ),
                          ],
                          if (product.marginPercent != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${AppLocalizations.of(context)!.margin}: ${product.marginPercent!.toStringAsFixed(1)} %',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.2,
                              ),
                            ),
                          ],
                          if (product.supplierName != null &&
                              product.supplierName!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Dodávateľ: ${product.supplierName}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.2,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _lowStock
                            ? AppColors.dangerSubtle
                            : AppColors.successSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _lowStock
                              ? AppColors.danger
                              : AppColors.success,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${product.qty} ${product.unit}',
                        style: TextStyle(
                          color: _lowStock
                              ? AppColors.danger
                              : AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
