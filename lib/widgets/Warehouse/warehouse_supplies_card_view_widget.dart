import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/product.dart';
import '../purchase/purchase_price_history_sheet_widget.dart';

/// Kartové zobrazenie skladových zásob – mriežka kariet s PLU, názvom, cenou a množstvom.
class WarehouseSuppliesCardView extends StatelessWidget {
  final List<Product> products;
  final bool isAdmin;
  final List<String> selectedIds;
  final ValueChanged<String?>? onSelectionChanged;
  final ValueChanged<Product>? onEditProduct;
  final ValueChanged<Product>? onDeleteProduct;

  const WarehouseSuppliesCardView({
    super.key,
    required this.products,
    required this.isAdmin,
    required this.selectedIds,
    this.onSelectionChanged,
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
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 56,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Žiadne produkty',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Skúste zmeniť vyhľadávanie alebo pridať produkt',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
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
            : (constraints.maxWidth > 600
                ? 2
                : 1);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
              isAdmin: isAdmin,
              isSelected: product.uniqueId != null &&
                  selectedIds.contains(product.uniqueId!),
              onSelectionChanged: onSelectionChanged != null && product.uniqueId != null
                  ? () => onSelectionChanged!(product.uniqueId)
                  : null,
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
                  builder: (context) => PurchasePriceHistorySheet(
                    product: product,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool isAdmin;
  final bool isSelected;
  final VoidCallback? onSelectionChanged;
  final VoidCallback? onEditTap;
  final VoidCallback? onDeleteTap;
  final VoidCallback onHistoryTap;

  const _ProductCard({
    required this.product,
    required this.isAdmin,
    required this.isSelected,
    this.onSelectionChanged,
    this.onEditTap,
    this.onDeleteTap,
    required this.onHistoryTap,
  });

  bool get _lowStock => product.qty < 10;

  static const _cardRadius = 20.0;
  static const _accentColor = Color(0xFF6366F1);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_cardRadius),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: isAdmin && onSelectionChanged != null
            ? () => onSelectionChanged!()
            : null,
        borderRadius: BorderRadius.circular(_cardRadius),
        splashColor: _accentColor.withValues(alpha: 0.12),
        highlightColor: _accentColor.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(
              color: isSelected ? _accentColor : Colors.grey.shade200,
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _accentColor.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Horná časť: PLU badge, názov, ikona histórie
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAdmin && onSelectionChanged != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => onSelectionChanged!(),
                        activeColor: _accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
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
                            color: _accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            product.plu,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.3,
                              color: _accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            height: 1.3,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (onEditTap != null)
                    Tooltip(
                      message: 'Upraviť produkt',
                      child: Material(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: onEditTap,
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 22,
                              color: Color(0xFF64748B),
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
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: onDeleteTap,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.delete_outline,
                              size: 22,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (onDeleteTap != null) const SizedBox(width: 6),
                  Tooltip(
                    message: 'História nákupných cien',
                    child: Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: onHistoryTap,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.history_edu_rounded,
                            size: 22,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Oddeľovač nad cenou
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey.shade200,
              ),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: -0.3,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bez DPH ${product.withoutVat.toStringAsFixed(2)} € · DPH ${product.vat}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            height: 1.2,
                          ),
                        ),
                        if (product.lastPurchasePriceWithoutVat > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Posl. nákup bez DPH: ${product.lastPurchasePriceWithoutVat.toStringAsFixed(2)} €',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
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
                              color: Colors.grey[600],
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
                              color: Colors.grey[600],
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
                      color: _lowStock ? Colors.red[50]! : Colors.green[50]!,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _lowStock
                            ? Colors.red.shade200
                            : Colors.green.shade200,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${product.qty} ${product.unit}',
                      style: TextStyle(
                        color: _lowStock ? Colors.red[800] : Colors.green[800],
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
