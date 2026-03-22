import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/product.dart';
import '../../models/warehouse.dart';
import '../../theme/app_theme.dart';
import '../purchase/purchase_price_history_sheet_widget.dart';
import 'warehouse_supplies_constants.dart';

typedef WarehouseSuppliesSortFn = void Function({
  required String sortKey,
  required int columnIndex,
  required bool ascending,
});

/// Stĺpce a bunky [DataTable] pre skladové zásoby.
class WarehouseSuppliesTableData {
  WarehouseSuppliesTableData._();

  static TextStyle get defaultRowStyle =>
      TextStyle(color: AppColors.textPrimary);

  /// Vizuálne stavy skladovej karty (OBERON).
  static TextStyle? rowStyleForProduct(Product product) {
    if (!product.isActive) {
      return TextStyle(
        decoration: TextDecoration.lineThrough,
        color: AppColors.textMuted,
      );
    }
    if (product.temporarilyUnavailable) {
      return TextStyle(color: AppColors.textMuted);
    }
    if (product.hasExtendedPricing) {
      return TextStyle(color: AppColors.accentPurple);
    }
    return null;
  }

  static bool isNumericColumn(String id) {
    const numericIds = {
      'predaj_bez_dph',
      'predaj_s_dph',
      'marza',
      'dph',
      'dph_eur',
      'mnozstvo',
      'zlava',
      'nakup_bez_dph',
      'nakup_s_dph',
      'nakup_dph',
      'recykl',
      'posl_nakup_bez_dph',
    };
    return numericIds.contains(id);
  }

  static List<DataColumn> buildColumns(
    BuildContext context, {
    required bool isAdmin,
    required Map<String, bool> columnVisibility,
    required WarehouseSuppliesSortFn onSort,
  }) {
    final cols = <DataColumn>[
      const DataColumn(
        label: Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      DataColumn(
        label: const Text('PLU'),
        onSort: (i, a) => onSort(sortKey: 'plu', columnIndex: i, ascending: a),
      ),
      DataColumn(
        label: const Text('Názov tovaru'),
        onSort: (i, a) => onSort(sortKey: 'name', columnIndex: i, ascending: a),
      ),
    ];
    for (final c in warehouseSupplyTableColumns) {
      if (columnVisibility[c.id] != true) continue;
      switch (c.id) {
        case 'predaj_s_dph':
          cols.add(
            DataColumn(
              label: const Text('Predaj s DPH'),
              numeric: true,
              onSort: (i, a) =>
                  onSort(sortKey: 'price', columnIndex: i, ascending: a),
            ),
          );
          break;
        case 'marza':
          cols.add(
            DataColumn(
              label: Text(AppLocalizations.of(context)!.margin),
              numeric: true,
              onSort: (i, a) =>
                  onSort(sortKey: 'margin', columnIndex: i, ascending: a),
            ),
          );
          break;
        case 'mnozstvo':
          cols.add(
            DataColumn(
              label: const Text('Množstvo'),
              numeric: true,
              onSort: (i, a) =>
                  onSort(sortKey: 'qty', columnIndex: i, ascending: a),
            ),
          );
          break;
        case 'posl_nakup_bez_dph':
          cols.add(
            DataColumn(
              label: const Text('Posledný nákup bez DPH'),
              numeric: true,
              onSort: (i, a) => onSort(
                sortKey: 'last_purchase_price_without_vat',
                columnIndex: i,
                ascending: a,
              ),
            ),
          );
          break;
        case 'dodavatel':
          cols.add(
            DataColumn(
              label: const Text('Dodávateľ'),
              onSort: (i, a) =>
                  onSort(sortKey: 'supplier_name', columnIndex: i, ascending: a),
            ),
          );
          break;
        case 'sklad':
          cols.add(
            DataColumn(
              label: const Text('Sklad'),
              onSort: (i, a) =>
                  onSort(sortKey: 'warehouse_id', columnIndex: i, ascending: a),
            ),
          );
          break;
        default:
          cols.add(
            DataColumn(
              label: Text(c.label),
              numeric: isNumericColumn(c.id),
            ),
          );
      }
    }
    cols.add(const DataColumn(label: Text('História cien')));
    return cols;
  }

  static List<DataCell> buildRowCells(
    BuildContext context, {
    required Product product,
    required int index,
    required bool lowStock,
    required bool isAdmin,
    required Map<String, bool> columnVisibility,
    required List<Warehouse> warehouses,
    required void Function(Product product) onEdit,
    required void Function(Product product) onDelete,
  }) {
    final rowStyle = rowStyleForProduct(product);
    final baseStyle = rowStyle ?? defaultRowStyle;
    final cells = <DataCell>[
      DataCell(Text('${index + 1}.', style: baseStyle)),
      DataCell(
        Text(
          product.plu,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      DataCell(Text(product.name, style: baseStyle)),
    ];
    for (final c in warehouseSupplyTableColumns) {
      if (columnVisibility[c.id] != true) continue;
      cells.add(_cellForColumn(
        c.id,
        product,
        lowStock,
        rowStyle,
        warehouses,
      ));
    }
    cells.add(
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 22,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Upraviť produkt',
              onPressed: () => onEdit(product),
            ),
            IconButton(
              icon: Icon(
                Icons.history_edu_outlined,
                size: 22,
                color: AppColors.textSecondary,
              ),
              tooltip: 'História nákupných cien',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) =>
                      PurchasePriceHistorySheet(product: product),
                );
              },
            ),
            if (isAdmin)
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 22,
                  color: AppColors.danger,
                ),
                tooltip: 'Vymazať produkt',
                onPressed: () => onDelete(product),
              ),
          ],
        ),
      ),
    );
    return cells;
  }

  static DataCell _cellForColumn(
    String id,
    Product product,
    bool lowStock,
    TextStyle? rowStyle,
    List<Warehouse> warehouses,
  ) {
    TextStyle merge(TextStyle base) =>
        (rowStyle ?? defaultRowStyle).merge(base);
    switch (id) {
      case 'predaj_bez_dph':
        return DataCell(
          Text(
            '${product.withoutVat.toStringAsFixed(2)} €',
            style: merge(const TextStyle()),
          ),
        );
      case 'predaj_s_dph':
        return DataCell(
          Text(
            '${product.price.toStringAsFixed(2)} €',
            style: merge(const TextStyle()),
          ),
        );
      case 'marza':
        final m = product.marginPercent;
        return DataCell(
          Text(
            m != null ? '${m.toStringAsFixed(1)} %' : '–',
            style: merge(const TextStyle()),
          ),
        );
      case 'dph':
        return DataCell(
          Text('${product.vat} %', style: merge(const TextStyle())),
        );
      case 'dph_eur':
        return DataCell(
          Text(
            '${(product.price - product.withoutVat).toStringAsFixed(2)} €',
            style: merge(const TextStyle()),
          ),
        );
      case 'mnozstvo':
        return DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: lowStock
                  ? AppColors.dangerSubtle
                  : AppColors.successSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${product.qty} ${product.unit}',
              style: merge(
                TextStyle(
                  color: lowStock ? AppColors.danger : AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      case 'zlava':
        return DataCell(
          Text('${product.discount} %', style: merge(const TextStyle())),
        );
      case 'nakup_bez_dph':
        return DataCell(
          Text(
            '${product.purchasePriceWithoutVat.toStringAsFixed(2)} €',
            style: merge(const TextStyle()),
          ),
        );
      case 'nakup_s_dph':
        return DataCell(
          Text(
            '${product.purchasePrice.toStringAsFixed(2)} €',
            style: merge(const TextStyle()),
          ),
        );
      case 'nakup_dph':
        return DataCell(
          Text('${product.purchaseVat} %', style: merge(const TextStyle())),
        );
      case 'recykl':
        return DataCell(
          Text(
            '${product.recyclingFee.toStringAsFixed(2)} €',
            style: merge(const TextStyle()),
          ),
        );
      case 'posl_datum':
        return DataCell(
          Text(product.lastPurchaseDate, style: merge(const TextStyle())),
        );
      case 'posl_nakup_bez_dph':
        return DataCell(
          Text(
            '${product.lastPurchasePriceWithoutVat.toStringAsFixed(2)} €',
            style: merge(const TextStyle()),
          ),
        );
      case 'dodavatel':
        return DataCell(
          Text(product.supplierName ?? '–', style: merge(const TextStyle())),
        );
      case 'mena':
        return DataCell(
          Text(product.currency, style: merge(const TextStyle())),
        );
      case 'typ':
        return DataCell(
          Text(product.productType, style: merge(const TextStyle())),
        );
      case 'lokacia':
        return DataCell(
          Text(
            product.location.isEmpty ? '–' : product.location,
            style: merge(const TextStyle()),
          ),
        );
      case 'sklad':
        {
          Warehouse? wh;
          if (product.warehouseId != null) {
            try {
              wh = warehouses.firstWhere((w) => w.id == product.warehouseId);
            } catch (_) {
              wh = null;
            }
          }
          final skladName = wh?.name ?? '–';
          return DataCell(Text(skladName, style: merge(const TextStyle())));
        }
      default:
        return const DataCell(Text(''));
    }
  }

  /// Extrahuje widget z [_cellForColumn] – určené pre vlastný virtualizovaný riadok.
  static Widget buildCellWidget(
    String id,
    Product product,
    bool lowStock,
    TextStyle? rowStyle,
    List<Warehouse> warehouses,
  ) =>
      _cellForColumn(id, product, lowStock, rowStyle, warehouses).child;
}
