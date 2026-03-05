import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/company.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/quote.dart';
import '../../models/receipt.dart';
import '../../models/supplier.dart';
import '../../models/user.dart';
import '../../models/warehouse.dart';
import '../../models/warehouse_transfer.dart';
import '../../models/stock_out.dart';
import '../../models/movement_type.dart';
import '../../models/stock_movement.dart';
import '../../models/warehouse_movement_record.dart';
import '../../models/transport.dart';
import '../../models/app_notification.dart';
import '../../models/product_kind.dart';
import '../../models/receptura_polozka.dart';
import '../../models/production_batch.dart';
import '../../models/production_batch_recipe_item.dart';
import '../../models/pallet.dart';
import '../../models/recipe.dart';
import '../../models/production_order.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  static Future<Database>? _dbFuture;
  static String? _customPath;
  static const String _kCurrentUserIdKey = 'current_user_id';

  /// Current user identifier (e.g. backend user id as string) – all reads/writes filter by this. Set on login, cleared on logout.
  static String? _currentUserId;

  static String? get currentUserId => _currentUserId;

  /// Set current user for all DB operations and persist to SharedPreferences so it survives static resets.
  static Future<void> setCurrentUser(String userId) async {
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentUserIdKey, userId);
    print('DEBUG setCurrentUser: $userId | instance: ${_instance.hashCode}');
  }

  /// Restore current user from memory or SharedPreferences (used when static field was reset).
  static Future<String?> restoreCurrentUser() async {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      print('DEBUG restoreCurrentUser: already set to $_currentUserId | instance: ${_instance.hashCode}');
      return _currentUserId;
    }
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString(_kCurrentUserIdKey);
    print('DEBUG restoreCurrentUser: restored $_currentUserId | instance: ${_instance.hashCode}');
    return _currentUserId;
  }

  static void clearCurrentUser() {
    print('DEBUG clearCurrentUser called! Stack:');
    print(StackTrace.current);
    print('DEBUG clearCurrentUser previous value: $_currentUserId | instance: ${_instance.hashCode}');
    _currentUserId = null;
    // Best-effort async cleanup of persisted user id.
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_kCurrentUserIdKey);
    });
  }

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<void> setCustomPath(String path) async {
    _customPath = path;
    _database = null;
    _dbFuture = null;
  }

  /// Where clause and args for current user (for SELECT/UPDATE/DELETE). When no user set, returns (null, null) – callers should handle.
  static String? get _userWhere => _currentUserId != null ? 'user_id = ?' : null;
  static List<dynamic>? get _userArgs => _currentUserId != null ? [_currentUserId] : null;

  /// Vymaže všetky lokálne dáta aktuálne prihláseného používateľa. Volaj pred clearCurrentUser() pri odhlásení.
  Future<void> clearCurrentUserData() async {
    final uid = _currentUserId;
    if (uid == null) return;
    final db = await database;
    const tables = [
      'notification_preferences',
      'notification_settings',
      'app_notifications',
      'suppliers',
      'receptura_polozky',
      'recipe_ingredients',
      'recipes',
      'production_orders',
      'transports',
      'warehouse_transfers',
      'stock_movements',
      'stock_out_items',
      'stock_outs',
      'pallets',
      'production_batch_recipe',
      'production_batches',
      'quote_items',
      'quotes',
      'inbound_receipt_items',
      'inbound_receipts',
      'customers',
      'products',
    ];
    for (final table in tables) {
      try {
        await db.delete(table, where: 'user_id = ?', whereArgs: [uid]);
      } catch (_) {}
    }
  }

  /// Premigruje lokálne dáta z jedného identifikátora používateľa na iný (napr. z username "admin" na numerické ID "2").
  /// Používa sa po prvom úspešnom backend logine, aby sa `user_id` v SQLite zhodoval s ID v JWT / Postgres.
  Future<void> migrateUserIdForCurrentUser({
    required String oldUserId,
    required String newUserId,
  }) async {
    if (oldUserId == newUserId) return;
    final db = await database;
    const dataTables = [
      'customers',
      'products',
      'inbound_receipts',
      'quotes',
      'quote_items',
      'production_batches',
      'production_batch_recipe',
      'pallets',
      'stock_outs',
      'stock_out_items',
      'stock_movements',
      'warehouse_transfers',
      'transports',
      'production_orders',
      'recipes',
      'recipe_ingredients',
      'receptura_polozky',
      'suppliers',
      'app_notifications',
      'notification_settings',
      'notification_preferences',
    ];
    for (final table in dataTables) {
      try {
        await db.update(
          table,
          {'user_id': newUserId},
          where: 'user_id = ?',
          whereArgs: [oldUserId],
        );
      } catch (_) {
        // Niektoré tabuľky nemusia existovať na starších schémach – v takom prípade pokračujeme.
      }
    }
  }

  Future<String> getDefaultDatabasePath() async {
    return await getDatabasesPath();
  }

  /// Vráti plnú cestu k súboru databázy.
  Future<String?> getDatabasePath() async {
    String basePath = _customPath ?? await getDatabasesPath();
    return join(basePath, 'stock_pilot.db');
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _dbFuture ??= _initDatabase();
    _database = await _dbFuture;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String basePath = _customPath ?? await getDatabasesPath();
    String path = join(basePath, 'stock_pilot.db');
    print('DATABASE PATH: $path');
    final db = await openDatabase(
      path,
      version: 30,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _ensureSchema(db);
    return db;
  }

  /// Spustí sa pri každom otvorení DB – vytvorí chýbajúce tabuľky a stĺpce.
  Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        unique_id TEXT PRIMARY KEY,
        name TEXT,
        plu TEXT,
        category TEXT,
        qty INTEGER,
        unit TEXT,
        price REAL,
        without_vat REAL,
        vat INTEGER,
        discount INTEGER,
        last_purchase_price REAL,
        last_purchase_price_without_vat REAL DEFAULT 0.0,
        last_purchase_date TEXT,
        currency TEXT,
        location TEXT,
        purchase_price REAL DEFAULT 0.0,
        purchase_price_without_vat REAL DEFAULT 0.0,
        purchase_vat INTEGER DEFAULT 20,
        recycling_fee REAL DEFAULT 0.0,
        product_type TEXT DEFAULT 'Sklad',
        supplier_name TEXT,
        kind_id INTEGER,
        warehouse_id INTEGER,
        min_quantity INTEGER NOT NULL DEFAULT 0,
        allow_at_cash_register INTEGER NOT NULL DEFAULT 1,
        show_in_price_list INTEGER NOT NULL DEFAULT 1,
        is_active INTEGER NOT NULL DEFAULT 1,
        temporarily_unavailable INTEGER NOT NULL DEFAULT 0,
        stock_group TEXT,
        card_type TEXT NOT NULL DEFAULT 'jednoduchá',
        has_extended_pricing INTEGER NOT NULL DEFAULT 0,
        iba_cele_mnozstva INTEGER NOT NULL DEFAULT 0,
        ean TEXT
      )
    ''');
    final productInfoEan = await db.rawQuery('PRAGMA table_info(products)');
    if (!productInfoEan.any((c) => c['name'] == 'ean')) {
      await db.execute('ALTER TABLE products ADD COLUMN ean TEXT');
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password TEXT,
        full_name TEXT,
        role TEXT,
        email TEXT,
        phone TEXT,
        department TEXT,
        avatar_url TEXT,
        join_date TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        ico TEXT NOT NULL,
        email TEXT,
        address TEXT,
        city TEXT,
        postal_code TEXT,
        dic TEXT,
        ic_dph TEXT,
        default_vat_rate INTEGER NOT NULL DEFAULT 20,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        ico TEXT NOT NULL,
        email TEXT,
        address TEXT,
        city TEXT,
        postal_code TEXT,
        dic TEXT,
        ic_dph TEXT,
        default_vat_rate INTEGER NOT NULL DEFAULT 20,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS company (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT NOT NULL DEFAULT '',
        address TEXT,
        city TEXT,
        postal_code TEXT,
        country TEXT,
        ico TEXT,
        ic_dph TEXT,
        vat_payer INTEGER NOT NULL DEFAULT 1,
        phone TEXT,
        email TEXT,
        web TEXT,
        iban TEXT,
        swift TEXT,
        bank_name TEXT,
        account TEXT,
        register_info TEXT,
        logo_path TEXT
      )
    ''');
    await db.rawInsert('INSERT OR IGNORE INTO company (id, name) VALUES (1, ?)', ['Moja firma']);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        warehouse_type TEXT DEFAULT 'Predaj',
        address TEXT,
        city TEXT,
        postal_code TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quote_number TEXT UNIQUE NOT NULL,
        customer_id INTEGER NOT NULL,
        customer_name TEXT,
        created_at TEXT NOT NULL,
        valid_until TEXT,
        notes TEXT,
        prices_include_vat INTEGER NOT NULL DEFAULT 1,
        default_vat_rate INTEGER NOT NULL DEFAULT 20,
        status TEXT NOT NULL DEFAULT 'draft',
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quote_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quote_id INTEGER NOT NULL,
        product_unique_id TEXT NOT NULL,
        product_name TEXT,
        plu TEXT,
        qty INTEGER NOT NULL,
        unit TEXT NOT NULL,
        unit_price REAL NOT NULL,
        discount_percent INTEGER NOT NULL DEFAULT 0,
        vat_percent INTEGER NOT NULL DEFAULT 20,
        FOREIGN KEY (quote_id) REFERENCES quotes(id),
        FOREIGN KEY (product_unique_id) REFERENCES products(unique_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inbound_receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_number TEXT UNIQUE NOT NULL,
        created_at TEXT NOT NULL,
        supplier_name TEXT,
        notes TEXT,
        username TEXT,
        prices_include_vat INTEGER NOT NULL DEFAULT 1,
        vat_applies_to_all INTEGER NOT NULL DEFAULT 0,
        vat_rate INTEGER,
        status TEXT NOT NULL DEFAULT 'vykazana',
        invoice_number TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inbound_receipt_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL,
        product_unique_id TEXT NOT NULL,
        product_name TEXT,
        plu TEXT,
        qty INTEGER NOT NULL,
        unit TEXT NOT NULL,
        unit_price REAL NOT NULL,
        FOREIGN KEY (receipt_id) REFERENCES inbound_receipts(id),
        FOREIGN KEY (product_unique_id) REFERENCES products(unique_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS preferences (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_outs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_number TEXT NOT NULL,
        created_at TEXT NOT NULL,
        recipient_name TEXT,
        notes TEXT,
        username TEXT,
        status TEXT NOT NULL DEFAULT 'vykazana',
        warehouse_id INTEGER,
        je_vysporiadana INTEGER NOT NULL DEFAULT 0,
        vat_rate INTEGER,
        issue_type TEXT NOT NULL DEFAULT 'SALE',
        write_off_reason TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_out_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_out_id INTEGER NOT NULL,
        product_unique_id TEXT NOT NULL,
        product_name TEXT,
        plu TEXT,
        qty INTEGER NOT NULL,
        unit TEXT NOT NULL,
        unit_price REAL NOT NULL,
        FOREIGN KEY (stock_out_id) REFERENCES stock_outs(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movement_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        name TEXT NOT NULL
      )
    ''');
    final mtCountResult = await db.rawQuery('SELECT COUNT(*) as c FROM movement_types');
    if (((mtCountResult.first['c'] as int?) ?? 0) == 0) {
      await db.insert('movement_types', {'code': 'SALE', 'name': 'Bežná výdajka'});
      await db.insert('movement_types', {'code': 'TRAN', 'name': 'Prevodka'});
      await db.insert('movement_types', {'code': 'CONS', 'name': 'Výdaj do spotreby'});
      await db.insert('movement_types', {'code': 'SCRP', 'name': 'Odpis / Likvidácia'});
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_out_id INTEGER NOT NULL,
        document_number TEXT NOT NULL,
        created_at TEXT NOT NULL,
        product_unique_id TEXT NOT NULL,
        product_name TEXT,
        plu TEXT,
        qty INTEGER NOT NULL,
        unit TEXT NOT NULL,
        direction TEXT NOT NULL DEFAULT 'OUT',
        FOREIGN KEY (stock_out_id) REFERENCES stock_outs(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_kinds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouse_transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_warehouse_id INTEGER NOT NULL,
        to_warehouse_id INTEGER NOT NULL,
        product_unique_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        product_plu TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit TEXT NOT NULL,
        created_at TEXT NOT NULL,
        notes TEXT,
        username TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        origin TEXT NOT NULL,
        destination TEXT NOT NULL,
        distance REAL NOT NULL,
        is_round_trip INTEGER NOT NULL DEFAULT 0,
        price_per_km REAL NOT NULL,
        fuel_consumption REAL,
        fuel_price REAL,
        base_cost REAL NOT NULL,
        fuel_cost REAL NOT NULL,
        total_cost REAL NOT NULL,
        created_at TEXT NOT NULL,
        notes TEXT
      )
    ''');

    final productInfo = await db.rawQuery('PRAGMA table_info(products)');
    if (!productInfo.any((c) => c['name'] == 'last_purchase_price_without_vat')) {
      await db.execute('ALTER TABLE products ADD COLUMN last_purchase_price_without_vat REAL DEFAULT 0.0');
    }
    if (!productInfo.any((c) => c['name'] == 'supplier_name')) {
      await db.execute('ALTER TABLE products ADD COLUMN supplier_name TEXT');
    }
    if (!productInfo.any((c) => c['name'] == 'kind_id')) {
      await db.execute('ALTER TABLE products ADD COLUMN kind_id INTEGER');
    }
    if (!productInfo.any((c) => c['name'] == 'warehouse_id')) {
      await db.execute('ALTER TABLE products ADD COLUMN warehouse_id INTEGER');
    }
    if (!productInfo.any((c) => c['name'] == 'linked_product_unique_id')) {
      await db.execute('ALTER TABLE products ADD COLUMN linked_product_unique_id TEXT');
    }
    // Skladová karta (OBERON): min množstvo, pokladnica, cenník, aktívna, nedostupná, skupina, typ karty, rozšírená cenotvorba
    if (!productInfo.any((c) => c['name'] == 'min_quantity')) {
      await db.execute('ALTER TABLE products ADD COLUMN min_quantity INTEGER NOT NULL DEFAULT 0');
    }
    if (!productInfo.any((c) => c['name'] == 'allow_at_cash_register')) {
      await db.execute('ALTER TABLE products ADD COLUMN allow_at_cash_register INTEGER NOT NULL DEFAULT 1');
    }
    if (!productInfo.any((c) => c['name'] == 'show_in_price_list')) {
      await db.execute('ALTER TABLE products ADD COLUMN show_in_price_list INTEGER NOT NULL DEFAULT 1');
    }
    if (!productInfo.any((c) => c['name'] == 'is_active')) {
      await db.execute('ALTER TABLE products ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1');
    }
    if (!productInfo.any((c) => c['name'] == 'temporarily_unavailable')) {
      await db.execute('ALTER TABLE products ADD COLUMN temporarily_unavailable INTEGER NOT NULL DEFAULT 0');
    }
    if (!productInfo.any((c) => c['name'] == 'stock_group')) {
      await db.execute('ALTER TABLE products ADD COLUMN stock_group TEXT');
    }
    if (!productInfo.any((c) => c['name'] == 'card_type')) {
      await db.execute("ALTER TABLE products ADD COLUMN card_type TEXT NOT NULL DEFAULT 'jednoduchá'");
    }
    if (!productInfo.any((c) => c['name'] == 'has_extended_pricing')) {
      await db.execute('ALTER TABLE products ADD COLUMN has_extended_pricing INTEGER NOT NULL DEFAULT 0');
    }
    if (!productInfo.any((c) => c['name'] == 'iba_cele_mnozstva')) {
      await db.execute('ALTER TABLE products ADD COLUMN iba_cele_mnozstva INTEGER NOT NULL DEFAULT 0');
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS production_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        production_date TEXT NOT NULL,
        product_type TEXT NOT NULL,
        quantity_produced INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT,
        cost_total REAL,
        revenue_total REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS production_batch_recipe (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        material_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL DEFAULT 'kg',
        FOREIGN KEY (batch_id) REFERENCES production_batches(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        product_type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        customer_id INTEGER,
        status TEXT NOT NULL DEFAULT 'Na sklade',
        created_at TEXT,
        FOREIGN KEY (batch_id) REFERENCES production_batches(id),
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');
    final custInfo = await db.rawQuery('PRAGMA table_info(customers)');
    if (!custInfo.any((c) => c['name'] == 'pallet_balance')) {
      await db.execute('ALTER TABLE customers ADD COLUMN pallet_balance INTEGER NOT NULL DEFAULT 0');
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS receptura_polozky (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receptura_karta_id TEXT NOT NULL,
        id_suroviny TEXT NOT NULL,
        mnozstvo REAL NOT NULL,
        FOREIGN KEY (receptura_karta_id) REFERENCES products(unique_id),
        FOREIGN KEY (id_suroviny) REFERENCES products(unique_id)
      )
    ''');
    final whInfo = await db.rawQuery('PRAGMA table_info(warehouses)');
    if (!whInfo.any((c) => c['name'] == 'warehouse_type')) {
      await db.execute("ALTER TABLE warehouses ADD COLUMN warehouse_type TEXT DEFAULT 'Predaj'");
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        finished_product_unique_id TEXT NOT NULL,
        finished_product_name TEXT,
        output_quantity REAL NOT NULL DEFAULT 1,
        unit TEXT NOT NULL DEFAULT 'ks',
        production_warehouse_id INTEGER,
        output_warehouse_id INTEGER,
        production_time_minutes INTEGER,
        note TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        min_approval_quantity REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (production_warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY (output_warehouse_id) REFERENCES warehouses(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        product_unique_id TEXT NOT NULL,
        product_name TEXT,
        plu TEXT,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL DEFAULT 'ks',
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
        FOREIGN KEY (product_unique_id) REFERENCES products(unique_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS production_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT UNIQUE NOT NULL,
        recipe_id INTEGER NOT NULL,
        recipe_name TEXT,
        planned_quantity REAL NOT NULL,
        production_date TEXT NOT NULL,
        source_warehouse_id INTEGER,
        destination_warehouse_id INTEGER,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        requires_approval INTEGER NOT NULL DEFAULT 0,
        created_by_username TEXT,
        created_at TEXT,
        submitted_at TEXT,
        approver_username TEXT,
        approved_at TEXT,
        rejection_reason TEXT,
        rejected_at TEXT,
        started_at TEXT,
        completed_at TEXT,
        completed_by_username TEXT,
        actual_quantity REAL,
        variance REAL,
        material_cost REAL,
        labor_cost REAL,
        energy_cost REAL,
        overhead_cost REAL,
        other_cost REAL,
        total_cost REAL,
        cost_per_unit REAL,
        raw_materials_stock_out_id INTEGER,
        finished_goods_receipt_id INTEGER,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id),
        FOREIGN KEY (source_warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY (destination_warehouse_id) REFERENCES warehouses(id)
      )
    ''');
  }

  Future<void> initializeWithAdmin(User admin) async {
    String basePath = _customPath ?? await getDatabasesPath();
    String path = join(basePath, 'stock_pilot.db');

    if (_database != null) {
      await _database!.close();
      _database = null;
      _dbFuture = null;
    }

    try {
      if (await File(path).exists()) {
        await File(path).delete();
      }
    } catch (e) {
      print(
        "Warning: Could not delete old DB file (maybe locked), clearing tables instead: $e",
      );
    }

    Database db = await database;
    await db.delete('users');
    await db.insert(
      'users',
      admin.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE,
          password TEXT,
          full_name TEXT,
          role TEXT,
          email TEXT,
          phone TEXT,
          department TEXT,
          avatar_url TEXT,
          join_date TEXT
        )
      ''');
    }

    if (oldVersion < 4) {
      var tableInfo = await db.rawQuery('PRAGMA table_info(users)');
      bool hasPassword = tableInfo.any(
        (column) => column['name'] == 'password',
      );
      if (!hasPassword) {
        await db.execute('ALTER TABLE users ADD COLUMN password TEXT');
        await db.update('users', {'password': 'password123'});
      }
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS inbound_receipts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          receipt_number TEXT UNIQUE NOT NULL,
          created_at TEXT NOT NULL,
          supplier_name TEXT,
          notes TEXT,
          username TEXT,
          prices_include_vat INTEGER NOT NULL DEFAULT 1,
          vat_applies_to_all INTEGER NOT NULL DEFAULT 0,
          vat_rate INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS inbound_receipt_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          receipt_id INTEGER NOT NULL,
          product_unique_id TEXT NOT NULL,
          product_name TEXT,
          plu TEXT,
          qty INTEGER NOT NULL,
          unit TEXT NOT NULL,
          unit_price REAL NOT NULL,
          FOREIGN KEY (receipt_id) REFERENCES inbound_receipts(id),
          FOREIGN KEY (product_unique_id) REFERENCES products(unique_id)
        )
      ''');
    }

    if (oldVersion < 6) {
      final tableInfo = await db.rawQuery(
        'PRAGMA table_info(inbound_receipts)',
      );
      final hasStatus = tableInfo.any((c) => c['name'] == 'status');
      if (!hasStatus) {
        await db.execute(
          "ALTER TABLE inbound_receipts ADD COLUMN status TEXT NOT NULL DEFAULT 'vykazana'",
        );
      }
    }

    if (oldVersion < 7) {
      final tableInfo = await db.rawQuery(
        'PRAGMA table_info(inbound_receipts)',
      );
      final hasInvoice = tableInfo.any((c) => c['name'] == 'invoice_number');
      if (!hasInvoice) {
        await db.execute(
          "ALTER TABLE inbound_receipts ADD COLUMN invoice_number TEXT",
        );
      }
    }

    if (oldVersion < 8) {
      final tableInfo = await db.rawQuery('PRAGMA table_info(products)');
      final hasPurchasePrice = tableInfo.any(
        (c) => c['name'] == 'purchase_price',
      );
      if (!hasPurchasePrice) {
        await db.execute(
          "ALTER TABLE products ADD COLUMN purchase_price REAL DEFAULT 0.0",
        );
      }
      final hasRecyclingFee = tableInfo.any(
        (c) => c['name'] == 'recycling_fee',
      );
      if (!hasRecyclingFee) {
        await db.execute(
          "ALTER TABLE products ADD COLUMN recycling_fee REAL DEFAULT 0.0",
        );
      }
      final hasProductType = tableInfo.any((c) => c['name'] == 'product_type');
      if (!hasProductType) {
        await db.execute(
          "ALTER TABLE products ADD COLUMN product_type TEXT DEFAULT 'Sklad'",
        );
      }
    }

    if (oldVersion < 9) {
      final tableInfo = await db.rawQuery('PRAGMA table_info(products)');
      final hasPpwv = tableInfo.any(
        (c) => c['name'] == 'purchase_price_without_vat',
      );
      if (!hasPpwv) {
        await db.execute(
          "ALTER TABLE products ADD COLUMN purchase_price_without_vat REAL DEFAULT 0.0",
        );
      }
      final hasPv = tableInfo.any((c) => c['name'] == 'purchase_vat');
      if (!hasPv) {
        await db.execute(
          "ALTER TABLE products ADD COLUMN purchase_vat INTEGER DEFAULT 20",
        );
      }
    }

    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS suppliers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          ico TEXT NOT NULL,
          email TEXT,
          address TEXT,
          city TEXT,
          postal_code TEXT,
          dic TEXT,
          ic_dph TEXT,
          default_vat_rate INTEGER NOT NULL DEFAULT 20
        )
      ''');
    }

    if (oldVersion < 11) {
      final info = await db.rawQuery('PRAGMA table_info(suppliers)');
      if (!info.any((c) => c['name'] == 'is_active')) {
        await db.execute(
          "ALTER TABLE suppliers ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1",
        );
      }
    }

    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          ico TEXT NOT NULL,
          email TEXT,
          address TEXT,
          city TEXT,
          postal_code TEXT,
          dic TEXT,
          ic_dph TEXT,
          default_vat_rate INTEGER NOT NULL DEFAULT 20,
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }

    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quotes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          quote_number TEXT UNIQUE NOT NULL,
          customer_id INTEGER NOT NULL,
          customer_name TEXT,
          created_at TEXT NOT NULL,
          valid_until TEXT,
          notes TEXT,
          prices_include_vat INTEGER NOT NULL DEFAULT 1,
          default_vat_rate INTEGER NOT NULL DEFAULT 20,
          status TEXT NOT NULL DEFAULT 'draft',
          FOREIGN KEY (customer_id) REFERENCES customers(id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quote_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          quote_id INTEGER NOT NULL,
          product_unique_id TEXT NOT NULL,
          product_name TEXT,
          plu TEXT,
          qty INTEGER NOT NULL,
          unit TEXT NOT NULL,
          unit_price REAL NOT NULL,
          discount_percent INTEGER NOT NULL DEFAULT 0,
          vat_percent INTEGER NOT NULL DEFAULT 20,
          FOREIGN KEY (quote_id) REFERENCES quotes(id),
          FOREIGN KEY (product_unique_id) REFERENCES products(unique_id)
        )
      ''');
    }

    if (oldVersion < 14) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS company (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          name TEXT NOT NULL DEFAULT '',
          address TEXT,
          city TEXT,
          postal_code TEXT,
          country TEXT,
          ico TEXT,
          ic_dph TEXT,
          vat_payer INTEGER NOT NULL DEFAULT 1,
          phone TEXT,
          email TEXT,
          web TEXT,
          iban TEXT,
          swift TEXT,
          bank_name TEXT,
          account TEXT,
          register_info TEXT
        )
      ''');
      await db.rawInsert(
        'INSERT OR IGNORE INTO company (id, name) VALUES (1, ?)',
        ['Moja firma'],
      );
    }

    if (oldVersion < 15) {
      final info = await db.rawQuery('PRAGMA table_info(company)');
      if (!info.any((c) => c['name'] == 'logo_path')) {
        await db.execute('ALTER TABLE company ADD COLUMN logo_path TEXT');
      }
    }

    if (oldVersion < 16) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS warehouses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          code TEXT NOT NULL UNIQUE,
          address TEXT,
          city TEXT,
          postal_code TEXT,
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 17) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS preferences (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_outs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_number TEXT NOT NULL,
          created_at TEXT NOT NULL,
          recipient_name TEXT,
          notes TEXT,
          username TEXT,
          status TEXT NOT NULL DEFAULT 'vykazana',
          vat_rate INTEGER,
          issue_type TEXT NOT NULL DEFAULT 'SALE',
          write_off_reason TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_out_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          stock_out_id INTEGER NOT NULL,
          product_unique_id TEXT NOT NULL,
          product_name TEXT,
          plu TEXT,
          qty INTEGER NOT NULL,
          unit TEXT NOT NULL,
          unit_price REAL NOT NULL,
          FOREIGN KEY (stock_out_id) REFERENCES stock_outs(id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS product_kinds (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS warehouse_transfers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          from_warehouse_id INTEGER NOT NULL,
          to_warehouse_id INTEGER NOT NULL,
          product_unique_id TEXT NOT NULL,
          product_name TEXT NOT NULL,
          product_plu TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit TEXT NOT NULL,
          created_at TEXT NOT NULL,
          notes TEXT,
          username TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          origin TEXT NOT NULL,
          destination TEXT NOT NULL,
          distance REAL NOT NULL,
          is_round_trip INTEGER NOT NULL DEFAULT 0,
          price_per_km REAL NOT NULL,
          fuel_consumption REAL,
          fuel_price REAL,
          base_cost REAL NOT NULL,
          fuel_cost REAL NOT NULL,
          total_cost REAL NOT NULL,
          created_at TEXT NOT NULL,
          notes TEXT
        )
      ''');
      final productInfo = await db.rawQuery('PRAGMA table_info(products)');
      if (!productInfo.any((c) => c['name'] == 'supplier_name')) {
        await db.execute('ALTER TABLE products ADD COLUMN supplier_name TEXT');
      }
      if (!productInfo.any((c) => c['name'] == 'kind_id')) {
        await db.execute('ALTER TABLE products ADD COLUMN kind_id INTEGER');
      }
      if (!productInfo.any((c) => c['name'] == 'warehouse_id')) {
        await db.execute('ALTER TABLE products ADD COLUMN warehouse_id INTEGER');
      }
      final whInfo = await db.rawQuery('PRAGMA table_info(warehouses)');
      if (!whInfo.any((c) => c['name'] == 'warehouse_type')) {
        await db.execute("ALTER TABLE warehouses ADD COLUMN warehouse_type TEXT DEFAULT 'Predaj'");
      }
    }
    if (oldVersion < 18) {
      final productInfo = await db.rawQuery('PRAGMA table_info(products)');
      if (!productInfo.any((c) => c['name'] == 'last_purchase_price_without_vat')) {
        await db.execute('ALTER TABLE products ADD COLUMN last_purchase_price_without_vat REAL DEFAULT 0.0');
      }
    }
    if (oldVersion < 19) {
      final itemInfo = await db.rawQuery('PRAGMA table_info(inbound_receipt_items)');
      if (!itemInfo.any((c) => c['name'] == 'vat_percent')) {
        await db.execute('ALTER TABLE inbound_receipt_items ADD COLUMN vat_percent INTEGER');
      }
    }
    if (oldVersion < 20) {
      final soInfo = await db.rawQuery('PRAGMA table_info(stock_outs)');
      if (!soInfo.any((c) => c['name'] == 'warehouse_id')) {
        await db.execute('ALTER TABLE stock_outs ADD COLUMN warehouse_id INTEGER');
      }
      if (!soInfo.any((c) => c['name'] == 'je_vysporiadana')) {
        await db.execute('ALTER TABLE stock_outs ADD COLUMN je_vysporiadana INTEGER NOT NULL DEFAULT 0');
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS movement_types (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT NOT NULL,
          name TEXT NOT NULL
        )
      ''');
      final mtCount = await db.rawQuery('SELECT COUNT(*) as c FROM movement_types');
      if (((mtCount.first['c'] as int?) ?? 0) == 0) {
        await db.insert('movement_types', {'code': 'SALE', 'name': 'Bežná výdajka'});
        await db.insert('movement_types', {'code': 'TRAN', 'name': 'Prevodka'});
        await db.insert('movement_types', {'code': 'CONS', 'name': 'Výdaj do spotreby'});
        await db.insert('movement_types', {'code': 'SCRP', 'name': 'Odpis / Likvidácia'});
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_movements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          stock_out_id INTEGER NOT NULL,
          document_number TEXT NOT NULL,
          created_at TEXT NOT NULL,
          product_unique_id TEXT NOT NULL,
          product_name TEXT,
          plu TEXT,
          qty INTEGER NOT NULL,
          unit TEXT NOT NULL,
          direction TEXT NOT NULL DEFAULT 'OUT',
          FOREIGN KEY (stock_out_id) REFERENCES stock_outs(id)
        )
      ''');
      final pInfo = await db.rawQuery('PRAGMA table_info(products)');
      if (!pInfo.any((c) => c['name'] == 'linked_product_unique_id')) {
        await db.execute('ALTER TABLE products ADD COLUMN linked_product_unique_id TEXT');
      }
    }
    if (oldVersion < 21) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS receipt_movement_types (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT NOT NULL,
          name TEXT NOT NULL
        )
      ''');
      final rmtCount = await db.rawQuery('SELECT COUNT(*) as c FROM receipt_movement_types');
      if (((rmtCount.first['c'] as int?) ?? 0) == 0) {
        await db.insert('receipt_movement_types', {'code': 'STANDARD', 'name': 'Bežná príjemka'});
        await db.insert('receipt_movement_types', {'code': 'TRANSFER', 'name': 'Prevodka'});
        await db.insert('receipt_movement_types', {'code': 'WITH_COSTS', 'name': 'Príjemka s obstarávacími nákladmi'});
      }
      final irInfo = await db.rawQuery('PRAGMA table_info(inbound_receipts)');
      if (!irInfo.any((c) => c['name'] == 'warehouse_id')) {
        await db.execute('ALTER TABLE inbound_receipts ADD COLUMN warehouse_id INTEGER');
      }
      if (!irInfo.any((c) => c['name'] == 'movement_type_code')) {
        await db.execute("ALTER TABLE inbound_receipts ADD COLUMN movement_type_code TEXT NOT NULL DEFAULT 'STANDARD'");
      }
      if (!irInfo.any((c) => c['name'] == 'je_vysporiadana')) {
        await db.execute('ALTER TABLE inbound_receipts ADD COLUMN je_vysporiadana INTEGER NOT NULL DEFAULT 0');
      }
    }
    if (oldVersion < 22) {
      final pInfo = await db.rawQuery('PRAGMA table_info(products)');
      if (!pInfo.any((c) => c['name'] == 'ean')) {
        await db.execute('ALTER TABLE products ADD COLUMN ean TEXT');
      }
    }
    if (oldVersion < 23) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS production_batches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          production_date TEXT NOT NULL,
          product_type TEXT NOT NULL,
          quantity_produced INTEGER NOT NULL DEFAULT 0,
          notes TEXT,
          created_at TEXT,
          cost_total REAL,
          revenue_total REAL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS production_batch_recipe (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          batch_id INTEGER NOT NULL,
          material_name TEXT NOT NULL,
          quantity REAL NOT NULL,
          unit TEXT NOT NULL DEFAULT 'kg',
          FOREIGN KEY (batch_id) REFERENCES production_batches(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 24) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pallets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          batch_id INTEGER NOT NULL,
          product_type TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          customer_id INTEGER,
          status TEXT NOT NULL DEFAULT 'Na sklade',
          created_at TEXT,
          FOREIGN KEY (batch_id) REFERENCES production_batches(id),
          FOREIGN KEY (customer_id) REFERENCES customers(id)
        )
      ''');
      final custInfo = await db.rawQuery('PRAGMA table_info(customers)');
      if (!custInfo.any((c) => c['name'] == 'pallet_balance')) {
        await db.execute('ALTER TABLE customers ADD COLUMN pallet_balance INTEGER NOT NULL DEFAULT 0');
      }
    }
    if (oldVersion < 25) {
      final irInfo = await db.rawQuery('PRAGMA table_info(inbound_receipts)');
      if (!irInfo.any((c) => c['name'] == 'source_warehouse_id')) {
        await db.execute('ALTER TABLE inbound_receipts ADD COLUMN source_warehouse_id INTEGER');
      }
      if (!irInfo.any((c) => c['name'] == 'linked_stock_out_id')) {
        await db.execute('ALTER TABLE inbound_receipts ADD COLUMN linked_stock_out_id INTEGER');
      }
      final soInfo = await db.rawQuery('PRAGMA table_info(stock_outs)');
      if (!soInfo.any((c) => c['name'] == 'linked_receipt_id')) {
        await db.execute('ALTER TABLE stock_outs ADD COLUMN linked_receipt_id INTEGER');
      }
    }
    if (oldVersion < 26) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS receipt_acquisition_costs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          receipt_id INTEGER NOT NULL,
          cost_type TEXT NOT NULL,
          description TEXT,
          amount_without_vat REAL NOT NULL DEFAULT 0,
          vat_percent INTEGER NOT NULL DEFAULT 0,
          amount_with_vat REAL NOT NULL DEFAULT 0,
          cost_supplier_name TEXT,
          document_number TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (receipt_id) REFERENCES inbound_receipts(id)
        )
      ''');
      final iiInfo = await db.rawQuery('PRAGMA table_info(inbound_receipt_items)');
      if (!iiInfo.any((c) => c['name'] == 'allocated_cost')) {
        await db.execute('ALTER TABLE inbound_receipt_items ADD COLUMN allocated_cost REAL NOT NULL DEFAULT 0');
      }
      final irInfo = await db.rawQuery('PRAGMA table_info(inbound_receipts)');
      if (!irInfo.any((c) => c['name'] == 'cost_distribution_method')) {
        await db.execute('ALTER TABLE inbound_receipts ADD COLUMN cost_distribution_method TEXT');
      }
    }
    if (oldVersion < 27) {
      final irInfo = await db.rawQuery('PRAGMA table_info(inbound_receipts)');
      final cols = ['submitted_at', 'approved_at', 'approver_username', 'approver_note', 'rejected_at', 'rejection_reason', 'reversed_at', 'reversed_by_username', 'reverse_reason'];
      for (final col in cols) {
        if (!irInfo.any((c) => c['name'] == col)) {
          final sql = col == 'submitted_at' || col == 'approved_at' || col == 'rejected_at' || col == 'reversed_at'
              ? 'ALTER TABLE inbound_receipts ADD COLUMN $col TEXT'
              : 'ALTER TABLE inbound_receipts ADD COLUMN $col TEXT';
          await db.execute(sql);
        }
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_notifications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          receipt_id INTEGER,
          receipt_number TEXT,
          extra_data TEXT,
          created_at TEXT NOT NULL,
          read INTEGER NOT NULL DEFAULT 0,
          target_username TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notification_settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          notification_type TEXT NOT NULL,
          push_enabled INTEGER NOT NULL DEFAULT 1,
          email_enabled INTEGER NOT NULL DEFAULT 0,
          UNIQUE(username, notification_type)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notification_preferences (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE NOT NULL,
          quiet_hours_start TEXT,
          quiet_hours_end TEXT,
          pending_reminder_hours INTEGER NOT NULL DEFAULT 24,
          price_change_threshold_percent REAL NOT NULL DEFAULT 20.0
        )
      ''');
    }
    if (oldVersion < 28) {
      final irInfo = await db.rawQuery('PRAGMA table_info(inbound_receipts)');
      if (!irInfo.any((c) => c['name'] == 'stock_applied')) {
        await db.execute('ALTER TABLE inbound_receipts ADD COLUMN stock_applied INTEGER NOT NULL DEFAULT 0');
      }
    }

    // Version 30: per-user data isolation – add user_id to all data tables
    if (oldVersion < 30) {
      const dataTables = [
        'customers',
        'products',
        'inbound_receipts',
        'quotes',
        'quote_items',
        'production_batches',
        'production_batch_recipe',
        'pallets',
        'stock_outs',
        'stock_out_items',
        'stock_movements',
        'warehouse_transfers',
        'transports',
        'production_orders',
        'recipes',
        'recipe_ingredients',
        'receptura_polozky',
        'suppliers',
        'app_notifications',
        'notification_settings',
        'notification_preferences',
      ];
      for (final table in dataTables) {
        try {
          final info = await db.rawQuery('PRAGMA table_info($table)');
          if (!info.any((c) => c['name'] == 'user_id')) {
            await db.execute('ALTER TABLE $table ADD COLUMN user_id TEXT');
            await db.execute(
              'UPDATE $table SET user_id = (SELECT username FROM users LIMIT 1) WHERE user_id IS NULL',
            );
          }
        } catch (e) {
          // Table might not exist in older DBs
        }
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        unique_id TEXT PRIMARY KEY,
        name TEXT,
        plu TEXT,
        category TEXT,
        qty INTEGER,
        unit TEXT,
        price REAL,
        without_vat REAL,
        vat INTEGER,
        discount INTEGER,
        last_purchase_price REAL,
        last_purchase_price_without_vat REAL DEFAULT 0.0,
        last_purchase_date TEXT,
        currency TEXT,
        location TEXT,
        purchase_price REAL DEFAULT 0.0,
        purchase_price_without_vat REAL DEFAULT 0.0,
        purchase_vat INTEGER DEFAULT 20,
        recycling_fee REAL DEFAULT 0.0,
        product_type TEXT DEFAULT 'Sklad',
        supplier_name TEXT,
        kind_id INTEGER,
        warehouse_id INTEGER,
        min_quantity INTEGER NOT NULL DEFAULT 0,
        allow_at_cash_register INTEGER NOT NULL DEFAULT 1,
        show_in_price_list INTEGER NOT NULL DEFAULT 1,
        is_active INTEGER NOT NULL DEFAULT 1,
        temporarily_unavailable INTEGER NOT NULL DEFAULT 0,
        stock_group TEXT,
        card_type TEXT NOT NULL DEFAULT 'jednoduchá',
        has_extended_pricing INTEGER NOT NULL DEFAULT 0,
        iba_cele_mnozstva INTEGER NOT NULL DEFAULT 0,
        ean TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password TEXT,
        full_name TEXT,
        role TEXT,
        email TEXT,
        phone TEXT,
        department TEXT,
        avatar_url TEXT,
        join_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        ico TEXT NOT NULL,
        email TEXT,
        address TEXT,
        city TEXT,
        postal_code TEXT,
        dic TEXT,
        ic_dph TEXT,
        default_vat_rate INTEGER NOT NULL DEFAULT 20,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        ico TEXT NOT NULL,
        email TEXT,
        address TEXT,
        city TEXT,
        postal_code TEXT,
        dic TEXT,
        ic_dph TEXT,
        default_vat_rate INTEGER NOT NULL DEFAULT 20,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS quotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quote_number TEXT UNIQUE NOT NULL,
        customer_id INTEGER NOT NULL,
        customer_name TEXT,
        created_at TEXT NOT NULL,
        valid_until TEXT,
        notes TEXT,
        prices_include_vat INTEGER NOT NULL DEFAULT 1,
        default_vat_rate INTEGER NOT NULL DEFAULT 20,
        status TEXT NOT NULL DEFAULT 'draft',
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quote_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quote_id INTEGER NOT NULL,
        product_unique_id TEXT NOT NULL,
        product_name TEXT,
        plu TEXT,
        qty INTEGER NOT NULL,
        unit TEXT NOT NULL,
        unit_price REAL NOT NULL,
        discount_percent INTEGER NOT NULL DEFAULT 0,
        vat_percent INTEGER NOT NULL DEFAULT 20,
        FOREIGN KEY (quote_id) REFERENCES quotes(id),
        FOREIGN KEY (product_unique_id) REFERENCES products(unique_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS company (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT NOT NULL DEFAULT '',
        address TEXT,
        city TEXT,
        postal_code TEXT,
        country TEXT,
        ico TEXT,
        ic_dph TEXT,
        vat_payer INTEGER NOT NULL DEFAULT 1,
        phone TEXT,
        email TEXT,
        web TEXT,
        iban TEXT,
        swift TEXT,
        bank_name TEXT,
        account TEXT,
        register_info TEXT,
        logo_path TEXT
      )
    ''');
    await db.rawInsert(
      'INSERT OR IGNORE INTO company (id, name) VALUES (1, ?)',
      ['Moja firma'],
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        address TEXT,
        city TEXT,
        postal_code TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS receipt_movement_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        name TEXT NOT NULL
      )
    ''');
    await db.insert('receipt_movement_types', {'code': 'STANDARD', 'name': 'Bežná príjemka'});
    await db.insert('receipt_movement_types', {'code': 'TRANSFER', 'name': 'Prevodka'});
    await db.insert('receipt_movement_types', {'code': 'WITH_COSTS', 'name': 'Príjemka s obstarávacími nákladmi'});
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inbound_receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_number TEXT UNIQUE NOT NULL,
        created_at TEXT NOT NULL,
        supplier_name TEXT,
        notes TEXT,
        username TEXT,
        prices_include_vat INTEGER NOT NULL DEFAULT 1,
        vat_applies_to_all INTEGER NOT NULL DEFAULT 0,
        vat_rate INTEGER,
        status TEXT NOT NULL DEFAULT 'vykazana',
        invoice_number TEXT,
        warehouse_id INTEGER,
        movement_type_code TEXT NOT NULL DEFAULT 'STANDARD',
        je_vysporiadana INTEGER NOT NULL DEFAULT 0,
        cost_distribution_method TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inbound_receipt_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL,
        product_unique_id TEXT NOT NULL,
        product_name TEXT,
        plu TEXT,
        qty INTEGER NOT NULL,
        unit TEXT NOT NULL,
        unit_price REAL NOT NULL,
        vat_percent INTEGER,
        allocated_cost REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (receipt_id) REFERENCES inbound_receipts(id),
        FOREIGN KEY (product_unique_id) REFERENCES products(unique_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS receipt_acquisition_costs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL,
        cost_type TEXT NOT NULL,
        description TEXT,
        amount_without_vat REAL NOT NULL DEFAULT 0,
        vat_percent INTEGER NOT NULL DEFAULT 0,
        amount_with_vat REAL NOT NULL DEFAULT 0,
        cost_supplier_name TEXT,
        document_number TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (receipt_id) REFERENCES inbound_receipts(id)
      )
    ''');

  }

  // User Operations
  Future<User?> getUserByUsername(String username) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  /// Vráti prvého používateľa s rolou admin (pre overenie pri vytváraní nového používateľa).
  Future<User?> getFirstAdminUser() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['admin'],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUser(User user) async {
    Database db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  /// Vráti true, ak v databáze existuje aspoň jeden používateľ.
  Future<bool> hasAnyUsers() async {
    Database db = await database;
    final result = await db.rawQuery('SELECT 1 FROM users LIMIT 1');
    return result.isNotEmpty;
  }

  /// Vloží nového používateľa (pre vytvorenie prvého používateľa bez vymazania DB).
  Future<int> insertUser(User user) async {
    Database db = await database;
    return await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // CRUD Operations for Products
  Future<int> insertProduct(Product product) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(product.toMap());
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('products', map);
  }

  Future<List<Product>> getProducts() async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final List<Map<String, dynamic>> maps = await db.query('products', where: _userWhere, whereArgs: _userArgs);
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<Product?> getProductByUniqueId(String uniqueId) async {
    Database db = await database;
    if (_currentUserId == null) return null;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'unique_id = ? AND user_id = ?',
      whereArgs: [uniqueId, _currentUserId],
    );
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  /// Vyhľadá produkt podľa EAN kódu (čiarový kód).
  Future<Product?> getProductByEan(String ean) async {
    if (ean.isEmpty || _currentUserId == null) return null;
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'ean = ? AND user_id = ?',
      whereArgs: [ean.trim(), _currentUserId],
    );
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  /// Vyhľadá produkt podľa naskenovaného kódu: najprv EAN, potom PLU.
  Future<Product?> getProductByBarcode(String code) async {
    if (code.isEmpty) return null;
    final trimmed = code.trim();
    Product? p = await getProductByEan(trimmed);
    if (p != null) return p;
    final all = await getProducts();
    final byPlu = all.where((p) => p.plu.trim() == trimmed).toList();
    return byPlu.isEmpty ? null : byPlu.first;
  }

  Future<int> updateProduct(Product product) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    return await db.update(
      'products',
      product.toMap(),
      where: 'unique_id = ? AND user_id = ?',
      whereArgs: [product.uniqueId, _currentUserId],
    );
  }

  Future<int> deleteProduct(String id) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    return await db.delete('products', where: 'unique_id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
  }

  /// Aktualizuje EAN lokálnych produktov podľa zoznamu z backendu (EAN priradené na webe).
  /// Vráti počet skutočne aktualizovaných produktov.
  Future<int> updateProductEanFromBackend(List<Map<String, dynamic>> backendProducts) async {
    int count = 0;
    for (final map in backendProducts) {
      final uniqueId = map['unique_id'] as String?;
      if (uniqueId == null || uniqueId.isEmpty) continue;
      final eanRaw = map['ean'];
      final ean = eanRaw is String ? eanRaw.trim() : null;
      if (ean == null || ean.isEmpty) continue;
      final product = await getProductByUniqueId(uniqueId);
      if (product == null || product.ean == ean) continue;
      await updateProduct(product.copyWith(ean: ean));
      count++;
    }
    return count;
  }

  // Receptúra – zložky (suroviny) receptúry
  Future<List<RecepturaPolozka>> getRecepturaPolozky(String recepturaKartaId) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query(
      'receptura_polozky',
      where: 'receptura_karta_id = ? AND user_id = ?',
      whereArgs: [recepturaKartaId, _currentUserId],
    );
    return maps.map((m) => RecepturaPolozka.fromMap(m)).toList();
  }

  Future<int> insertRecepturaPolozka(RecepturaPolozka polozka, String recepturaKartaId) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(polozka.toMap(recepturaKartaId: recepturaKartaId));
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('receptura_polozky', map);
  }

  Future<int> deleteRecepturaPolozkyByRecepturaKartaId(String recepturaKartaId) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    return await db.delete(
      'receptura_polozky',
      where: 'receptura_karta_id = ? AND user_id = ?',
      whereArgs: [recepturaKartaId, _currentUserId],
    );
  }

  // Recipes (Receptúry)
  Future<int> insertRecipe(Recipe recipe) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(recipe.toMap());
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('recipes', map);
  }

  Future<int> updateRecipe(Recipe recipe) async {
    if (recipe.id == null || _currentUserId == null) return 0;
    Database db = await database;
    return await db.update('recipes', recipe.toMap(), where: 'id = ? AND user_id = ?', whereArgs: [recipe.id, _currentUserId]);
  }

  Future<List<Recipe>> getRecipes({bool? activeOnly, String? search}) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final conditions = <String>['user_id = ?'];
    final args = <Object?>[_currentUserId];
    if (activeOnly == true) {
      conditions.add('is_active = 1');
    }
    if (search != null && search.trim().isNotEmpty) {
      final term = '%${search.trim()}%';
      conditions.add('(name LIKE ? OR finished_product_name LIKE ?)');
      args.addAll([term, term]);
    }
    final maps = await db.query('recipes', where: conditions.join(' AND '), whereArgs: args, orderBy: 'name ASC');
    return maps.map((m) => Recipe.fromMap(m)).toList();
  }

  Future<Recipe?> getRecipeById(int id) async {
    Database db = await database;
    if (_currentUserId == null) return null;
    final maps = await db.query('recipes', where: 'id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
    if (maps.isEmpty) return null;
    return Recipe.fromMap(maps.first);
  }

  Future<int> deleteRecipe(int id) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    await db.delete('recipe_ingredients', where: 'recipe_id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
    return await db.delete('recipes', where: 'id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
  }

  Future<List<RecipeIngredient>> getRecipeIngredients(int recipeId) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query('recipe_ingredients', where: 'recipe_id = ? AND user_id = ?', whereArgs: [recipeId, _currentUserId], orderBy: 'id ASC');
    return maps.map((m) => RecipeIngredient.fromMap(m)).toList();
  }

  Future<int> insertRecipeIngredient(RecipeIngredient ing) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(ing.toMap());
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('recipe_ingredients', map);
  }

  Future<void> deleteRecipeIngredientsByRecipeId(int recipeId) async {
    Database db = await database;
    if (_currentUserId == null) return;
    await db.delete('recipe_ingredients', where: 'recipe_id = ? AND user_id = ?', whereArgs: [recipeId, _currentUserId]);
  }

  Future<String> getNextProductionOrderNumber() async {
    Database db = await database;
    if (_currentUserId == null) return 'VP-${DateTime.now().year}-0001';
    final year = DateTime.now().year;
    final maps = await db.rawQuery(
      "SELECT order_number FROM production_orders WHERE user_id = ? AND order_number LIKE 'VP-$year-%' ORDER BY id DESC LIMIT 1",
      [_currentUserId],
    );
    if (maps.isEmpty) return 'VP-$year-0001';
    final last = maps.first['order_number'] as String? ?? '';
    final parts = last.split('-');
    if (parts.length < 3) return 'VP-$year-0001';
    final num = int.tryParse(parts[2]) ?? 0;
    return 'VP-$year-${(num + 1).toString().padLeft(4, '0')}';
  }

  Future<int> insertProductionOrder(ProductionOrder order) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(order.toMap());
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('production_orders', map);
  }

  Future<int> updateProductionOrder(ProductionOrder order) async {
    if (order.id == null || _currentUserId == null) return 0;
    Database db = await database;
    return await db.update('production_orders', order.toMap(), where: 'id = ? AND user_id = ?', whereArgs: [order.id, _currentUserId]);
  }

  Future<List<ProductionOrder>> getProductionOrders({
    int? recipeId,
    String? status,
    int? warehouseId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? createdBy,
  }) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final conditions = <String>['user_id = ?'];
    final args = <Object?>[_currentUserId];
    if (recipeId != null) {
      conditions.add('recipe_id = ?');
      args.add(recipeId);
    }
    if (status != null && status.isNotEmpty) {
      conditions.add('status = ?');
      args.add(status);
    }
    if (warehouseId != null) {
      conditions.add('(source_warehouse_id = ? OR destination_warehouse_id = ?)');
      args.add(warehouseId);
      args.add(warehouseId);
    }
    if (dateFrom != null) {
      conditions.add('production_date >= ?');
      args.add(dateFrom.toIso8601String().split('T').first);
    }
    if (dateTo != null) {
      conditions.add('production_date <= ?');
      args.add(dateTo.toIso8601String().split('T').first);
    }
    if (createdBy != null && createdBy.isNotEmpty) {
      conditions.add('created_by_username = ?');
      args.add(createdBy);
    }
    final where = conditions.join(' AND ');
    final maps = await db.query('production_orders', where: where, whereArgs: args, orderBy: 'production_date DESC, id DESC');
    return maps.map((m) => ProductionOrder.fromMap(m)).toList();
  }

  Future<ProductionOrder?> getProductionOrderById(int id) async {
    Database db = await database;
    if (_currentUserId == null) return null;
    final maps = await db.query('production_orders', where: 'id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
    if (maps.isEmpty) return null;
    return ProductionOrder.fromMap(maps.first);
  }

  Future<int> getProductionOrderCountByStatus(String status) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM production_orders WHERE user_id = ? AND status = ?', [_currentUserId, status]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<int> getProductionOrderCountForDate(String dateYyyyMmDd) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM production_orders WHERE user_id = ? AND production_date = ? AND status != ?', [_currentUserId, dateYyyyMmDd, 'cancelled']);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<double?> getTotalProductionCostThisMonth() async {
    Database db = await database;
    if (_currentUserId == null) return null;
    final start = DateTime(DateTime.now().year, DateTime.now().month, 1).toIso8601String();
    final endNext = DateTime(DateTime.now().year, DateTime.now().month + 1, 1).toIso8601String();
    final r = await db.rawQuery(
      "SELECT SUM(total_cost) as s FROM production_orders WHERE user_id = ? AND status = 'completed' AND completed_at >= ? AND completed_at < ?",
      [_currentUserId, start, endNext],
    );
    final v = r.first['s'];
    return v != null ? (v as num).toDouble() : null;
  }

  // Inbound receipts
  Future<int> insertInboundReceipt(InboundReceipt receipt) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(receipt.toMap());
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('inbound_receipts', map);
  }

  /// Príjemky zoradené od najnovších. Ak [warehouseId] je zadané, len príjemky daného skladu.
  Future<List<InboundReceipt>> getInboundReceipts({int? warehouseId}) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final List<Map<String, dynamic>> maps = warehouseId != null
        ? await db.query(
            'inbound_receipts',
            where: 'user_id = ? AND warehouse_id = ?',
            whereArgs: [_currentUserId, warehouseId],
            orderBy: 'created_at DESC',
          )
        : await db.query(
            'inbound_receipts',
            where: _userWhere,
            whereArgs: _userArgs,
            orderBy: 'created_at DESC',
          );
    return maps.map((m) => InboundReceipt.fromMap(m)).toList();
  }

  Future<List<ReceiptMovementType>> getReceiptMovementTypes() async {
    Database db = await database;
    final maps = await db.query(
      'receipt_movement_types',
      orderBy: 'code ASC',
    );
    return maps.map((m) => ReceiptMovementType.fromMap(m)).toList();
  }

  Future<InboundReceipt?> getInboundReceiptById(int id) async {
    Database db = await database;
    if (_currentUserId == null) return null;
    final List<Map<String, dynamic>> maps = await db.query(
      'inbound_receipts',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _currentUserId],
    );
    if (maps.isEmpty) return null;
    return InboundReceipt.fromMap(maps.first);
  }

  Future<List<InboundReceiptItem>> getInboundReceiptItems(int receiptId) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final List<Map<String, dynamic>> maps = await db.query(
      'inbound_receipt_items',
      where: 'receipt_id = ? AND user_id = ?',
      whereArgs: [receiptId, _currentUserId],
    );
    return maps.map((m) => InboundReceiptItem.fromMap(m)).toList();
  }

  Future<int> insertInboundReceiptItem(InboundReceiptItem item) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(item.toMap());
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('inbound_receipt_items', map);
  }

  Future<int> updateInboundReceipt(InboundReceipt receipt) async {
    if (receipt.id == null || _currentUserId == null) return 0;
    Database db = await database;
    return await db.update(
      'inbound_receipts',
      receipt.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [receipt.id, _currentUserId],
    );
  }

  Future<int> updateInboundReceiptStatus(
    int id,
    InboundReceiptStatus status,
  ) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    return await db.update(
      'inbound_receipts',
      {'status': status.value},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _currentUserId],
    );
  }

  Future<int> deleteInboundReceiptItemsByReceiptId(int receiptId) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    return await db.delete(
      'inbound_receipt_items',
      where: 'receipt_id = ? AND user_id = ?',
      whereArgs: [receiptId, _currentUserId],
    );
  }

  Future<List<ReceiptAcquisitionCost>> getReceiptAcquisitionCosts(int receiptId) async {
    Database db = await database;
    final maps = await db.query(
      'receipt_acquisition_costs',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return maps.map((m) => ReceiptAcquisitionCost.fromMap(m)).toList();
  }

  Future<int> insertReceiptAcquisitionCost(ReceiptAcquisitionCost cost) async {
    Database db = await database;
    final map = cost.toMap();
    map.remove('id');
    return await db.insert('receipt_acquisition_costs', map);
  }

  Future<int> deleteReceiptAcquisitionCostsByReceiptId(int receiptId) async {
    Database db = await database;
    return await db.delete(
      'receipt_acquisition_costs',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
    );
  }

  /// Vymaže príjemku a jej položky. Len neschválené príjemky.
  Future<int> deleteInboundReceipt(int receiptId) async {
    Database db = await database;
    final receipt = await getInboundReceiptById(receiptId);
    if (receipt == null || receipt.isApproved || _currentUserId == null) return 0;
    await db.delete(
      'inbound_receipt_items',
      where: 'receipt_id = ? AND user_id = ?',
      whereArgs: [receiptId, _currentUserId],
    );
    await deleteReceiptAcquisitionCostsByReceiptId(receiptId);
    return await db.delete(
      'inbound_receipts',
      where: 'id = ? AND user_id = ?',
      whereArgs: [receiptId, _currentUserId],
    );
  }

  /// Aktualizuje celú príjemku (vrátane nových stĺpcov schválenia).
  Future<void> updateInboundReceiptFull(InboundReceipt receipt) async {
    if (receipt.id == null || _currentUserId == null) return;
    Database db = await database;
    await db.update(
      'inbound_receipts',
      receipt.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [receipt.id, _currentUserId],
    );
  }

  /// Označí príjemku, že bolo množstvo pričítané/odpočítané na sklad. [applied] = false pri storne s odpočítaním.
  Future<void> setReceiptStockApplied(int receiptId, {bool applied = true}) async {
    Database db = await database;
    if (_currentUserId == null) return;
    await db.update(
      'inbound_receipts',
      {'stock_applied': applied ? 1 : 0},
      where: 'id = ? AND user_id = ?',
      whereArgs: [receiptId, _currentUserId],
    );
  }

  /// Používatelia s danou rolou (admin, user, manager).
  Future<List<User>> getUsersWithRole(String role) async {
    Database db = await database;
    final maps = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: [role],
    );
    return maps.map((m) => User.fromMap(m)).toList();
  }

  /// Všetci manažéri a admini (pre notifikácie).
  Future<List<User>> getManagersAndAdmins() async {
    Database db = await database;
    final maps = await db.query('users');
    return maps
        .map((m) => User.fromMap(m))
        .where((u) => u.role == 'admin' || u.role == 'manager')
        .toList();
  }

  // App notifications
  Future<int> insertAppNotification(AppNotification n) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(n.toMap());
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('app_notifications', map);
  }

  Future<List<AppNotification>> getAppNotifications({
    String? targetUsername,
    bool? unreadOnly,
    String? typeFilter,
    int limit = 100,
    int offset = 0,
    DateTime? olderThan,
  }) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final conditions = <String>['user_id = ?'];
    final whereArgs = <Object?>[_currentUserId];
    if (targetUsername != null) {
      conditions.add('(target_username IS NULL OR target_username = ?)');
      whereArgs.add(targetUsername);
    }
    if (unreadOnly == true) {
      conditions.add('read = 0');
    }
    if (typeFilter != null && typeFilter.isNotEmpty) {
      conditions.add('type = ?');
      whereArgs.add(typeFilter);
    }
    if (olderThan != null) {
      conditions.add('created_at >= ?');
      whereArgs.add(olderThan.toIso8601String());
    }
    final maps = await db.query(
      'app_notifications',
      where: conditions.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => AppNotification.fromMap(m)).toList();
  }

  Future<int> getUnreadNotificationCount(String? targetUsername) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    final args = [_currentUserId];
    if (targetUsername != null) args.add(targetUsername);
    final r = await db.rawQuery(
      targetUsername == null
          ? 'SELECT COUNT(*) as c FROM app_notifications WHERE user_id = ? AND read = 0'
          : 'SELECT COUNT(*) as c FROM app_notifications WHERE user_id = ? AND read = 0 AND (target_username IS NULL OR target_username = ?)',
      args,
    );
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> markNotificationRead(int id) async {
    Database db = await database;
    if (_currentUserId == null) return;
    await db.update('app_notifications', {'read': 1}, where: 'id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
  }

  Future<void> markAllNotificationsRead(String? targetUsername) async {
    Database db = await database;
    if (_currentUserId == null) return;
    if (targetUsername == null) {
      await db.update('app_notifications', {'read': 1}, where: 'user_id = ?', whereArgs: [_currentUserId]);
    } else {
      await db.update(
        'app_notifications',
        {'read': 1},
        where: 'user_id = ? AND (target_username IS NULL OR target_username = ?)',
        whereArgs: [_currentUserId, targetUsername],
      );
    }
  }

  Future<void> deleteNotificationsOlderThan(Duration d) async {
    Database db = await database;
    if (_currentUserId == null) return;
    final cutoff = DateTime.now().subtract(d);
    await db.delete(
      'app_notifications',
      where: 'user_id = ? AND created_at < ?',
      whereArgs: [_currentUserId, cutoff.toIso8601String()],
    );
  }

  Future<Map<String, dynamic>?> getNotificationPreferences(String username) async {
    Database db = await database;
    if (_currentUserId == null) return null;
    final maps = await db.query(
      'notification_preferences',
      where: 'username = ? AND user_id = ?',
      whereArgs: [username, _currentUserId],
    );
    if (maps.isEmpty) return null;
    final m = maps.first;
    return {
      'quiet_hours_start': m['quiet_hours_start'] as String?,
      'quiet_hours_end': m['quiet_hours_end'] as String?,
      'pending_reminder_hours': (m['pending_reminder_hours'] as int?) ?? 24,
      'price_change_threshold_percent': (m['price_change_threshold_percent'] as num?)?.toDouble() ?? 20.0,
    };
  }

  Future<void> saveNotificationPreferences(
    String username, {
    String? quietHoursStart,
    String? quietHoursEnd,
    int? pendingReminderHours,
    double? priceChangeThresholdPercent,
  }) async {
    Database db = await database;
    final existing = await getNotificationPreferences(username);
    final map = <String, dynamic>{
      'username': username,
      'quiet_hours_start': quietHoursStart ?? existing?['quiet_hours_start'],
      'quiet_hours_end': quietHoursEnd ?? existing?['quiet_hours_end'],
      'pending_reminder_hours': pendingReminderHours ?? existing?['pending_reminder_hours'] ?? 24,
      'price_change_threshold_percent': priceChangeThresholdPercent ?? existing?['price_change_threshold_percent'] ?? 20.0,
    };
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    await db.insert(
      'notification_preferences',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// História nákupných cien produktu z príjemok (vykázané + schválené).
  Future<List<Map<String, dynamic>>> getPurchasePriceHistory(
    String productUniqueId,
  ) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final rows = await db.rawQuery(
      '''
      SELECT r.receipt_number, r.created_at, r.prices_include_vat,
             i.unit_price, i.qty, i.unit
      FROM inbound_receipt_items i
      JOIN inbound_receipts r ON i.receipt_id = r.id AND r.user_id = i.user_id
      WHERE i.product_unique_id = ? AND i.user_id = ?
      ORDER BY r.created_at DESC
    ''',
      [productUniqueId, _currentUserId],
    );
    return rows;
  }

  Future<String> getNextReceiptNumber() async {
    Database db = await database;
    if (_currentUserId == null) return 'PR-${DateTime.now().year}-0001';
    final year = DateTime.now().year;
    final prefix = 'PR-$year-';
    final result = await db.rawQuery(
      'SELECT receipt_number FROM inbound_receipts WHERE user_id = ? AND receipt_number LIKE ? ORDER BY id DESC LIMIT 1',
      [_currentUserId, '$prefix%'],
    );
    if (result.isEmpty) return '${prefix}0001';
    final last = result.first['receipt_number'] as String;
    final numPart = last.replaceFirst(prefix, '');
    final next = (int.tryParse(numPart) ?? 0) + 1;
    return '$prefix${next.toString().padLeft(4, '0')}';
  }

  // Supplier CRUD
  Future<int> insertSupplier(Supplier supplier) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(supplier.toMap());
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('suppliers', map);
  }

  Future<List<Supplier>> getSuppliers() async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query('suppliers', where: _userWhere, whereArgs: _userArgs, orderBy: 'name ASC');
    return maps.map((m) => Supplier.fromMap(m)).toList();
  }

  Future<List<Supplier>> getActiveSuppliers() async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query(
      'suppliers',
      where: 'user_id = ? AND is_active = 1',
      whereArgs: [_currentUserId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Supplier.fromMap(m)).toList();
  }

  Future<Supplier?> getSupplierById(int id) async {
    Database db = await database;
    if (_currentUserId == null) return null;
    final maps = await db.query('suppliers', where: 'id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
    if (maps.isEmpty) return null;
    return Supplier.fromMap(maps.first);
  }

  Future<int> updateSupplier(Supplier supplier) async {
    if (supplier.id == null || _currentUserId == null) return 0;
    Database db = await database;
    return await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [supplier.id, _currentUserId],
    );
  }

  Future<int> deleteSupplier(int id) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    return await db.delete('suppliers', where: 'id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
  }

  // Customer CRUD
  Future<int> insertCustomer(Customer customer) async {
    if (_currentUserId == null) {
      await DatabaseService.restoreCurrentUser();
    }
    if (_currentUserId == null) {
      print(
        'ERROR insertCustomer: currentUserId still null after restore, refusing to insert customer ${customer.name} | instance: ${_instance.hashCode}',
      );
      throw Exception('User not logged in – cannot insert customer');
    }
    final db = await database;
    final map = Map<String, dynamic>.from(customer.toMap());
    map['user_id'] = _currentUserId;
    print('DEBUG insertCustomer: user_id = $_currentUserId | instance: ${_instance.hashCode}');
    print('DEBUG insertCustomer map: $map');
    return await db.insert('customers', map);
  }

  Future<List<Customer>> getCustomers() async {
    if (_currentUserId == null) {
      await DatabaseService.restoreCurrentUser();
    }
    if (_currentUserId == null) {
      print(
        'ERROR getCustomers: currentUserId still null after restore – returning empty list | instance: ${_instance.hashCode}',
      );
      return [];
    }
    print('DEBUG getCustomers: user=$_currentUserId | instance: ${_instance.hashCode}');
    final db = await database;
    final maps = await db.query(
      'customers',
      where: _userWhere,
      whereArgs: _userArgs,
      orderBy: 'name ASC',
    );
    print('DEBUG getCustomers result count: ${maps.length}');
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<List<Customer>> getActiveCustomers() async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query(
      'customers',
      where: 'user_id = ? AND is_active = 1',
      whereArgs: [_currentUserId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    Database db = await database;
    if (_currentUserId == null) return null;
    final maps = await db.query('customers', where: 'id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<int> updateCustomer(Customer customer) async {
    if (customer.id == null || _currentUserId == null) return 0;
    Database db = await database;
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [customer.id, _currentUserId],
    );
  }

  Future<int> deleteCustomer(int id) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    return await db.delete('customers', where: 'id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
  }

  /// Nahradí lokálnych zákazníkov zoznamom z backendu. Vkladá s user_id = _currentUserId.
  Future<void> replaceCustomersFromBackend(List<Map<String, dynamic>> list) async {
    if (list.isEmpty || _currentUserId == null) return;
    Database db = await database;
    await db.delete('customers', where: 'user_id = ?', whereArgs: [_currentUserId]);
    for (final map in list) {
      final c = Customer.fromMap(Map<String, dynamic>.from(map));
      final row = Map<String, dynamic>.from(c.toMap());
      row['user_id'] = _currentUserId;
      await db.insert('customers', row);
    }
  }

  // Quote CRUD
  Future<String> getNextQuoteNumber() async {
    Database db = await database;
    if (_currentUserId == null) return 'CP-${DateTime.now().year}-0001';
    final year = DateTime.now().year;
    final prefix = 'CP-$year-';
    final result = await db.rawQuery(
      'SELECT quote_number FROM quotes WHERE user_id = ? AND quote_number LIKE ? ORDER BY id DESC LIMIT 1',
      [_currentUserId, '$prefix%'],
    );
    if (result.isEmpty) return '${prefix}0001';
    final last = result.first['quote_number'] as String;
    final numPart = last.replaceFirst(prefix, '');
    final next = (int.tryParse(numPart) ?? 0) + 1;
    return '$prefix${next.toString().padLeft(4, '0')}';
  }

  Future<int> insertQuote(Quote quote) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(quote.toMap());
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('quotes', map);
  }

  Future<Quote?> getQuoteById(int id) async {
    Database db = await database;
    if (_currentUserId == null) return null;
    final maps = await db.query('quotes', where: 'id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
    if (maps.isEmpty) return null;
    return Quote.fromMap(maps.first);
  }

  Future<List<Quote>> getQuotes() async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query('quotes', where: _userWhere, whereArgs: _userArgs, orderBy: 'created_at DESC');
    return maps.map((m) => Quote.fromMap(m)).toList();
  }

  Future<List<Quote>> getQuotesByCustomerId(int customerId) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query(
      'quotes',
      where: 'user_id = ? AND customer_id = ?',
      whereArgs: [_currentUserId, customerId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Quote.fromMap(m)).toList();
  }

  Future<int> updateQuote(Quote quote) async {
    if (quote.id == null || _currentUserId == null) return 0;
    Database db = await database;
    return await db.update(
      'quotes',
      quote.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [quote.id, _currentUserId],
    );
  }

  Future<int> deleteQuote(int id) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    await db.delete('quote_items', where: 'quote_id = ?', whereArgs: [id]);
    return await db.delete('quotes', where: 'id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
  }

  Future<List<QuoteItem>> getQuoteItems(int quoteId) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query(
      'quote_items',
      where: 'quote_id = ? AND user_id = ?',
      whereArgs: [quoteId, _currentUserId],
      orderBy: 'id ASC',
    );
    return maps.map((m) => QuoteItem.fromMap(m)).toList();
  }

  Future<int> insertQuoteItem(QuoteItem item) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(item.toMap());
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('quote_items', map);
  }

  Future<int> updateQuoteItem(QuoteItem item) async {
    if (item.id == null || _currentUserId == null) return 0;
    Database db = await database;
    return await db.update(
      'quote_items',
      item.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [item.id, _currentUserId],
    );
  }

  Future<int> deleteQuoteItem(int id) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    return await db.delete('quote_items', where: 'id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
  }

  Future<int> deleteQuoteItemsByQuoteId(int quoteId) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    return await db.delete(
      'quote_items',
      where: 'quote_id = ? AND user_id = ?',
      whereArgs: [quoteId, _currentUserId],
    );
  }

  Future<Company?> getCompany() async {
    Database db = await database;
    final maps = await db.query('company', where: 'id = 1');
    if (maps.isEmpty) return null;
    return Company.fromMap(maps.first);
  }

  Future<int> saveCompany(Company company) async {
    Database db = await database;
    final map = company.toMap();
    map['id'] = 1;
    return await db.insert(
      'company',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Warehouse CRUD
  Future<int> insertWarehouse(Warehouse warehouse) async {
    Database db = await database;
    return await db.insert('warehouses', warehouse.toMap());
  }

  Future<List<Warehouse>> getWarehouses() async {
    Database db = await database;
    final maps = await db.query('warehouses', orderBy: 'name ASC');
    return maps.map((m) => Warehouse.fromMap(m)).toList();
  }
  Future<List<WarehouseTransfer>> getWarehouseTransfers() async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query('warehouse_transfers', where: _userWhere, whereArgs: _userArgs, orderBy: 'created_at DESC');
    return maps.map((m) => WarehouseTransfer.fromMap(m)).toList();
  }

  Future<int> insertWarehouseTransfer(WarehouseTransfer transfer) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(transfer.toMap());
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('warehouse_transfers', map);
  }

  /// Vykoná presun medzi skladmi: zníži zásobu v zdrojovom sklade, zvýši (alebo vytvorí kartu) v cieľovom, zapíše presun.
  /// Pri chybe validácie alebo DB vyhodí výnimku.
  Future<int> executeWarehouseTransfer(WarehouseTransfer transfer) async {
    final db = await database;
    return await db.transaction((txn) async {
      final sourceMaps = await txn.query(
        'products',
        where: 'unique_id = ?',
        whereArgs: [transfer.productUniqueId],
      );
      if (sourceMaps.isEmpty) {
        throw Exception('Produkt nebol nájdený');
      }
      final source = Product.fromMap(sourceMaps.first);
      if (source.warehouseId != transfer.fromWarehouseId) {
        throw Exception('Produkt nie je v zdrojovom sklade');
      }
      if (source.qty < transfer.quantity) {
        throw Exception(
            'Nedostatočné množstvo. Na sklade je ${source.qty} ${transfer.unit}.');
      }
      final newSourceQty = source.qty - transfer.quantity;
      final updatedSource = Product(
        uniqueId: source.uniqueId,
        name: source.name,
        plu: source.plu,
        ean: source.ean,
        category: source.category,
        qty: newSourceQty,
        unit: source.unit,
        price: source.price,
        withoutVat: source.withoutVat,
        vat: source.vat,
        discount: source.discount,
        lastPurchasePrice: source.lastPurchasePrice,
        lastPurchasePriceWithoutVat: source.lastPurchasePriceWithoutVat,
        lastPurchaseDate: source.lastPurchaseDate,
        currency: source.currency,
        location: source.location,
        purchasePrice: source.purchasePrice,
        purchasePriceWithoutVat: source.purchasePriceWithoutVat,
        purchaseVat: source.purchaseVat,
        recyclingFee: source.recyclingFee,
        productType: source.productType,
        supplierName: source.supplierName,
        kindId: source.kindId,
        warehouseId: source.warehouseId,
        linkedProductUniqueId: source.linkedProductUniqueId,
        minQuantity: source.minQuantity,
        allowAtCashRegister: source.allowAtCashRegister,
        showInPriceList: source.showInPriceList,
        isActive: source.isActive,
        temporarilyUnavailable: source.temporarilyUnavailable,
        stockGroup: source.stockGroup,
        cardType: source.cardType,
        hasExtendedPricing: source.hasExtendedPricing,
        ibaCeleMnozstva: source.ibaCeleMnozstva,
      );
      await txn.update(
        'products',
        updatedSource.toMap(),
        where: 'unique_id = ?',
        whereArgs: [source.uniqueId],
      );
      final targetMaps = await txn.query(
        'products',
        where: 'warehouse_id = ?',
        whereArgs: [transfer.toWarehouseId],
      );
      Product? target;
      try {
        target = targetMaps
            .map((m) => Product.fromMap(m))
            .firstWhere((p) =>
                p.plu == transfer.productPlu && p.name == transfer.productName);
      } catch (_) {
        target = null;
      }
      if (target != null) {
        final updatedTarget = Product(
          uniqueId: target.uniqueId,
          name: target.name,
          plu: target.plu,
          ean: target.ean,
          category: target.category,
          qty: target.qty + transfer.quantity,
          unit: target.unit,
          price: target.price,
          withoutVat: target.withoutVat,
          vat: target.vat,
          discount: target.discount,
          lastPurchasePrice: target.lastPurchasePrice,
          lastPurchasePriceWithoutVat: target.lastPurchasePriceWithoutVat,
          lastPurchaseDate: target.lastPurchaseDate,
          currency: target.currency,
          location: target.location,
          purchasePrice: target.purchasePrice,
          purchasePriceWithoutVat: target.purchasePriceWithoutVat,
          purchaseVat: target.purchaseVat,
          recyclingFee: target.recyclingFee,
          productType: target.productType,
          supplierName: target.supplierName,
          kindId: target.kindId,
          warehouseId: target.warehouseId,
          linkedProductUniqueId: target.linkedProductUniqueId,
          minQuantity: target.minQuantity,
          allowAtCashRegister: target.allowAtCashRegister,
          showInPriceList: target.showInPriceList,
          isActive: target.isActive,
          temporarilyUnavailable: target.temporarilyUnavailable,
          stockGroup: target.stockGroup,
          cardType: target.cardType,
          hasExtendedPricing: target.hasExtendedPricing,
          ibaCeleMnozstva: target.ibaCeleMnozstva,
        );
        await txn.update(
          'products',
          updatedTarget.toMap(),
          where: 'unique_id = ?',
          whereArgs: [target.uniqueId],
        );
      } else {
        final newUniqueId = 'W${transfer.toWarehouseId}-${source.uniqueId}';
        final newProduct = Product(
          uniqueId: newUniqueId,
          name: transfer.productName,
          plu: transfer.productPlu,
          ean: source.ean,
          category: source.category,
          qty: transfer.quantity,
          unit: transfer.unit,
          price: source.price,
          withoutVat: source.withoutVat,
          vat: source.vat,
          discount: source.discount,
          lastPurchasePrice: source.lastPurchasePrice,
          lastPurchasePriceWithoutVat: source.lastPurchasePriceWithoutVat,
          lastPurchaseDate: source.lastPurchaseDate,
          currency: source.currency,
          location: source.location,
          purchasePrice: source.purchasePrice,
          purchasePriceWithoutVat: source.purchasePriceWithoutVat,
          purchaseVat: source.purchaseVat,
          recyclingFee: source.recyclingFee,
          productType: source.productType,
          supplierName: source.supplierName,
          kindId: source.kindId,
          warehouseId: transfer.toWarehouseId,
          linkedProductUniqueId: source.linkedProductUniqueId,
          minQuantity: source.minQuantity,
          allowAtCashRegister: source.allowAtCashRegister,
          showInPriceList: source.showInPriceList,
          isActive: source.isActive,
          temporarilyUnavailable: source.temporarilyUnavailable,
          stockGroup: source.stockGroup,
          cardType: source.cardType,
          hasExtendedPricing: source.hasExtendedPricing,
          ibaCeleMnozstva: source.ibaCeleMnozstva,
        );
        await txn.insert('products', newProduct.toMap());
      }
      final wtMap = Map<String, dynamic>.from(transfer.toMap());
      if (_currentUserId != null) wtMap['user_id'] = _currentUserId;
      return await txn.insert('warehouse_transfers', wtMap);
    });
  }

  /// Prevodka: zníži zásoby vo zdrojovom sklade, zvýši (alebo vytvorí) v cieľovom, zapíše pohyby výdajky.
  Future<void> applyTransferReceipt({
    required int sourceWarehouseId,
    required int destWarehouseId,
    required List<InboundReceiptItem> items,
    required int stockOutId,
    required String stockOutDocumentNumber,
    required DateTime stockOutCreatedAt,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final item in items) {
        final sourceMaps = await txn.query(
          'products',
          where: 'unique_id = ?',
          whereArgs: [item.productUniqueId],
        );
        if (sourceMaps.isEmpty) {
          throw Exception('Produkt ${item.productName ?? item.productUniqueId} nebol nájdený.');
        }
        final source = Product.fromMap(sourceMaps.first);
        if (source.warehouseId != sourceWarehouseId) {
          throw Exception(
              'Produkt ${item.productName} nie je v zdrojovom sklade (alebo je v inom sklade).');
        }
        if (source.qty < item.qty) {
          throw Exception(
              'Nedostatočné množstvo: ${item.productName ?? item.productUniqueId}. Požadované: ${item.qty}, dostupné: ${source.qty}.');
        }
        final newSourceQty = source.qty - item.qty;
        final updatedSource = source.copyWith(qty: newSourceQty);
        await txn.update(
          'products',
          updatedSource.toMap(),
          where: 'unique_id = ?',
          whereArgs: [source.uniqueId],
        );

        final targetMaps = await txn.query(
          'products',
          where: 'warehouse_id = ?',
          whereArgs: [destWarehouseId],
        );
        Product? target;
        try {
          target = targetMaps
              .map((m) => Product.fromMap(m))
              .firstWhere((p) =>
                  p.plu == (item.plu ?? '') && p.name == (item.productName ?? ''));
        } catch (_) {
          target = null;
        }
        if (target != null) {
          final updatedTarget = target.copyWith(qty: target.qty + item.qty);
          await txn.update(
            'products',
            updatedTarget.toMap(),
            where: 'unique_id = ?',
            whereArgs: [target.uniqueId],
          );
        } else {
          final newUniqueId = 'W$destWarehouseId-${source.uniqueId}';
          final newProduct = Product(
            uniqueId: newUniqueId,
            name: item.productName ?? source.name,
            plu: item.plu ?? source.plu,
            ean: source.ean,
            category: source.category,
            qty: item.qty,
            unit: item.unit,
            price: source.price,
            withoutVat: source.withoutVat,
            vat: source.vat,
            discount: source.discount,
            lastPurchasePrice: source.lastPurchasePrice,
            lastPurchasePriceWithoutVat: source.lastPurchasePriceWithoutVat,
            lastPurchaseDate: source.lastPurchaseDate,
            currency: source.currency,
            location: source.location,
            purchasePrice: source.purchasePrice,
            purchasePriceWithoutVat: source.purchasePriceWithoutVat,
            purchaseVat: source.purchaseVat,
            recyclingFee: source.recyclingFee,
            productType: source.productType,
            supplierName: source.supplierName,
            kindId: source.kindId,
            warehouseId: destWarehouseId,
            linkedProductUniqueId: source.linkedProductUniqueId,
            minQuantity: source.minQuantity,
            allowAtCashRegister: source.allowAtCashRegister,
            showInPriceList: source.showInPriceList,
            isActive: source.isActive,
            temporarilyUnavailable: source.temporarilyUnavailable,
            stockGroup: source.stockGroup,
            cardType: source.cardType,
            hasExtendedPricing: source.hasExtendedPricing,
            ibaCeleMnozstva: source.ibaCeleMnozstva,
          );
          await txn.insert('products', newProduct.toMap());
        }

        final smMap = StockMovement(
          stockOutId: stockOutId,
          documentNumber: stockOutDocumentNumber,
          createdAt: stockOutCreatedAt,
          productUniqueId: item.productUniqueId,
          productName: item.productName,
          plu: item.plu,
          qty: item.qty,
          unit: item.unit,
          direction: 'OUT',
        ).toMap();
        if (_currentUserId != null) smMap['user_id'] = _currentUserId;
        await txn.insert('stock_movements', smMap);
      }
    });
  }

  Future<List<Warehouse>> getActiveWarehouses() async {
    Database db = await database;
    final maps = await db.query(
      'warehouses',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
    return maps.map((m) => Warehouse.fromMap(m)).toList();
  }

  Future<Warehouse?> getWarehouseById(int id) async {
    Database db = await database;
    final maps = await db.query('warehouses', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Warehouse.fromMap(maps.first);
  }

  Future<int> updateWarehouse(Warehouse warehouse) async {
    if (warehouse.id == null) return 0;
    Database db = await database;
    return await db.update(
      'warehouses',
      warehouse.toMap(),
      where: 'id = ?',
      whereArgs: [warehouse.id],
    );
  }

  Future<int> deleteWarehouse(int id) async {
    Database db = await database;
    return await db.delete('warehouses', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    Database db = await database;
    if (_currentUserId == null) {
      return {
        'products': 0, 'orders': 0, 'customers': 0, 'revenue': 0.0, 'inboundCount': 0, 'outboundCount': 0,
        'quotesCount': 0, 'receiptsToday': 0, 'pendingReceiptCount': 0, 'receiptsValueThisMonth': 0.0,
        'lowStockCount': 0, 'lastReceipt': null, 'productionOrdersToday': 0, 'productionInProgressCount': 0,
        'productionPendingApprovalCount': 0, 'productionCostThisMonth': 0.0,
      };
    }
    final uid = _currentUserId!;

    // Počet produktov
    final productCountResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE user_id = ?', [uid],
    );
    int productCount = Sqflite.firstIntValue(productCountResult) ?? 0;

    // Počet zákazníkov
    final customerCountResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM customers WHERE user_id = ?', [uid],
    );
    int customerCount = Sqflite.firstIntValue(customerCountResult) ?? 0;

    // Počet quotes (ako objednávky)
    final quotesCountResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM quotes WHERE user_id = ?', [uid],
    );
    int quotesCount = Sqflite.firstIntValue(quotesCountResult) ?? 0;

    // Počet príjemiek
    final inboundCountResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM inbound_receipts WHERE user_id = ?', [uid],
    );
    int inboundCount = Sqflite.firstIntValue(inboundCountResult) ?? 0;

    // Príjemky dnes (created_at v rámci dnes)
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).toIso8601String();
    final todayEnd = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59).toIso8601String();
    final receiptsTodayResult = await db.rawQuery(
      'SELECT COUNT(*) as c FROM inbound_receipts WHERE user_id = ? AND created_at >= ? AND created_at <= ?',
      [uid, todayStart, todayEnd],
    );
    int receiptsToday = (receiptsTodayResult.isNotEmpty && receiptsTodayResult.first['c'] != null)
        ? (receiptsTodayResult.first['c'] as num).toInt() : 0;

    // Čakajú na schválenie (pending)
    final pendingResult = await db.rawQuery(
      "SELECT COUNT(*) as c FROM inbound_receipts WHERE user_id = ? AND status = 'pending'", [uid],
    );
    int pendingCount = (pendingResult.isNotEmpty && pendingResult.first['c'] != null)
        ? (pendingResult.first['c'] as num).toInt() : 0;

    // Hodnota príjemiek tento mesiac (schválené, súčet položiek)
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1).toIso8601String();
    double valueThisMonth = 0.0;
    try {
      final sumResult = await db.rawQuery('''
        SELECT SUM(i.qty * i.unit_price) as total
        FROM inbound_receipt_items i
        JOIN inbound_receipts r ON r.id = i.receipt_id AND r.user_id = i.user_id
        WHERE r.user_id = ? AND r.status = 'schvalena' AND r.approved_at >= ?
      ''', [uid, monthStart]);
      if (sumResult.isNotEmpty && sumResult[0]['total'] != null) {
        valueThisMonth = (sumResult[0]['total'] as num).toDouble();
      }
    } catch (_) {}

    // Produkty pod minimálnou zásobou
    final lowResult = await db.rawQuery(
      'SELECT COUNT(*) as c FROM products WHERE user_id = ? AND min_quantity > 0 AND qty < min_quantity', [uid],
    );
    int lowStockCount = (lowResult.isNotEmpty && lowResult.first['c'] != null)
        ? (lowResult.first['c'] as num).toInt() : 0;

    // Posledná príjemka (číslo + dátum)
    Map<String, dynamic>? lastReceipt;
    final lastR = await db.query('inbound_receipts', where: 'user_id = ?', whereArgs: [uid], orderBy: 'created_at DESC', limit: 1);
    if (lastR.isNotEmpty) {
      lastReceipt = {
        'receipt_number': lastR[0]['receipt_number'],
        'created_at': lastR[0]['created_at'],
      };
    }

    // Výrobné príkazy – KPI
    final todayStr = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).toIso8601String().split('T').first;
    final productionTodayResult = await db.rawQuery(
      "SELECT COUNT(*) as c FROM production_orders WHERE user_id = ? AND production_date = ? AND status != 'cancelled'",
      [uid, todayStr],
    );
    int productionOrdersToday = (productionTodayResult.isNotEmpty && productionTodayResult.first['c'] != null)
        ? (productionTodayResult.first['c'] as num).toInt() : 0;
    final productionInProgressResult = await db.rawQuery(
      "SELECT COUNT(*) as c FROM production_orders WHERE user_id = ? AND status = 'in_progress'", [uid],
    );
    int productionInProgressCount = (productionInProgressResult.isNotEmpty && productionInProgressResult.first['c'] != null)
        ? (productionInProgressResult.first['c'] as num).toInt() : 0;
    final productionPendingResult = await db.rawQuery(
      "SELECT COUNT(*) as c FROM production_orders WHERE user_id = ? AND status = 'pending'", [uid],
    );
    int productionPendingApprovalCount = (productionPendingResult.isNotEmpty && productionPendingResult.first['c'] != null)
        ? (productionPendingResult.first['c'] as num).toInt() : 0;
    double productionCostThisMonth = 0.0;
    try {
      final costResult = await db.rawQuery(
        "SELECT SUM(total_cost) as s FROM production_orders WHERE user_id = ? AND status = 'completed' AND completed_at >= ? AND completed_at < ?",
        [uid, monthStart, DateTime(DateTime.now().year, DateTime.now().month + 1, 1).toIso8601String()],
      );
      if (costResult.isNotEmpty && costResult.first['s'] != null) {
        productionCostThisMonth = (costResult.first['s'] as num).toDouble();
      }
    } catch (_) {}

    // Počet výdajok (zatiaľ 0, keďže nemáme outbound_receipts tabuľku)
    int outboundCount = 0;

    // Výpočet tržieb z quotes (súčet celkových súm s DPH)
    double revenue = 0.0;
    try {
      final revenueResult = await db.rawQuery('''
        SELECT SUM(
          (SELECT SUM(qi.qty * qi.unit_price * (1 + qi.vat_percent / 100.0))
           FROM quote_items qi
           WHERE qi.quote_id = q.id AND qi.user_id = q.user_id)
        ) as total
        FROM quotes q
        WHERE q.user_id = ? AND q.status != 'draft'
      ''', [uid]);
      if (revenueResult.isNotEmpty && revenueResult[0]['total'] != null) {
        revenue = (revenueResult[0]['total'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      revenue = 0.0;
    }

    return {
      'products': productCount,
      'orders': quotesCount,
      'customers': customerCount,
      'revenue': revenue,
      'inboundCount': inboundCount,
      'outboundCount': outboundCount,
      'quotesCount': quotesCount,
      'receiptsToday': receiptsToday,
      'pendingReceiptCount': pendingCount,
      'receiptsValueThisMonth': valueThisMonth,
      'lowStockCount': lowStockCount,
      'lastReceipt': lastReceipt,
      'productionOrdersToday': productionOrdersToday,
      'productionInProgressCount': productionInProgressCount,
      'productionPendingApprovalCount': productionPendingApprovalCount,
      'productionCostThisMonth': productionCostThisMonth,
    };
  }

  Future<bool> getRememberMe() async {
    Database db = await database;
    final rows = await db.query('preferences', where: 'key = ?', whereArgs: ['remember_me']);
    if (rows.isEmpty) return false;
    final v = rows.first['value'] as String?;
    return v == '1' || v == 'true';
  }

  Future<String?> getSavedUsername() async {
    Database db = await database;
    final rows = await db.query('preferences', where: 'key = ?', whereArgs: ['saved_username']);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setRememberMe(bool value) async {
    Database db = await database;
    await db.insert('preferences', {'key': 'remember_me', 'value': value ? '1' : '0'}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setSavedUsername(String username) async {
    Database db = await database;
    await db.insert('preferences', {'key': 'saved_username', 'value': username}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearSavedLogin() async {
    Database db = await database;
    await db.delete('preferences', where: 'key IN (?, ?)', whereArgs: ['remember_me', 'saved_username']);
  }

  Future<void> clearAllData() async {
    Database db = await database;
    await db.delete('stock_out_items');
    await db.delete('stock_outs');
    await db.delete('warehouse_transfers');
    await db.delete('transports');
    await db.delete('preferences');
    await db.delete('inbound_receipt_items');
    await db.delete('inbound_receipts');
    await db.delete('quote_items');
    await db.delete('quotes');
    await db.delete('production_orders');
    await db.delete('recipe_ingredients');
    await db.delete('recipes');
    await db.delete('receptura_polozky');
    await db.delete('products');
    await db.delete('customers');
    await db.delete('suppliers');
    await db.delete('warehouses');
    await db.delete('product_kinds');
    await db.delete('users');
    await db.update('company', {'name': 'Moja firma', 'address': null, 'city': null, 'postal_code': null, 'country': null, 'ico': null, 'ic_dph': null, 'vat_payer': 1, 'phone': null, 'email': null, 'web': null, 'iban': null, 'swift': null, 'bank_name': null, 'account': null, 'register_info': null, 'logo_path': null}, where: 'id = 1');
  }

  Future<List<Map<String, dynamic>>> getRecentInboundReceiptsWithTotal({int limit = 5}) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final receipts = await db.query('inbound_receipts', where: _userWhere, whereArgs: _userArgs, orderBy: 'created_at DESC', limit: limit);
    final result = <Map<String, dynamic>>[];
    for (final r in receipts) {
      final items = await db.query('inbound_receipt_items', where: 'receipt_id = ? AND user_id = ?', whereArgs: [r['id'], _currentUserId]);
      double total = 0;
      for (final i in items) {
        total += ((i['unit_price'] as num?) ?? 0) * ((i['qty'] as int?) ?? 0);
      }
      result.add({...r, 'total': total});
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getRecentStockOutsWithTotal({int limit = 5}) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final outs = await db.query('stock_outs', where: _userWhere, whereArgs: _userArgs, orderBy: 'created_at DESC', limit: limit);
    final result = <Map<String, dynamic>>[];
    for (final o in outs) {
      final items = await db.query('stock_out_items', where: 'stock_out_id = ? AND user_id = ?', whereArgs: [o['id'], _currentUserId]);
      double total = 0;
      for (final i in items) {
        total += ((i['unit_price'] as num?) ?? 0) * ((i['qty'] as int?) ?? 0);
      }
      result.add({...o, 'total': total});
    }
    return result;
  }

  Future<Map<int, int>> getProductCountPerWarehouse() async {
    Database db = await database;
    final rows = await db.rawQuery('SELECT warehouse_id, COUNT(*) as cnt FROM products WHERE warehouse_id IS NOT NULL GROUP BY warehouse_id');
    final map = <int, int>{};
    for (final r in rows) {
      final id = r['warehouse_id'] as int?;
      if (id != null) map[id] = (r['cnt'] as int?) ?? 0;
    }
    return map;
  }

  Future<void> insertTransport(Transport transport) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(transport.toMap());
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    await db.insert('transports', map);
  }

  Future<List<StockOut>> getStockOuts() async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query('stock_outs', where: _userWhere, whereArgs: _userArgs, orderBy: 'created_at DESC');
    return maps.map((m) => StockOut.fromMap(m)).toList();
  }

  /// Výdajky pre daný sklad; ak [warehouseId] je null, vráti všetky.
  Future<List<StockOut>> getStockOutsByWarehouseId(int? warehouseId) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = warehouseId == null
        ? await db.query('stock_outs', where: _userWhere, whereArgs: _userArgs, orderBy: 'created_at DESC')
        : await db.query(
            'stock_outs',
            where: 'user_id = ? AND warehouse_id = ?',
            whereArgs: [_currentUserId, warehouseId],
            orderBy: 'created_at DESC',
          );
    return maps.map((m) => StockOut.fromMap(m)).toList();
  }

  Future<StockOut?> getStockOutById(int id) async {
    Database db = await database;
    if (_currentUserId == null) return null;
    final maps = await db.query('stock_outs', where: 'id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
    if (maps.isEmpty) return null;
    return StockOut.fromMap(maps.first);
  }

  Future<List<StockOutItem>> getStockOutItems(int stockOutId) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query('stock_out_items', where: 'stock_out_id = ? AND user_id = ?', whereArgs: [stockOutId, _currentUserId]);
    return maps.map((m) => StockOutItem.fromMap(m)).toList();
  }

  Future<String> getNextStockOutNumber() async {
    Database db = await database;
    if (_currentUserId == null) return 'VY-${DateTime.now().year}-0001';
    final year = DateTime.now().year;
    final prefix = 'VY-$year-';
    final result = await db.rawQuery('SELECT document_number FROM stock_outs WHERE user_id = ? AND document_number LIKE ? ORDER BY id DESC LIMIT 1', [_currentUserId, '$prefix%']);
    if (result.isEmpty) return '${prefix}0001';
    final last = result.first['document_number'] as String;
    final next = (int.tryParse(last.replaceFirst(prefix, '')) ?? 0) + 1;
    return '$prefix${next.toString().padLeft(4, '0')}';
  }

  Future<int> insertStockOut(StockOut stockOut) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(stockOut.toMap());
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('stock_outs', map);
  }

  Future<void> insertStockOutItem(StockOutItem item) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(item.toMap());
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    await db.insert('stock_out_items', map);
  }

  Future<void> deleteStockOutItemsByStockOutId(int stockOutId) async {
    Database db = await database;
    if (_currentUserId == null) return;
    await db.delete('stock_out_items', where: 'stock_out_id = ? AND user_id = ?', whereArgs: [stockOutId, _currentUserId]);
  }

  Future<int> updateStockOut(StockOut stockOut) async {
    if (stockOut.id == null || _currentUserId == null) return 0;
    Database db = await database;
    return await db.update('stock_outs', stockOut.toMap(), where: 'id = ? AND user_id = ?', whereArgs: [stockOut.id, _currentUserId]);
  }

  Future<void> updateStockOutStatus(int stockOutId, StockOutStatus status) async {
    Database db = await database;
    if (_currentUserId == null) return;
    await db.update('stock_outs', {'status': status.value}, where: 'id = ? AND user_id = ?', whereArgs: [stockOutId, _currentUserId]);
  }

  Future<List<MovementType>> getMovementTypes() async {
    Database db = await database;
    final maps = await db.query('movement_types', orderBy: 'code ASC');
    return maps.map((m) => MovementType.fromMap(m)).toList();
  }

  Future<int> insertMovementType(MovementType mt) async {
    Database db = await database;
    return await db.insert('movement_types', mt.toMap());
  }

  Future<List<StockMovement>> getStockMovementsByStockOutId(int stockOutId) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query(
      'stock_movements',
      where: 'stock_out_id = ? AND user_id = ?',
      whereArgs: [stockOutId, _currentUserId],
    );
    return maps.map((m) => StockMovement.fromMap(m)).toList();
  }

  Future<int> insertStockMovement(StockMovement sm) async {
    Database db = await database;
    final map = Map<String, dynamic>.from(sm.toMap());
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('stock_movements', map);
  }

  Future<void> deleteStockMovementsByStockOutId(int stockOutId) async {
    Database db = await database;
    if (_currentUserId == null) return;
    await db.delete('stock_movements', where: 'stock_out_id = ? AND user_id = ?', whereArgs: [stockOutId, _currentUserId]);
  }

  /// Výdajové pohyby (z výdajok) s warehouse_id; ak [warehouseId] je zadané, len daný sklad.
  Future<List<WarehouseMovementRecord>> getStockMovementRecordsOut({int? warehouseId}) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final sql = '''
      SELECT sm.id, sm.document_number, sm.created_at, sm.product_unique_id, sm.product_name, sm.plu, sm.qty, sm.unit, sm.direction, so.warehouse_id
      FROM stock_movements sm
      JOIN stock_outs so ON sm.stock_out_id = so.id AND so.user_id = sm.user_id
      WHERE so.user_id = ? ${warehouseId != null ? 'AND so.warehouse_id = ?' : ''}
      ORDER BY sm.created_at DESC
    ''';
    final maps = warehouseId != null
        ? await db.rawQuery(sql, [_currentUserId, warehouseId])
        : await db.rawQuery(sql, [_currentUserId]);
    return maps.map((m) => WarehouseMovementRecord(
      createdAt: DateTime.parse(m['created_at'] as String),
      documentNumber: m['document_number'] as String? ?? '',
      productUniqueId: m['product_unique_id'] as String,
      productName: m['product_name'] as String?,
      plu: m['plu'] as String?,
      qty: m['qty'] as int,
      unit: m['unit'] as String,
      direction: m['direction'] as String? ?? 'OUT',
      warehouseId: m['warehouse_id'] as int?,
      sourceType: 'stock_out',
      relatedId: m['id'] as int?,
    )).toList();
  }

  /// Príjmové pohyby (z príjemiek); ak [warehouseId] je zadané, len daný sklad.
  Future<List<WarehouseMovementRecord>> getReceiptMovementRecordsIn({int? warehouseId}) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final sql = '''
      SELECT i.id, r.receipt_number AS document_number, r.created_at, i.product_unique_id, i.product_name, i.plu, i.qty, i.unit, r.warehouse_id
      FROM inbound_receipt_items i
      JOIN inbound_receipts r ON i.receipt_id = r.id AND r.user_id = i.user_id
      WHERE r.user_id = ? ${warehouseId != null ? 'AND r.warehouse_id = ?' : ''}
      ORDER BY r.created_at DESC
    ''';
    final maps = warehouseId != null
        ? await db.rawQuery(sql, [_currentUserId, warehouseId])
        : await db.rawQuery(sql, [_currentUserId]);
    return maps.map((m) => WarehouseMovementRecord(
      createdAt: DateTime.parse(m['created_at'] as String),
      documentNumber: m['document_number'] as String? ?? '',
      productUniqueId: m['product_unique_id'] as String,
      productName: m['product_name'] as String?,
      plu: m['plu'] as String?,
      qty: m['qty'] as int,
      unit: m['unit'] as String,
      direction: 'IN',
      warehouseId: m['warehouse_id'] as int?,
      sourceType: 'receipt',
      relatedId: m['id'] as int?,
    )).toList();
  }

  /// Presuny medzi skladmi: pre každý presun dva záznamy (OUT z from, IN do to). Ak [warehouseId] je zadané, len záznamy týkajúce sa daného skladu.
  Future<List<WarehouseMovementRecord>> getTransferMovementRecords({int? warehouseId}) async {
    Database db = await database;
    final sql = warehouseId != null
        ? 'SELECT * FROM warehouse_transfers WHERE from_warehouse_id = ? OR to_warehouse_id = ? ORDER BY created_at DESC'
        : 'SELECT * FROM warehouse_transfers ORDER BY created_at DESC';
    final maps = warehouseId != null
        ? await db.rawQuery(sql, [warehouseId, warehouseId])
        : await db.rawQuery(sql);
    final list = <WarehouseMovementRecord>[];
    for (final m in maps) {
      final fromId = m['from_warehouse_id'] as int?;
      final toId = m['to_warehouse_id'] as int?;
      final createdAt = DateTime.parse(m['created_at'] as String);
      final docNum = 'Presun #${m['id']}';
      if (warehouseId == null || fromId == warehouseId) {
        list.add(WarehouseMovementRecord(
          createdAt: createdAt,
          documentNumber: docNum,
          productUniqueId: m['product_unique_id'] as String,
          productName: m['product_name'] as String?,
          plu: m['product_plu'] as String?,
          qty: m['quantity'] as int,
          unit: m['unit'] as String? ?? 'ks',
          direction: 'OUT',
          warehouseId: fromId,
          sourceType: 'transfer',
          relatedId: m['id'] as int?,
        ));
      }
      if (warehouseId == null || toId == warehouseId) {
        list.add(WarehouseMovementRecord(
          createdAt: createdAt,
          documentNumber: docNum,
          productUniqueId: m['product_unique_id'] as String,
          productName: m['product_name'] as String?,
          plu: m['product_plu'] as String?,
          qty: m['quantity'] as int,
          unit: m['unit'] as String? ?? 'ks',
          direction: 'IN',
          warehouseId: toId,
          sourceType: 'transfer',
          relatedId: m['id'] as int?,
        ));
      }
    }
    return list;
  }

  /// Všetky záznamy knihy skladových pohybov (príjmy + výdaje + presuny), zoradené od najnovších. Ak [warehouseId] je zadané, len pohyby daného skladu.
  Future<List<WarehouseMovementRecord>> getAllWarehouseMovementRecords({int? warehouseId}) async {
    final out = await getStockMovementRecordsOut(warehouseId: warehouseId);
    final inn = await getReceiptMovementRecordsIn(warehouseId: warehouseId);
    final trans = await getTransferMovementRecords(warehouseId: warehouseId);
    final combined = [...out, ...inn, ...trans];
    combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return combined;
  }

  Future<List<ProductKind>> getProductKinds() async {
    Database db = await database;
    final maps = await db.query('product_kinds', orderBy: 'name ASC');
    return maps.map((m) => ProductKind.fromMap(m)).toList();
  }

  Future<int> insertProductKind(ProductKind kind) async {
    Database db = await database;
    return await db.insert('product_kinds', kind.toMap());
  }

  Future<int> updateProductKind(ProductKind kind) async {
    if (kind.id == null) return 0;
    Database db = await database;
    return await db.update('product_kinds', kind.toMap(), where: 'id = ?', whereArgs: [kind.id]);
  }

  Future<int> deleteProductKind(int id) async {
    Database db = await database;
    return await db.delete('product_kinds', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> getProductsByWarehouseId(int warehouseId) async {
    Database db = await database;
    final maps = await db.query('products', where: 'warehouse_id = ?', whereArgs: [warehouseId]);
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<void> updateStockAfterAudit(int warehouseId, Map<String, int> changes) async {
    Database db = await database;
    for (final e in changes.entries) {
      await db.update('products', {'qty': e.value}, where: 'unique_id = ?', whereArgs: [e.key]);
    }
  }

  // ---------- Výroba – šarže a receptúry ----------
  static const String _productionBatchQrPrefix = 'STOCKPILOT_BATCH:';

  static String productionBatchQrPayload(int batchId) => '$_productionBatchQrPrefix$batchId';

  static int? parseProductionBatchIdFromQr(String qrContent) {
    if (!qrContent.startsWith(_productionBatchQrPrefix)) return null;
    final idStr = qrContent.substring(_productionBatchQrPrefix.length).trim();
    return int.tryParse(idStr);
  }

  Future<int> insertProductionBatch(ProductionBatch batch) async {
    Database db = await database;
    final map = batch.toMap()
      ..remove('id')
      ..['created_at'] = batch.createdAt ?? DateTime.now().toIso8601String();
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('production_batches', map);
  }

  Future<ProductionBatch?> getProductionBatchById(int id) async {
    Database db = await database;
    if (_currentUserId == null) return null;
    final maps = await db.query('production_batches', where: 'id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
    if (maps.isEmpty) return null;
    return ProductionBatch.fromMap(maps.first);
  }

  Future<List<ProductionBatch>> getProductionBatchesByDate(String date) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query(
      'production_batches',
      where: 'user_id = ? AND production_date = ?',
      whereArgs: [_currentUserId, date],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => ProductionBatch.fromMap(m)).toList();
  }

  Future<List<ProductionBatch>> getProductionBatchesByDateRange(String fromDate, String toDate) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query(
      'production_batches',
      where: 'user_id = ? AND production_date >= ? AND production_date <= ?',
      whereArgs: [_currentUserId, fromDate, toDate],
      orderBy: 'production_date DESC, created_at DESC',
    );
    return maps.map((m) => ProductionBatch.fromMap(m)).toList();
  }

  Future<List<ProductionBatchRecipeItem>> getRecipeForBatch(int batchId) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query(
      'production_batch_recipe',
      where: 'batch_id = ? AND user_id = ?',
      whereArgs: [batchId, _currentUserId],
      orderBy: 'id ASC',
    );
    return maps.map((m) => ProductionBatchRecipeItem.fromMap(m)).toList();
  }

  Future<int> insertProductionBatchRecipeItem(ProductionBatchRecipeItem item) async {
    Database db = await database;
    final map = item.toMap()..remove('id');
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('production_batch_recipe', map);
  }

  Future<int> deleteProductionBatchRecipeItems(int batchId) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    return await db.delete(
      'production_batch_recipe',
      where: 'batch_id = ? AND user_id = ?',
      whereArgs: [batchId, _currentUserId],
    );
  }

  Future<int> updateProductionBatch(ProductionBatch batch) async {
    if (batch.id == null || _currentUserId == null) return 0;
    Database db = await database;
    return await db.update(
      'production_batches',
      batch.toMap()..remove('id'),
      where: 'id = ? AND user_id = ?',
      whereArgs: [batch.id, _currentUserId],
    );
  }

  Future<int> deleteProductionBatch(int id) async {
    Database db = await database;
    if (_currentUserId == null) return 0;
    await db.delete('production_batch_recipe', where: 'batch_id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
    return await db.delete('production_batches', where: 'id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
  }

  // ---------- Palety (Expedícia) ----------
  Future<int> insertPallet(Pallet pallet) async {
    Database db = await database;
    final map = pallet.toMap()
      ..remove('id')
      ..['created_at'] = pallet.createdAt ?? DateTime.now().toIso8601String();
    if (_currentUserId != null) map['user_id'] = _currentUserId;
    return await db.insert('pallets', map);
  }

  Future<Pallet?> getPalletById(int id) async {
    Database db = await database;
    if (_currentUserId == null) return null;
    final maps = await db.query('pallets', where: 'id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
    if (maps.isEmpty) return null;
    return Pallet.fromMap(maps.first);
  }

  Future<List<Pallet>> getPalletsByBatchId(int batchId) async {
    Database db = await database;
    if (_currentUserId == null) return [];
    final maps = await db.query(
      'pallets',
      where: 'batch_id = ? AND user_id = ?',
      whereArgs: [batchId, _currentUserId],
      orderBy: 'id ASC',
    );
    return maps.map((m) => Pallet.fromMap(m)).toList();
  }

  Future<int> updatePallet(Pallet pallet) async {
    if (pallet.id == null || _currentUserId == null) return 0;
    Database db = await database;
    return await db.update(
      'pallets',
      pallet.toMap()..remove('id'),
      where: 'id = ? AND user_id = ?',
      whereArgs: [pallet.id, _currentUserId],
    );
  }

  /// Priradí paletu zákazníkovi: status U zákazníka, zvýši customer.palletBalance o 1.
  Future<void> assignPalletToCustomer(int palletId, int customerId) async {
    Database db = await database;
    final pallet = await getPalletById(palletId);
    final customer = await getCustomerById(customerId);
    if (pallet == null || customer == null) return;
    if (_currentUserId == null) return;
    await db.update(
      'pallets',
      {
        'customer_id': customerId,
        'status': PalletStatus.uZakaznika.label,
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [palletId, _currentUserId],
    );
    await db.update(
      'customers',
      {'pallet_balance': (customer.palletBalance + 1)},
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  /// Nahradí lokálne šarže recepty a palety dátami z backendu. Vkladá s user_id = _currentUserId.
  Future<void> replaceBatchesFromBackend(List<Map<String, dynamic>> batches) async {
    if (_currentUserId == null) return;
    final db = await database;
    await db.delete('production_batch_recipe', where: 'user_id = ?', whereArgs: [_currentUserId]);
    await db.delete('pallets', where: 'user_id = ?', whereArgs: [_currentUserId]);
    await db.delete('production_batches', where: 'user_id = ?', whereArgs: [_currentUserId]);
    if (batches.isEmpty) return;
    for (final b in batches) {
      final batchId = b['id'] as int?;
      if (batchId == null) continue;
      final productionDate = (b['production_date'] as String?) ?? '';
      final productType = (b['product_type'] as String?) ?? '';
      final quantityProduced = (b['quantity_produced'] as num?)?.toInt() ?? 0;
      await db.insert('production_batches', {
        'id': batchId,
        'user_id': _currentUserId,
        'production_date': productionDate,
        'product_type': productType,
        'quantity_produced': quantityProduced,
        'notes': b['notes'],
        'created_at': b['created_at']?.toString(),
        'cost_total': (b['cost_total'] as num?)?.toDouble(),
        'revenue_total': (b['revenue_total'] as num?)?.toDouble(),
      });
      final recipe = b['recipe'] as List<dynamic>? ?? [];
      for (final r in recipe) {
        final map = Map<String, dynamic>.from(r as Map);
        final qty = (map['quantity'] as num?)?.toDouble() ?? 0;
        if (qty <= 0) continue;
        await db.insert('production_batch_recipe', {
          'user_id': _currentUserId,
          'batch_id': batchId,
          'material_name': (map['material_name'] as String?) ?? '',
          'quantity': qty,
          'unit': (map['unit'] as String?) ?? 'kg',
        });
      }
      final pallets = b['pallets'] as List<dynamic>? ?? [];
      for (final p in pallets) {
        final map = Map<String, dynamic>.from(p as Map);
        final palletId = map['id'] as int?;
        if (palletId == null) continue;
        await db.insert('pallets', {
          'id': palletId,
          'user_id': _currentUserId,
          'batch_id': batchId,
          'product_type': (map['product_type'] as String?) ?? '',
          'quantity': (map['quantity'] as num?)?.toInt() ?? 0,
          'customer_id': map['customer_id'] as int?,
          'status': (map['status'] as String?) ?? 'Na sklade',
          'created_at': map['created_at']?.toString(),
        });
      }
    }
  }

  /// Zníži zákazníkovi palletBalance o [count]. Neprebieha zmena stavu paliet (len bilancia).
  Future<void> returnPalletsForCustomer(int customerId, int count) async {
    if (count <= 0) return;
    Database db = await database;
    final customer = await getCustomerById(customerId);
    if (customer == null) return;
    final newBalance = (customer.palletBalance - count).clamp(0, 0x7fffffff);
    if (_currentUserId == null) return;
    await db.update(
      'customers',
      {'pallet_balance': newBalance},
      where: 'id = ? AND user_id = ?',
      whereArgs: [customerId, _currentUserId],
    );
  }
}
