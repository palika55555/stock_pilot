import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../../models/receipt.dart';
import '../../models/receipt_pdf_style_config.dart';
import '../../services/Database/database_service.dart';
import '../../services/Receipt/receipt_service.dart';
import '../../services/Receipt/receipt_pdf_service.dart';
import '../../services/Receipt/bulk_receipt_import_service.dart';
import '../../widgets/receipts/goods_receipt_list_widget.dart';
import '../../widgets/receipts/goods_receipt_modal_widget.dart';

/// Obrazovka Príjem tovaru – scaffold, AppBar, načítanie dát a FAB.
class GoodsReceiptScreen extends StatefulWidget {
  const GoodsReceiptScreen({super.key});

  @override
  State<GoodsReceiptScreen> createState() => _GoodsReceiptScreenState();
}

class _GoodsReceiptScreenState extends State<GoodsReceiptScreen> {
  final ReceiptService _receiptService = ReceiptService();
  final BulkReceiptImportService _importService = BulkReceiptImportService();
  List<InboundReceipt> _receipts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() => _isLoading = true);
    final list = await _receiptService.getAllReceipts();
    if (mounted) {
      setState(() {
        _receipts = list;
        _isLoading = false;
      });
    }
  }

  void _openNewReceiptModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => GoodsReceiptModal(),
    ).then((saved) {
      if (saved == true) _loadReceipts();
    });
  }

  void _openEditModal(InboundReceipt receipt) {
    if (receipt.id == null || receipt.isApproved) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => GoodsReceiptModal(receiptId: receipt.id),
    ).then((saved) {
      if (saved == true) _loadReceipts();
    });
  }

  Future<void> _approveReceipt(InboundReceipt receipt) async {
    if (receipt.id == null || receipt.isApproved) return;
    await _receiptService.approveReceipt(receipt.id!);
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

  Future<void> _printReceiptPdf(InboundReceipt receipt) async {
    if (receipt.id == null) return;
    final items = await _receiptService.getReceiptItems(receipt.id!);
    if (items.isEmpty && !mounted) return;
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pripravujem PDF...')));
    }
    try {
      String? issuedBy;
      try {
        final prefs = await SharedPreferences.getInstance();
        issuedBy = prefs.getString('current_user_fullname') ??
            prefs.getString('current_user_username');
      } catch (_) {}
      final styleConfig = await ReceiptPdfStyleConfig.load();
      Map<String, String> lastPurchaseByProduct = {};
      if (styleConfig.showColLastPurchaseDate) {
        final db = DatabaseService();
        for (final item in items) {
          final product = await db.getProductByUniqueId(item.productUniqueId);
          if (product != null && product.lastPurchaseDate.isNotEmpty) {
            lastPurchaseByProduct[item.productUniqueId] = product.lastPurchaseDate;
          }
        }
      }
      final pdfBytes = await ReceiptPdfService.buildPdf(
        receipt: receipt,
        items: items,
        issuedBy: issuedBy,
        styleConfig: styleConfig,
        lastPurchaseDateByProductId: lastPurchaseByProduct,
      );
      final filename =
          'prijemka_${receipt.receiptNumber.replaceAll(RegExp(r'[^\w\-.]'), '_')}.pdf';
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
    final importResult = await _importService.importFromExcel(bytes);
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
    if (importResult.matchedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noRowsMatched),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ImportPreviewDialog(
        l10n: l10n,
        importResult: importResult,
        onCreateDraft: () async {
          Navigator.of(ctx).pop();
          final receipt = InboundReceipt(
            receiptNumber: '',
            createdAt: DateTime.now(),
            pricesIncludeVat: true,
            vatAppliesToAll: true,
            vatRate: 20,
          );
          await _receiptService.createReceipt(
            receipt: receipt,
            items: importResult.matchedItems,
            isDraft: true,
          );
          if (mounted) {
            _loadReceipts();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.importSuccess),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
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
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Príjem tovaru',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              actions: [
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoodsReceiptList(
              receipts: _receipts,
              onAddTap: _openNewReceiptModal,
              onApprove: _approveReceipt,
              onEdit: _openEditModal,
              onPrintPdf: _printReceiptPdf,
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

class _ImportPreviewDialog extends StatelessWidget {
  final AppLocalizations l10n;
  final BulkImportResult importResult;
  final VoidCallback onCreateDraft;

  const _ImportPreviewDialog({
    required this.l10n,
    required this.importResult,
    required this.onCreateDraft,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(l10n.importPreview),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.matchedRowsCount(importResult.matchedCount),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.unmatchedRowsCount(importResult.unmatchedCount),
              style: TextStyle(
                color: importResult.unmatchedCount > 0 ? Colors.orange : null,
              ),
            ),
            if (importResult.unmatchedRows.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Nezhodné (PLU/Názov):',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: importResult.unmatchedRows.length,
                  itemBuilder: (_, i) {
                    final row = importResult.unmatchedRows[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${row.plu.isNotEmpty ? row.plu : row.name ?? "?"} – ${row.qty} ${row.unit}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ],
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
          onPressed: onCreateDraft,
          child: Text(l10n.createDraftReceipt),
        ),
      ],
    );
  }
}
