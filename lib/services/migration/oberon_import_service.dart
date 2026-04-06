import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';

import '../../config/oberon_product_import.dart';
import '../../models/product.dart';
import '../Database/database_service.dart';
import 'access_mdb_windows.dart';
import 'oberon_import_spec.dart';

/// Výsledok importu z Oberon SQLite.
class OberonImportResult {
  final int imported;
  final int skipped;
  final int errors;
  final List<String> messages;

  const OberonImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
    this.messages = const [],
  });
}

/// Čítanie Oberon SQLite alebo Microsoft Access (.mdb) na Windows a mapovanie do `products`.
class OberonImportService {
  OberonImportService(this._dbService);

  final DatabaseService _dbService;

  static bool _isAccessPath(String lowerPath) {
    return lowerPath.endsWith('.mdb') ||
        lowerPath.endsWith('.accdb') ||
        lowerPath.endsWith('.mde') ||
        lowerPath.endsWith('.accde') ||
        lowerPath.endsWith('.laccdb');
  }

  /// Varovanie pre UI: Access mimo Windows. Na Windows s .mdb vráti null.
  static String? sqlitePathRejectionMessage(String path) {
    final lower = path.toLowerCase().trim();
    if (!_isAccessPath(lower)) return null;
    if (!kIsWeb && Platform.isWindows) return null;
    return 'Import súborov Microsoft Access (.mdb / .accdb) je v tejto aplikácii dostupný len na Windows. '
        'Na iných platformách použite SQLite (.db) alebo export z Accessu do CSV.';
  }

  /// Informácia pre Windows + Access (nie je chyba).
  static String? accessEngineHint(String path) {
    final lower = path.toLowerCase().trim();
    if (!_isAccessPath(lower)) return null;
    if (kIsWeb || !Platform.isWindows) return null;
    return 'Súbor Access: na čítanie sa použije OLE DB. Ak import zlyhá, nainštalujte '
        '„Microsoft Access Database Engine“ (64-bit, ak je StockPilot 64-bit) z Microsoft Download Center.';
  }

  /// Zoznam tabuliek (SQLite alebo Access na Windows).
  Future<List<String>> listTables(String databasePath) async {
    final lower = databasePath.toLowerCase();
    if (_isAccessPath(lower)) {
      if (kIsWeb || !Platform.isWindows) {
        throw FormatException(sqlitePathRejectionMessage(databasePath) ?? 'Access nie je podporovaný.');
      }
      return AccessMdbWindows.listTables(databasePath);
    }

    Database db;
    try {
      db = await openDatabase(databasePath, readOnly: true);
    } catch (e) {
      throw _wrapOpenDatabaseError(e);
    }
    try {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      return rows.map((r) => r['name'] as String).toList();
    } finally {
      await db.close();
    }
  }

  /// Stĺpce tabuľky (SQLite: PRAGMA; Access: schéma OLE DB na Windows).
  Future<List<String>> listColumns(String databasePath, String tableName) async {
    final lower = databasePath.toLowerCase();
    if (_isAccessPath(lower)) {
      if (kIsWeb || !Platform.isWindows) {
        throw FormatException(sqlitePathRejectionMessage(databasePath) ?? 'Access nie je podporovaný.');
      }
      return AccessMdbWindows.listColumns(databasePath, tableName);
    }

    Database db;
    try {
      db = await openDatabase(databasePath, readOnly: true);
    } catch (e) {
      throw _wrapOpenDatabaseError(e);
    }
    try {
      final rows = await db.rawQuery('PRAGMA table_info(${_quoteIdent(tableName)})');
      return rows.map((r) => r['name'] as String).toList();
    } finally {
      await db.close();
    }
  }

  Future<List<Map<String, dynamic>>> _parseCsvToMapList(String csvPath) async {
    final text = await File(csvPath).readAsString(encoding: utf8);
    if (text.trim().isEmpty) return [];
    final rows = const CsvToListConverter(shouldParseNumbers: false).convert(text);
    if (rows.isEmpty) return [];
    final headers = rows.first.map((e) => e.toString()).toList();
    final out = <Map<String, dynamic>>[];
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      final m = <String, dynamic>{};
      for (var j = 0; j < headers.length; j++) {
        if (j < r.length) {
          m[headers[j]] = r[j];
        }
      }
      out.add(m);
    }
    return out;
  }

  /// Import produktov podľa [oberonProductImportSpec] alebo vlastného [spec].
  Future<OberonImportResult> importProducts(
    String oberonDatabasePath, {
    OberonProductImportSpec? spec,
  }) async {
    final s = spec ?? oberonProductImportSpec;
    final uid = DatabaseService.currentUserId;
    if (uid == null || uid.isEmpty) {
      return const OberonImportResult(
        imported: 0,
        skipped: 0,
        errors: 1,
        messages: [
          'Nie ste prihlásený – import vyžaduje aktívnu reláciu (user_id v databáze).',
        ],
      );
    }
    if (s.tableName.trim().isEmpty) {
      return const OberonImportResult(
        imported: 0,
        skipped: 0,
        errors: 1,
        messages: [
          'Vyberte tabuľku v obrazovke Import z Oberon alebo nastavte tableName v lib/config/oberon_product_import.dart. '
          'Mapovanie stĺpcov (columnMap) musí byť v tom istom súbore.',
        ],
      );
    }

    if (s.columnMap.isEmpty) {
      return const OberonImportResult(
        imported: 0,
        skipped: 0,
        errors: 1,
        messages: [
          'Vyplňte columnMap v lib/config/oberon_product_import.dart (aspoň name a plu).',
        ],
      );
    }

    final lower = oberonDatabasePath.toLowerCase();

    if (_isAccessPath(lower)) {
      if (kIsWeb || !Platform.isWindows) {
        return OberonImportResult(
          imported: 0,
          skipped: 0,
          errors: 1,
          messages: [
            sqlitePathRejectionMessage(oberonDatabasePath) ?? 'Access nie je na tejto platforme podporovaný.',
          ],
        );
      }
      String? csvPath;
      try {
        csvPath = await AccessMdbWindows.exportTableToCsv(oberonDatabasePath, s.tableName);
        final rows = await _parseCsvToMapList(csvPath);
        return _importRows(rows, s);
      } catch (e) {
        return OberonImportResult(
          imported: 0,
          skipped: 0,
          errors: 1,
          messages: [e.toString()],
        );
      } finally {
        if (csvPath != null) {
          try {
            await File(csvPath).delete();
          } catch (_) {}
        }
      }
    }

    Database? oberonDb;
    try {
      oberonDb = await openDatabase(oberonDatabasePath, readOnly: true);
    } catch (e) {
      return OberonImportResult(
        imported: 0,
        skipped: 0,
        errors: 1,
        messages: [_wrapOpenDatabaseError(e).toString()],
      );
    }

    try {
      List<Map<String, dynamic>> rows;
      try {
        rows = await oberonDb.rawQuery('SELECT * FROM ${_quoteIdent(s.tableName)}');
      } catch (e) {
        return OberonImportResult(
          imported: 0,
          skipped: 0,
          errors: 1,
          messages: [
            'Nepodarilo sa čítať tabuľku "${s.tableName}": $e',
          ],
        );
      }
      return _importRows(rows, s);
    } finally {
      await oberonDb.close();
    }
  }

  Future<OberonImportResult> _importRows(
    List<Map<String, dynamic>> rows,
    OberonProductImportSpec s,
  ) async {
    final messages = <String>[];
    final existingProducts = await _dbService.getProducts();
    final existingPlu = <String>{
      for (final p in existingProducts)
        if (p.plu.trim().isNotEmpty) p.plu.trim().toLowerCase(),
    };

    var imported = 0;
    var skipped = 0;
    var errors = 0;
    var rowIndex = 0;

    for (final row in rows) {
      rowIndex++;
      try {
        final product = _rowToProduct(row, s, rowIndex);
        if (product.name.trim().isEmpty) {
          skipped++;
          messages.add('Riadok $rowIndex: prázdny názov — preskočené');
          continue;
        }
        final pluKey = product.plu.trim().toLowerCase();
        if (pluKey.isNotEmpty && s.skipIfPluExists && existingPlu.contains(pluKey)) {
          skipped++;
          continue;
        }
        if (pluKey.isNotEmpty) existingPlu.add(pluKey);

        await _dbService.insertProduct(product);
        imported++;
      } catch (e) {
        errors++;
        messages.add('Riadok $rowIndex: $e');
      }
    }

    return OberonImportResult(
      imported: imported,
      skipped: skipped,
      errors: errors,
      messages: messages.length > 50 ? messages.sublist(0, 50) : messages,
    );
  }

  Product _rowToProduct(
    Map<String, dynamic> row,
    OberonProductImportSpec spec,
    int rowIndex,
  ) {
    dynamic raw(String stockPilotKey) {
      final col = spec.columnMap[stockPilotKey];
      if (col == null || col.isEmpty) return null;
      if (row.containsKey(col)) return row[col];
      final want = col.toLowerCase();
      for (final e in row.entries) {
        if (e.key.toLowerCase() == want) return e.value;
      }
      return null;
    }

    String str(String key, [String fallback = '']) {
      final v = raw(key);
      if (v == null) return fallback;
      return v.toString().trim();
    }

    double d(String key, [double fallback = 0]) {
      final v = raw(key);
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(',', '.')) ?? fallback;
    }

    int i(String key, [int fallback = 0]) {
      final v = raw(key);
      if (v == null) return fallback;
      if (v is bool) return v ? 1 : 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString().trim()) ?? fallback;
    }

    bool bit(String key, bool fallback) {
      final v = raw(key);
      if (v == null) return fallback;
      final col = spec.columnMap[key];
      final invertIsActive =
          key == 'is_active' && col != null && col.trim().toLowerCase() == 'disabled';

      bool truth;
      if (v is bool) {
        truth = v;
      } else if (v is num) {
        truth = v != 0;
      } else {
        final s = v.toString().toLowerCase().trim();
        truth = s == '1' ||
            s == '-1' ||
            s == 'true' ||
            s == 'áno' ||
            s == 'yes';
      }
      if (invertIsActive) return !truth;
      return truth;
    }

    final name = str('name');
    var plu = str('plu');
    if (plu.isEmpty) {
      plu = 'OBR-$rowIndex';
    }

    final uniqueId = _makeUniqueId(plu, name, rowIndex);

    int? warehouseId;
    if (spec.columnMap['warehouse_id'] != null &&
        spec.columnMap['warehouse_id']!.trim().isNotEmpty) {
      final v = raw('warehouse_id');
      warehouseId = v == null ? spec.defaultWarehouseId : i('warehouse_id');
    } else {
      warehouseId = spec.defaultWarehouseId;
    }

    int? kindId;
    if (spec.columnMap['kind_id'] != null && spec.columnMap['kind_id']!.trim().isNotEmpty) {
      final v = raw('kind_id');
      kindId = v == null ? null : i('kind_id');
    }

    final price = d('price');
    final withoutVat = d('without_vat');
    final vatPct = i('vat', 20);

    return Product(
      uniqueId: uniqueId,
      name: name.isEmpty ? 'Bez názvu' : name,
      plu: plu,
      ean: str('ean').isEmpty ? null : str('ean'),
      category: str('category'),
      qty: d('qty'),
      unit: str('unit', 'ks').isEmpty ? 'ks' : str('unit', 'ks'),
      price: price,
      withoutVat: withoutVat,
      vat: vatPct,
      discount: i('discount'),
      lastPurchasePrice: d('last_purchase_price'),
      lastPurchasePriceWithoutVat: d('last_purchase_price_without_vat'),
      lastPurchaseDate: str('last_purchase_date'),
      currency: str('currency', spec.defaultCurrency).isEmpty
          ? spec.defaultCurrency
          : str('currency', spec.defaultCurrency),
      location: str('location'),
      purchasePrice: d('purchase_price'),
      purchasePriceWithoutVat: d('purchase_price_without_vat'),
      purchaseVat: i('purchase_vat', 20),
      recyclingFee: d('recycling_fee'),
      productType: str('product_type', 'Sklad').isEmpty ? 'Sklad' : str('product_type', 'Sklad'),
      supplierName: str('supplier_name').isEmpty ? null : str('supplier_name'),
      kindId: kindId,
      warehouseId: warehouseId,
      minQuantity: i('min_quantity'),
      allowAtCashRegister: bit('allow_at_cash_register', true),
      showInPriceList: bit('show_in_price_list', true),
      isActive: bit('is_active', true),
      temporarilyUnavailable: bit('temporarily_unavailable', false),
      stockGroup: str('stock_group').isEmpty ? null : str('stock_group'),
      cardType: str('card_type', 'jednoduchá').isEmpty ? 'jednoduchá' : str('card_type', 'jednoduchá'),
      hasExtendedPricing: bit('has_extended_pricing', false),
      ibaCeleMnozstva: bit('iba_cele_mnozstva', false),
    );
  }

  String _makeUniqueId(String plu, String name, int rowIndex) {
    final base = utf8.encode('oberon|$plu|$name|$rowIndex');
    final h = sha256.convert(base).toString().substring(0, 24);
    return 'oberon-$h';
  }

  static String _quoteIdent(String name) => '"${name.replaceAll('"', '""')}"';

  static Object _wrapOpenDatabaseError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('code 26') ||
        s.contains('not a database') ||
        s.contains('file is not a database')) {
      return FormatException(
        'Súbor nie je platná SQLite databáza (chyba 26). '
        'Skontrolujte, či ide o .db / .sqlite.',
      );
    }
    return e;
  }
}
