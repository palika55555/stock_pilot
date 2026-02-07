import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../models/receipt.dart';
import '../../services/Receipt/receipt_service.dart';
import '../../services/Receipt/receipt_pdf_service.dart';
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
      final pdfBytes = await ReceiptPdfService.buildPdf(
        receipt: receipt,
        items: items,
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
