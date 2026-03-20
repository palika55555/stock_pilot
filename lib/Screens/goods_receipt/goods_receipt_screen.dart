import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../models/product.dart';
import '../../models/receipt.dart';
import '../../models/receipt_pdf_style_config.dart';
import '../../services/Database/database_service.dart';
import '../../services/Receipt/receipt_service.dart';
import '../../services/Receipt/prijemka_pdf_generator.dart';
import '../../models/supplier.dart';
import '../../models/warehouse.dart';
import '../../services/Receipt/bulk_receipt_import_service.dart';
import '../../services/Supplier/supplier_service.dart';
import '../../services/Warehouse/warehouse_service.dart';
import '../../widgets/receipts/goods_receipt_list_widget.dart';
import '../../widgets/receipts/goods_receipt_modal_widget.dart';
import '../../widgets/Common/grid_background.dart';

/// Obrazovka Príjem tovaru – scaffold, AppBar, načítanie dát a FAB.
class GoodsReceiptScreen extends StatefulWidget {
  const GoodsReceiptScreen({super.key});

  @override
  State<GoodsReceiptScreen> createState() => _GoodsReceiptScreenState();
}

class _GoodsReceiptScreenState extends State<GoodsReceiptScreen> {
  final ReceiptService _receiptService = ReceiptService();
  final BulkReceiptImportService _importService = BulkReceiptImportService();
  final WarehouseService _warehouseService = WarehouseService();
  List<InboundReceipt> _receipts = [];
  List<Warehouse> _warehouses = [];
  Map<String, String> _movementTypeNames = {};
  int? _filterWarehouseId;
  bool _isLoading = true;
  String? _currentUserUsername;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
    _loadMovementTypes();
    _loadReceipts();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _currentUserUsername = prefs.getString('current_user_username');
          _currentUserRole = prefs.getString('current_user_role');
        });
      }
    });
  }

  Future<void> _loadWarehouses() async {
    final list = await _warehouseService.getActiveWarehouses();
    if (mounted) setState(() => _warehouses = list);
  }

  Future<void> _loadMovementTypes() async {
    final list = await _receiptService.getReceiptMovementTypes();
    if (mounted) {
      setState(() {
        _movementTypeNames = {
          for (final t in list) t.code: t.name,
        };
      });
    }
  }

  Future<void> _loadReceipts() async {
    setState(() => _isLoading = true);
    final list = await _receiptService.getAllReceipts(
      warehouseId: _filterWarehouseId,
    );
    if (mounted) {
      setState(() {
        _receipts = list;
        _isLoading = false;
      });
    }
  }

  void _openNewReceiptModal() {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const GoodsReceiptModal(),
    ).then((saved) {
      if (saved == true) _loadReceipts();
    });
  }

  void _openEditModal(InboundReceipt receipt) {
    if (receipt.id == null || receipt.isApproved) return;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GoodsReceiptModal(receiptId: receipt.id),
    ).then((saved) {
      if (saved == true) _loadReceipts();
    });
  }

  Future<void> _approveReceipt(InboundReceipt receipt) async {
    if (receipt.id == null || receipt.isApproved) return;
    String? approverName;
    try {
      final prefs = await SharedPreferences.getInstance();
      approverName = prefs.getString('current_user_fullname') ?? prefs.getString('current_user_username');
    } catch (_) {}
    await _receiptService.approveReceipt(receipt.id!, approverUsername: approverName);
    if (mounted) {
      _loadReceipts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Príjemka bola schválená'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  Future<void> _submitForApproval(InboundReceipt receipt) async {
    if (receipt.id == null || receipt.isPendingApproval || receipt.isApproved) return;
    String? creatorName;
    try {
      final prefs = await SharedPreferences.getInstance();
      creatorName = prefs.getString('current_user_fullname') ?? prefs.getString('current_user_username') ?? 'Používateľ';
    } catch (_) {
      creatorName = 'Používateľ';
    }
    await _receiptService.submitForApproval(receipt.id!, creatorName);
    if (mounted) {
      _loadReceipts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Príjemka bola odoslaná na schválenie'), backgroundColor: Colors.teal),
      );
    }
  }

  Future<void> _recallReceipt(InboundReceipt receipt) async {
    if (receipt.id == null || !receipt.isPendingApproval) return;
    String? creatorName;
    try {
      final prefs = await SharedPreferences.getInstance();
      creatorName = prefs.getString('current_user_fullname') ?? prefs.getString('current_user_username') ?? 'Používateľ';
    } catch (_) {
      creatorName = 'Používateľ';
    }
    await _receiptService.recallReceipt(receipt.id!, creatorName);
    if (mounted) {
      _loadReceipts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Príjemka bola stiahnutá zo schválenia')),
      );
    }
  }

  Future<void> _rejectReceipt(InboundReceipt receipt) async {
    if (receipt.id == null || !receipt.isPendingApproval) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Zamietnuť príjemku'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              labelText: 'Dôvod zamietnutia',
              hintText: 'Zadajte dôvod...',
            ),
            maxLines: 2,
            onSubmitted: (_) => Navigator.pop(ctx, c.text.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zrušiť')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim().isEmpty ? null : c.text.trim()),
              child: const Text('Zamietnuť'),
            ),
          ],
        );
      },
    );
    if (reason == null && mounted) return;
    if (reason != null) {
      await _receiptService.rejectReceipt(receipt.id!, reason);
      if (mounted) {
        _loadReceipts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Príjemka bola zamietnutá'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _reverseReceipt(InboundReceipt receipt) async {
    if (receipt.id == null) return;
    final isReported = receipt.stockApplied ||
        receipt.isApproved ||
        receipt.status == InboundReceiptStatus.vykazana;

    if (!isReported) {
      // Príjemka ešte nebola vykázaná – len zrušenie (žiadny vplyv na sklad)
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Zrušiť príjemku'),
          content: const Text(
            'Príjemka ešte nebola vykázaná. Naozaj ju chcete zrušiť? Táto akcia len zmení jej stav na zrušená.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nie')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Áno, zrušiť')),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      await _receiptService.cancelReceipt(receipt.id!);
      if (mounted) {
        _loadReceipts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Príjemka bola zrušená'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    // Vykázaná príjemka – výber: storno s odpočítaním zo skladu alebo bez
    String? userName;
    try {
      final prefs = await SharedPreferences.getInstance();
      userName = prefs.getString('current_user_fullname') ?? prefs.getString('current_user_username');
    } catch (_) {}
    if (userName == null && mounted) return;

    final result = await showDialog<_ReverseChoice>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Stornovať príjemku'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Príjemka už bola vykázaná. Ako ju chcete stornovať?',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: c,
                  decoration: const InputDecoration(
                    labelText: 'Dôvod stornovania',
                    hintText: 'Zadajte dôvod...',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zrušiť')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _ReverseChoice(reason: c.text.trim(), deductFromStock: false)),
              child: const Text('Stornovať bez odpočítania zo skladu'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, _ReverseChoice(reason: c.text.trim(), deductFromStock: true)),
              child: const Text('Stornovať s odpočítaním zo skladu'),
            ),
          ],
        );
      },
    );

    if (result == null || !mounted) return;
    await _receiptService.reverseReceipt(
      receipt.id!,
      userName!,
      result.reason.isEmpty ? 'Stornované' : result.reason,
      deductFromStock: result.deductFromStock,
    );
    if (mounted) {
      _loadReceipts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.deductFromStock
              ? 'Príjemka bola stornovaná a množstvá boli odpočítané zo skladu'
              : 'Príjemka bola stornovaná (bez zmeny skladu)'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Zobrazí výber typu tlače (účtovná, s predajnými cenami, slepá, so stavmi) a spustí generovanie.
  Future<void> _printReceiptPdf(InboundReceipt receipt) async {
    if (receipt.id == null) return;
    final type = await showModalBottomSheet<PrintType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Typ tlačového výstupu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...PrintType.values.map((t) => ListTile(
                    leading: Icon(
                      t == PrintType.standard
                          ? Icons.description_outlined
                          : t == PrintType.retail
                              ? Icons.storefront_outlined
                              : t == PrintType.warehouse
                                  ? Icons.inventory_2_outlined
                                  : Icons.analytics_outlined,
                      color: const Color(0xFF10B981),
                    ),
                    title: Text(t.label),
                    onTap: () => Navigator.pop(context, t),
                  )),
            ],
          ),
        ),
      ),
    );
    if (type == null || !mounted) return;
    await _printReceiptPdfWithType(receipt, type);
  }

  Future<void> _printReceiptPdfWithType(InboundReceipt receipt, PrintType type) async {
    if (receipt.id == null) return;
    final items = await _receiptService.getReceiptItems(receipt.id!);
    if (items.isEmpty && !mounted) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pripravujem PDF...')),
      );
    }
    try {
      String? issuedBy;
      try {
        final prefs = await SharedPreferences.getInstance();
        issuedBy = prefs.getString('current_user_fullname') ??
            prefs.getString('current_user_username');
      } catch (_) {}
      final styleConfig = await ReceiptPdfStyleConfig.load();
      final db = DatabaseService();

      String? warehouseName;
      if (receipt.warehouseId != null) {
        final wh = await db.getWarehouseById(receipt.warehouseId!);
        warehouseName = wh?.name;
      }

      Map<String, String> lastPurchaseByProduct = {};
      Map<String, Product> productsByUniqueId = {};
      if (type == PrintType.retail || type == PrintType.stocks) {
        for (final item in items) {
          final product = await db.getProductByUniqueId(item.productUniqueId);
          if (product != null) {
            productsByUniqueId[item.productUniqueId] = product;
            if (product.lastPurchaseDate.isNotEmpty) {
              lastPurchaseByProduct[item.productUniqueId] = product.lastPurchaseDate;
            }
          }
        }
      } else if (styleConfig.showColLastPurchaseDate) {
        for (final item in items) {
          final product = await db.getProductByUniqueId(item.productUniqueId);
          if (product != null && product.lastPurchaseDate.isNotEmpty) {
            lastPurchaseByProduct[item.productUniqueId] = product.lastPurchaseDate;
          }
        }
      }

      final pdfContext = PrijemkaPdfContext(
        issuedBy: issuedBy,
        warehouseName: warehouseName,
        warehouseId: receipt.warehouseId,
        lastPurchaseDateByProductId: lastPurchaseByProduct,
        productsByUniqueId: productsByUniqueId,
        styleConfig: styleConfig,
      );

      final pdfBytes = await PrijemkaPdfGenerator.generatePdf(
        receipt: receipt,
        items: items,
        type: type,
        context: pdfContext,
      );

      final suffix = type.name.toLowerCase();
      final filename =
          'prijemka_${receipt.receiptNumber.replaceAll(RegExp(r'[^\w\-.]'), '_')}_$suffix.pdf';
      try {
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF pripravené na uloženie / zdieľanie'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } on MissingPluginException {
        await _saveAndOpenPdf(pdfBytes, filename);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri generovaní PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadImportTemplate() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final bytes = _importService.buildImportTemplate();
      const filename = 'sablona_import_prijemky.xlsx';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: l10n.downloadImportTemplate,
        fileName: filename,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        lockParentWindow: true,
      );
      if (!mounted) return;
      if (path != null && path.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.downloadImportTemplateSuccess}\n$path'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.importError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importFromExcel() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.single.bytes == null) return;
    final bytes = result.files.single.bytes!;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.importPreview)),
    );
    BulkImportResult importResult;
    try {
      importResult = await _importService.importFromExcel(bytes);
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.importError}: $e'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrintStack(stackTrace: st);
      return;
    }
    if (!mounted) return;
    if (importResult.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.importError}: ${importResult.parseError}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final hasAnyItems = importResult.matchedCount > 0 || importResult.unmatchedCount > 0;
    if (!hasAnyItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noRowsMatched),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ImportPreviewDialog(
        l10n: l10n,
        importResult: importResult,
        onCreateDraft: (supplierName, warehouseId) {
          Navigator.of(ctx).pop();
          SchedulerBinding.instance.addPostFrameCallback((_) {
            _createDraftFromImportResult(
              importResult,
              l10n,
              supplierName: supplierName,
              warehouseId: warehouseId,
            );
          });
        },
      ),
    );
  }

  /// Vytvorí draft príjemku z výsledku importu. Volané po zatvorení dialógu (addPostFrameCallback),
  /// aby sa predišlo assertion chybám počas layoutu.
  Future<void> _createDraftFromImportResult(
    BulkImportResult importResult,
    AppLocalizations l10n, {
    String? supplierName,
    int? warehouseId,
  }) async {
    List<InboundReceiptItem> allItems = List.from(importResult.matchedItems);
    if (importResult.unmatchedRows.isNotEmpty) {
      final newItems = await _importService.createProductsFromUnmatchedRows(
        importResult.unmatchedRows,
        warehouseId: warehouseId,
      );
      allItems.addAll(newItems);
    }
    final receipt = InboundReceipt(
      receiptNumber: '',
      createdAt: DateTime.now(),
      supplierName: supplierName,
      pricesIncludeVat: true,
      vatAppliesToAll: true,
      vatRate: 20,
      warehouseId: warehouseId,
      movementTypeCode: 'STANDARD',
    );
    await _receiptService.createReceipt(
      receipt: receipt,
      items: allItems,
      isDraft: true,
    );
    if (!mounted) return;
    _loadReceipts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.importSuccess),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _saveAndOpenPdf(Uint8List pdfBytes, String filename) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(pdfBytes);
      if (Platform.isWindows) {
        await Process.run('start', ['', file.path], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [file.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [file.path]);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF uložené: ${file.path}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri ukladaní PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF080C0F),
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
                icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Príjem tovaru',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              actions: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: _filterWarehouseId,
                    decoration: const InputDecoration(
                      labelText: 'Sklad',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Všetky sklady'),
                      ),
                      ..._warehouses.map(
                        (w) => DropdownMenuItem(
                          value: w.id,
                          child: Text(
                            w.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (id) {
                      setState(() {
                        _filterWarehouseId = id;
                        _loadReceipts();
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.black87),
                  tooltip: l10n.downloadImportTemplate,
                  onPressed: _downloadImportTemplate,
                ),
                IconButton(
                  icon: const Icon(Icons.upload_file_rounded, color: Colors.black87),
                  tooltip: l10n.importFromExcel,
                  onPressed: _importFromExcel,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ReceiptBackground()),
          Padding(
        padding: const EdgeInsets.only(top: kToolbarHeight + 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GoodsReceiptList(
                    receipts: _receipts,
                    warehouses: _warehouses,
                    movementTypeNames: _movementTypeNames,
                    onAddTap: _openNewReceiptModal,
                    onApprove: _approveReceipt,
                    onEdit: _openEditModal,
                    onPrintPdf: _printReceiptPdf,
                    onSubmit: _submitForApproval,
                    onRecall: _recallReceipt,
                    onReject: _rejectReceipt,
                    onReverse: _reverseReceipt,
                    currentUserUsername: _currentUserUsername,
                    currentUserRole: _currentUserRole,
                  ),
            ),
          ],
        ),
      ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewReceiptModal,
        backgroundColor: const Color(0xFF10B981),
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        label: const Text(
          'Nový príjem',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _ReverseChoice {
  final String reason;
  final bool deductFromStock;
  _ReverseChoice({required this.reason, required this.deductFromStock});
}

String _formatRowPrice(double? value) =>
    value != null && value > 0 ? value.toStringAsFixed(2) : '-';
String _formatRowVat(double? value) =>
    value != null && value > 0 ? value.toStringAsFixed(0) : '-';

Widget _importTableCell(String text, {bool isHeader = false, Color? color}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
        color: color ?? (isHeader ? Colors.black87 : null),
      ),
    ),
  );
}

class _ImportPreviewDialog extends StatefulWidget {
  final AppLocalizations l10n;
  final BulkImportResult importResult;
  final void Function(String? supplierName, int? warehouseId) onCreateDraft;

  const _ImportPreviewDialog({
    required this.l10n,
    required this.importResult,
    required this.onCreateDraft,
  });

  @override
  State<_ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<_ImportPreviewDialog> {
  final SupplierService _supplierService = SupplierService();
  final WarehouseService _warehouseService = WarehouseService();
  List<Supplier> _suppliers = [];
  List<Warehouse> _warehouses = [];
  Supplier? _selectedSupplier;
  Warehouse? _selectedWarehouse;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final suppliers = await _supplierService.getActiveSuppliers();
    final warehouses = await _warehouseService.getAllWarehouses();
    if (mounted) {
      setState(() {
        _suppliers = suppliers;
        _warehouses = warehouses;
        if (_warehouses.isNotEmpty && _selectedWarehouse == null) {
          _selectedWarehouse = _warehouses.first;
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final importResult = widget.importResult;
    final totalValueStr = '${importResult.totalValue.toStringAsFixed(2)} €';
    return AlertDialog(
      title: Text(l10n.importSummaryTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.importPreview,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.importTotalRowsInFile(importResult.totalDataRows),
              style: const TextStyle(fontSize: 13),
            ),
            if (importResult.skippedRows > 0)
              Text(
                l10n.importSkippedRows(importResult.skippedRows),
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            const SizedBox(height: 6),
            Text(
              l10n.matchedRowsCount(importResult.matchedCount),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              l10n.unmatchedRowsCount(importResult.unmatchedCount),
              style: TextStyle(
                fontSize: 13,
                color: importResult.unmatchedCount > 0 ? Colors.orange : null,
              ),
            ),
            if (importResult.matchedCount + importResult.unmatchedCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                l10n.importTotalValue(totalValueStr),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              Text(
                l10n.importSupplierLabel,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[800]),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<Supplier?>(
                isExpanded: true,
                value: _selectedSupplier,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                hint: Text(l10n.importOptionalNone),
                items: [
                  DropdownMenuItem<Supplier?>(value: null, child: Text(l10n.importOptionalNone)),
                  ..._suppliers.map(
                    (s) => DropdownMenuItem<Supplier?>(
                      value: s,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (s) => setState(() => _selectedSupplier = s),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.importWarehouseLabel,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[800]),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<Warehouse?>(
                isExpanded: true,
                value: _selectedWarehouse,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<Warehouse?>(value: null, child: Text(l10n.importOptionalNone)),
                  ..._warehouses.map(
                    (w) => DropdownMenuItem<Warehouse?>(
                      value: w,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              w.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (w) => setState(() => _selectedWarehouse = w),
              ),
            ],
            const SizedBox(height: 14),
            if (importResult.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                l10n.importWarnings,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[800],
                ),
              ),
              const SizedBox(height: 4),
              ...importResult.warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: Colors.orange[700], fontSize: 12)),
                      Expanded(child: Text(w, style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              l10n.importFullTable,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 320,
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    columnWidths: const {
                      0: IntrinsicColumnWidth(),
                      1: IntrinsicColumnWidth(),
                      2: IntrinsicColumnWidth(),
                      3: IntrinsicColumnWidth(),
                      4: IntrinsicColumnWidth(),
                      5: IntrinsicColumnWidth(),
                      6: IntrinsicColumnWidth(),
                      7: IntrinsicColumnWidth(),
                      8: IntrinsicColumnWidth(),
                      9: IntrinsicColumnWidth(),
                      10: IntrinsicColumnWidth(),
                      11: IntrinsicColumnWidth(),
                    },
                    border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey.shade200),
                        children: [
                          _importTableCell('PLU', isHeader: true),
                          _importTableCell(l10n.reportProduct, isHeader: true),
                          _importTableCell('Množstvo', isHeader: true),
                          _importTableCell('MJ', isHeader: true),
                          _importTableCell(l10n.importPricePurchaseWithoutVat, isHeader: true),
                          _importTableCell(l10n.importPricePurchaseWithVat, isHeader: true),
                          _importTableCell(l10n.importVatPurchase, isHeader: true),
                          _importTableCell(l10n.importPriceSaleWithoutVat, isHeader: true),
                          _importTableCell(l10n.importPriceSaleWithVat, isHeader: true),
                          _importTableCell(l10n.importVatSale, isHeader: true),
                          _importTableCell('Dodávateľ', isHeader: true),
                          _importTableCell('Stav', isHeader: true),
                        ],
                      ),
                      ...importResult.matchedItems.asMap().entries.map(
                        (entry) {
                          final i = entry.key;
                          final item = entry.value;
                          final row = i < importResult.matchedRows.length
                              ? importResult.matchedRows[i]
                              : null;
                          final supplier = (i < importResult.matchedItemSupplierNames.length)
                              ? (importResult.matchedItemSupplierNames[i] ?? '-')
                              : '-';
                          return TableRow(
                            children: [
                              _importTableCell(item.plu ?? ''),
                              _importTableCell(item.productName ?? ''),
                              _importTableCell('${item.qty}'),
                              _importTableCell(item.unit),
                              _importTableCell(_formatRowPrice(row?.purchasePriceWithoutVat)),
                              _importTableCell(_formatRowPrice(row?.purchasePriceWithVat)),
                              _importTableCell(_formatRowVat(row?.purchaseVatPercent)),
                              _importTableCell(_formatRowPrice(row?.salePriceWithoutVat)),
                              _importTableCell(_formatRowPrice(row?.salePriceWithVat)),
                              _importTableCell(_formatRowVat(row?.saleVatPercent)),
                              _importTableCell(supplier),
                              _importTableCell(l10n.importStatusExisting, color: Colors.green.shade700),
                            ],
                          );
                        },
                      ),
                      ...importResult.unmatchedRows.map(
                        (row) => TableRow(
                          children: [
                            _importTableCell(row.plu.isNotEmpty ? row.plu : '-'),
                            _importTableCell(row.name?.trim().isEmpty ?? true ? '-' : row.name!),
                            _importTableCell('${row.qty}'),
                            _importTableCell(row.unit),
                            _importTableCell(_formatRowPrice(row.purchasePriceWithoutVat)),
                            _importTableCell(_formatRowPrice(row.purchasePriceWithVat)),
                            _importTableCell(_formatRowVat(row.purchaseVatPercent)),
                            _importTableCell(_formatRowPrice(row.salePriceWithoutVat)),
                            _importTableCell(_formatRowPrice(row.salePriceWithVat)),
                            _importTableCell(_formatRowVat(row.saleVatPercent)),
                            _importTableCell('-'),
                            _importTableCell(l10n.importStatusNew, color: Colors.blue.shade700),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.excelFormatHint,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => widget.onCreateDraft(
            _selectedSupplier?.name,
            _selectedWarehouse?.id,
          ),
          child: Text(l10n.createDraftReceipt),
        ),
      ],
    );
  }
}
