import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:stock_pilot/theme/app_theme.dart';
import 'package:stock_pilot/l10n/app_localizations.dart';
import 'package:stock_pilot/models/warehouse.dart';
import 'package:stock_pilot/models/warehouse_movement_record.dart';
import 'package:stock_pilot/services/Warehouse/warehouse_service.dart';

/// Evidencia záznamov o skladových pohyboch (kniha skladových pohybov).
/// Skladový pohyb = príjem jednej položky do skladu alebo výdaj jednej položky zo skladu.
/// Záznamy sú len na čítanie – vznikajú z dokladov (príjemky, výdajky, presuny).
/// Filter Sklad umožňuje zobraziť pohyby len pre vybraný sklad.
class WarehouseMovementsListScreen extends StatefulWidget {
  const WarehouseMovementsListScreen({super.key});

  @override
  State<WarehouseMovementsListScreen> createState() =>
      _WarehouseMovementsListScreenState();
}

class _WarehouseMovementsListScreenState extends State<WarehouseMovementsListScreen> {
  final WarehouseService _warehouseService = WarehouseService();
  List<WarehouseMovementRecord> _records = [];
  List<Warehouse> _warehouses = [];
  int? _filterWarehouseId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
    _load();
  }

  Future<void> _loadWarehouses() async {
    final list = await _warehouseService.getActiveWarehouses();
    if (mounted) setState(() => _warehouses = list);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await _warehouseService.getWarehouseMovementRecords(
      warehouseId: _filterWarehouseId,
    );
    if (mounted) {
      setState(() {
        _records = records;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.bgPrimary,
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
                icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                l10n.stockMovements,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWarehouseFilter(l10n),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: const Color(0xFF6366F1),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        children: [
                          ..._buildMovementRecordTiles(),
                          if (_records.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.inbox_rounded,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _filterWarehouseId == null
                                          ? 'Zatiaľ žiadne skladové pohyby'
                                          : 'Žiadne pohyby pre vybraný sklad',
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
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseFilter(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _filterWarehouseId,
          isExpanded: true,
          hint: Text(l10n.chooseWarehouse),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(l10n.warehouseFilterAll),
            ),
            for (final w in _warehouses)
              DropdownMenuItem<int?>(
                value: w.id,
                child: Text(w.name),
              ),
          ],
          onChanged: (int? value) {
            setState(() {
              _filterWarehouseId = value;
              _loading = true;
            });
            _load();
          },
        ),
      ),
    );
  }

  List<Widget> _buildMovementRecordTiles() {
    return _records.map((r) {
      final isIn = r.isIn;
      final color = isIn
          ? const Color(0xFF6366F1)
          : const Color(0xFFDC2626);
      final icon = isIn
          ? Icons.south_west_rounded
          : Icons.north_east_rounded;
      final dirLabel = isIn ? 'Príjem' : 'Výdaj';
      final productLabel = r.productName?.isNotEmpty == true
          ? r.productName!
          : (r.plu?.isNotEmpty == true ? 'PLU ${r.plu}' : r.productUniqueId);
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF263238),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dirLabel · ${r.documentNumber} · ${_formatDate(r.createdAt)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${r.qty} ${r.unit}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
