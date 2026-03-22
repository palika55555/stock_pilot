import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/warehouse.dart';
import '../../models/product.dart';
import '../../services/Database/database_service.dart';
import '../../services/user_session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// Bottom sheet pre inventúru skladu so skenerom a zoznamom produktov.
class WarehouseInventorySheetWidget extends StatefulWidget {
  const WarehouseInventorySheetWidget({
    super.key,
    required this.warehouse,
    required this.onSaved,
  });

  final Warehouse warehouse;
  final VoidCallback? onSaved;

  @override
  State<WarehouseInventorySheetWidget> createState() =>
      _WarehouseInventorySheetWidgetState();
}

class _WarehouseInventorySheetWidgetState
    extends State<WarehouseInventorySheetWidget> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Product> _products = [];
  List<Product> _filtered = [];
  bool _loading = true;
  /// Skutočné množstvá zadané používateľom: productKey (uniqueId ?? plu) -> qty
  final Map<String, int> _actualQty = {};
  /// Index riadku, ktorý má dostať focus po naskenovaní
  int? _focusRequestIndex;
  bool _saving = false;

  String _productKey(Product p) => p.uniqueId ?? p.plu;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filter);
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final id = widget.warehouse.id;
    if (id == null) return;
    setState(() => _loading = true);
    final list = await _db.getProductsByWarehouseId(id);
    if (mounted) {
      setState(() {
        _products = list;
        _filter();
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.from(_products);
    } else {
      _filtered = _products.where((p) {
        return p.name.toLowerCase().contains(q) ||
            (p.plu.toLowerCase().contains(q)) ||
            (p.uniqueId?.toLowerCase().contains(q) ?? false) ||
            (p.ean?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    setState(() {});
  }

  int? _findProductIndexByCode(String code) {
    final c = code.trim();
    if (c.isEmpty) return null;
    for (int i = 0; i < _filtered.length; i++) {
      final p = _filtered[i];
      if (p.plu == c || p.uniqueId == c || (p.ean != null && p.ean!.trim() == c)) return i;
    }
    return null;
  }

  Future<void> _openScanner() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pre skenovanie je potrebný prístup ku kamere.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    final String? code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (ctx) => _InventoryScannerScreen(
          onScanned: (value) => Navigator.of(ctx).pop(value),
        ),
      ),
    );
    if (code == null || !mounted) return;
    final idx = _findProductIndexByCode(code);
    if (idx == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produkt s kódom "$code" nie je v zozname.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _focusRequestIndex = idx);
    // Scroll to item and focus after build
    final itemHeight = 88.0;
    final offset = (idx * itemHeight).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  int _getActualQty(Product p) {
    return _actualQty[_productKey(p)] ?? p.qty.round();
  }

  void _setActualQty(Product p, int value) {
    setState(() => _actualQty[_productKey(p)] = value);
  }

  /// Zmeny na uloženie: len unique_id produktov, kde sa qty líši od systému.
  Map<String, int> _buildChanges() {
    final Map<String, int> changes = {};
    for (final p in _products) {
      final uid = p.uniqueId;
      if (uid == null) continue;
      final actual = _getActualQty(p);
      if (actual != p.qty) changes[uid] = actual;
    }
    return changes;
  }

  Future<void> _saveInventory() async {
    final id = widget.warehouse.id;
    if (id == null) return;
    final changes = _buildChanges();
    if (changes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Žiadne zmeny na uloženie.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      return;
    }

    final confirmed = await _showConfirmationDialog(changes);
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    await _db.updateStockAfterAudit(
      id,
      changes,
      warehouseName: widget.warehouse.name,
      username: UserSession.username ?? '',
      allProducts: _products,
    );
    if (mounted) {
      setState(() => _saving = false);
      widget.onSaved?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Inventúra uložená (${changes.length} zmien).'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool?> _showConfirmationDialog(Map<String, int> changes) {
    final productMap = <String, Product>{};
    for (final p in _products) {
      if (p.uniqueId != null) productMap[p.uniqueId!] = p;
    }
    int surplus = 0;
    int deficit = 0;
    for (final e in changes.entries) {
      final p = productMap[e.key];
      if (p == null) continue;
      final diff = e.value - p.qty.round();
      if (diff > 0) {
        surplus += diff;
      } else {
        deficit += diff.abs();
      }
    }

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.fact_check_rounded, color: AppColors.accentGold),
            const SizedBox(width: 10),
            Text(
              'Potvrdenie inventúry',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sklad: ${widget.warehouse.name}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _confirmRow(Icons.edit_note_rounded, 'Zmenené produkty', '${changes.length}', AppColors.accentGold),
            const SizedBox(height: 8),
            if (surplus > 0) ...[
              _confirmRow(Icons.add_circle_outline, 'Prebytok (celkom)', '+$surplus', Colors.green),
              const SizedBox(height: 8),
            ],
            if (deficit > 0) ...[
              _confirmRow(Icons.remove_circle_outline, 'Manko (celkom)', '-$deficit', Colors.red),
              const SizedBox(height: 8),
            ],
            const Divider(),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: changes.entries.map((e) {
                    final p = productMap[e.key];
                    if (p == null) return const SizedBox.shrink();
                    final diff = e.value - p.qty.round();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${p.name} (${p.plu})',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${p.qty.round()} → ${e.value}',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: diff > 0 ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${diff > 0 ? "+" : ""}$diff',
                              style: TextStyle(
                                color: diff > 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Zrušiť', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: AppColors.bgPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Uložiť inventúru'),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        ),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
          left: BorderSide(color: AppColors.borderSubtle, width: 1),
          right: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
          children: [
            _buildHeader(l10n, scrollController),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(color: AppColors.accentGold),
                    )
                  : _filtered.isEmpty
                      ? Center(
                          child: Text(
                            l10n.noResults,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final p = _filtered[index];
                            final requestFocus = _focusRequestIndex == index;
                            if (requestFocus) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_focusRequestIndex == index && mounted) {
                                  setState(() => _focusRequestIndex = null);
                                }
                              });
                            }
                            return _InventoryRow(
                              product: p,
                              actualQty: _getActualQty(p),
                              onQtyChanged: (v) => _setActualQty(p, v),
                              requestFocus: requestFocus,
                              onFocused: () {
                                if (mounted && _focusRequestIndex == index) {
                                  setState(() => _focusRequestIndex = null);
                                }
                              },
                            );
                          },
                        ),
            ),
            _buildSaveBar(l10n),
          ],
        );
        },
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, ScrollController scrollController) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.inventoryTitle}: ${widget.warehouse.name}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _openScanner,
                icon: Icon(Icons.camera_alt_rounded, color: AppColors.bgPrimary),
                tooltip: l10n.scanProduct,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: AppColors.bgPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: l10n.inventorySearchHint,
              hintStyle: TextStyle(color: AppColors.textMuted),
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.accentGold),
              filled: true,
              fillColor: AppColors.bgInput,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderDefault),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _saveInventory,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: AppColors.bgPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _saving
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: AppColors.bgPrimary,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    l10n.saveInventory,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.bgPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Jeden riadok zoznamu: názov, kód, TextField skutočný stav, v systéme, badge rozdielu.
class _InventoryRow extends StatefulWidget {
  const _InventoryRow({
    required this.product,
    required this.actualQty,
    required this.onQtyChanged,
    required this.requestFocus,
    required this.onFocused,
  });

  final Product product;
  final int actualQty;
  final ValueChanged<int> onQtyChanged;
  final bool requestFocus;
  final VoidCallback onFocused;

  @override
  State<_InventoryRow> createState() => _InventoryRowState();
}

class _InventoryRowState extends State<_InventoryRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.actualQty}');
    _focusNode = FocusNode();
    if (widget.requestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.canRequestFocus) {
          _focusNode.requestFocus();
          widget.onFocused();
        }
      });
    }
  }

  @override
  void didUpdateWidget(_InventoryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.actualQty != oldWidget.actualQty &&
        _controller.text != '${widget.actualQty}') {
      _controller.text = '${widget.actualQty}';
    }
    if (widget.requestFocus && !oldWidget.requestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.canRequestFocus) {
          _focusNode.requestFocus();
          widget.onFocused();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final systemQty = p.qty;
    final actual = widget.actualQty;
    final diff = actual - systemQty;
    final hasDiff = diff != 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.plu,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${AppLocalizations.of(context)!.inSystemKs} ${systemQty} ${p.unit}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.actualStock,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null && n >= 0) widget.onQtyChanged(n);
                },
              ),
            ),
            if (hasDiff) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: diff > 0
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${diff > 0 ? "+" : ""}$diff',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: diff > 0 ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Jednoduchá obrazovka skenera pre inventúru – vráti naskenovaný kód.
class _InventoryScannerScreen extends StatefulWidget {
  const _InventoryScannerScreen({required this.onScanned});

  final ValueChanged<String> onScanned;

  @override
  State<_InventoryScannerScreen> createState() => _InventoryScannerScreenState();
}

class _InventoryScannerScreenState extends State<_InventoryScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: true,
    formats: [BarcodeFormat.all],
  );
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    _handled = true;
    widget.onScanned(code);
    Navigator.of(context).pop(code);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.scanProduct),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}
