import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:stock_pilot/widgets/warehouse/warehouse_list_widget.dart';
import 'package:stock_pilot/widgets/warehouse/add_warehouse_modal_widget.dart';
import 'package:stock_pilot/l10n/app_localizations.dart';
import 'package:stock_pilot/models/warehouse.dart';
import 'package:stock_pilot/services/Warehouse/warehouse_service.dart';
import 'package:stock_pilot/services/Warehouse/warehouse_report_service.dart';

class WarehousesPage extends StatefulWidget {
  const WarehousesPage({super.key});

  @override
  State<WarehousesPage> createState() => _WarehousesPageState();
}

class _WarehousesPageState extends State<WarehousesPage> {
  final GlobalKey<State<WarehouseListWidget>> _warehouseListKey =
      GlobalKey<State<WarehouseListWidget>>();
  final WarehouseService _warehouseService = WarehouseService();
  final WarehouseReportService _reportService = WarehouseReportService();

  void _addWarehouse() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AddWarehouseModal(),
    ).then((result) {
      // Obnoviť zoznam po pridaní alebo úprave skladu
      if (result != null) {
        final state = _warehouseListKey.currentState;
        if (state != null) {
          // Volanie refreshWarehouses cez dynamic
          (state as dynamic).refreshWarehouses();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.white.withOpacity(0.7),
              elevation: 0,
              centerTitle: false,
              title: Text(
                l10n.warehouses,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.upload_file_rounded, color: Colors.black87),
                  tooltip: l10n.exportReport,
                  onPressed: () => _showExportReportDialog(context),
                ),
                IconButton(
                  icon: const Icon(Icons.tune, color: Colors.black87),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: WarehouseListWidget(key: _warehouseListKey),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWarehouse,
        backgroundColor: Colors.black,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        label: Text(
          l10n.add,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _showExportReportDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ExportReportDialog(
        l10n: l10n,
        warehouseService: _warehouseService,
        reportService: _reportService,
      ),
    );
  }
}

/// Dialóg na výber formátu (PDF/Excel) a skladu, vygenerovanie a zdieľanie reportu.
class _ExportReportDialog extends StatefulWidget {
  final AppLocalizations l10n;
  final WarehouseService warehouseService;
  final WarehouseReportService reportService;

  const _ExportReportDialog({
    required this.l10n,
    required this.warehouseService,
    required this.reportService,
  });

  @override
  State<_ExportReportDialog> createState() => _ExportReportDialogState();
}

class _ExportReportDialogState extends State<_ExportReportDialog> {
  List<Warehouse> _warehouses = [];
  Warehouse? _selectedWarehouse;
  bool _isPdf = true;
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    final list = await widget.warehouseService.getAllWarehouses();
    if (mounted) {
      setState(() {
        _warehouses = list;
        _selectedWarehouse = list.isNotEmpty ? list.first : null;
        _loading = false;
      });
    }
  }

  Future<void> _generateAndShare() async {
    final warehouse = _selectedWarehouse;
    if (warehouse == null) return;
    setState(() => _generating = true);
    try {
      final products = await widget.reportService.getProductsForWarehouse(warehouse);
      final safeName = warehouse.name.replaceAll(RegExp(r'[^\w\-.]'), '_');
      final date = DateTime.now();
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (_isPdf) {
        final bytes = await widget.reportService.buildPdf(
          warehouse: warehouse,
          products: products,
          productColumnLabel: widget.l10n.reportProduct,
          quantityColumnLabel: widget.l10n.reportQuantity,
        );
        await widget.reportService.sharePdf(
          bytes: bytes,
          filename: 'report_${safeName}_$dateStr.pdf',
        );
      } else {
        final bytes = await widget.reportService.buildExcel(
          warehouse: warehouse,
          products: products,
          productColumnLabel: widget.l10n.reportProduct,
          quantityColumnLabel: widget.l10n.reportQuantity,
        );
        await widget.reportService.shareExcel(
          bytes: bytes,
          filename: 'report_${safeName}_$dateStr.xlsx',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.l10n.reportGenerated),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.l10n.reportError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.exportReport),
      content: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.exportFormat,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _FormatChip(
                          label: l10n.formatPdf,
                          selected: _isPdf,
                          onTap: () => setState(() => _isPdf = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FormatChip(
                          label: l10n.formatExcel,
                          selected: !_isPdf,
                          onTap: () => setState(() => _isPdf = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.chooseWarehouse,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Warehouse>(
                    value: _selectedWarehouse,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _warehouses
                        .map((w) => DropdownMenuItem<Warehouse>(
                              value: w,
                              child: Text('${w.name} (${w.code})'),
                            ))
                        .toList(),
                    onChanged: (w) => setState(() => _selectedWarehouse = w),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _generating ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: (_loading || _generating || _selectedWarehouse == null)
              ? null
              : _generateAndShare,
          child: _generating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.exportReport),
        ),
      ],
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FormatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF6366F1) : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
