import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:stock_pilot/models/receipt.dart';
import 'package:stock_pilot/models/stock_out.dart';
import 'package:stock_pilot/models/warehouse_transfer.dart';
import 'package:stock_pilot/services/Receipt/receipt_service.dart';
import 'package:stock_pilot/services/StockOut/stock_out_service.dart';
import 'package:stock_pilot/services/Warehouse/warehouse_service.dart';

/// Zoznam všetkých pohybov na sklade (príjemky, výdajky, presuny medzi skladmi).
class WarehouseMovementsListScreen extends StatefulWidget {
  const WarehouseMovementsListScreen({super.key});

  @override
  State<WarehouseMovementsListScreen> createState() =>
      _WarehouseMovementsListScreenState();
}

class _WarehouseMovementsListScreenState extends State<WarehouseMovementsListScreen> {
  final ReceiptService _receiptService = ReceiptService();
  final WarehouseService _warehouseService = WarehouseService();
  final StockOutService _stockOutService = StockOutService();
  List<InboundReceipt> _receipts = [];
  List<WarehouseTransfer> _transfers = [];
  List<StockOut> _stockOuts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final receipts = await _receiptService.getAllReceipts();
    final transfers = await _warehouseService.getWarehouseTransfers();
    final stockOuts = await _stockOutService.getAllStockOuts();
    if (mounted) {
      setState(() {
        _receipts = receipts;
        _transfers = transfers;
        _stockOuts = stockOuts;
        _loading = false;
      });
    }
  }

  /// Zlúčený zoznam pohybov zoradený podľa dátumu (najnovší hore).
  List<_MovementItem> get _allMovements {
    final items = <_MovementItem>[
      for (final r in _receipts) _MovementItem(receipt: r),
      for (final t in _transfers) _MovementItem(transfer: t),
      for (final s in _stockOuts) _MovementItem(stockOut: s),
    ];
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
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
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Všetky pohyby na sklade',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              )
            : RefreshIndicator(
                onRefresh: _load,
                color: const Color(0xFF6366F1),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    ..._buildMovementTiles(),
                    if (_receipts.isEmpty && _transfers.isEmpty && _stockOuts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.inbox_rounded,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Zatiaľ žiadne pohyby',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  List<Widget> _buildMovementTiles() {
    return _allMovements.map((item) {
      if (item.receipt != null) {
        final r = item.receipt!;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.south_west_rounded, color: Color(0xFF6366F1)),
            ),
            title: Text(
              r.receiptNumber,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Príjem · ${_formatDate(r.createdAt)}${r.supplierName != null && r.supplierName!.isNotEmpty ? ' · ${r.supplierName}' : ''}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      }
      if (item.stockOut != null) {
        final s = item.stockOut!;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.north_east_rounded, color: Color(0xFFDC2626)),
            ),
            title: Text(
              s.documentNumber,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFDC2626),
              ),
            ),
            subtitle: Text(
              'VÝDAJ · ${s.issueType.label} · ${_formatDate(s.createdAt)}${s.recipientName != null && s.recipientName!.isNotEmpty ? ' · ${s.recipientName}' : ''}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      }
      final t = item.transfer!;
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0D9488)),
          ),
          title: Text(
            '${t.productName} · ${t.quantity} ${t.unit}',
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'Presun · ${_formatDate(t.createdAt)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
    }).toList();
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) {
      return 'Dnes ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day}.${d.month}.${d.year}';
  }
}

class _MovementItem {
  final InboundReceipt? receipt;
  final WarehouseTransfer? transfer;
  final StockOut? stockOut;
  _MovementItem({this.receipt, this.transfer, this.stockOut})
      : assert(receipt != null || transfer != null || stockOut != null);
  DateTime get date =>
      receipt?.createdAt ?? transfer?.createdAt ?? stockOut!.createdAt;
}
