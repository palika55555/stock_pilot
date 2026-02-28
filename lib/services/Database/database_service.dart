import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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
import '../../models/product_kind.dart';
import '../../models/receptura_polozka.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  static Future<Database>? _dbFuture;
  static String? _customPath;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<void> setCustomPath(String path) async {
    _customPath = path;
    _database = null;
    _dbFuture = null;
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
      version: 22,
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
        je_vysporiadana INTEGER NOT NULL DEFAULT 0
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
        FOREIGN KEY (receipt_id) REFERENCES inbound_receipts(id),
        FOREIGN KEY (product_unique_id) REFERENCES products(unique_id)
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
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getProducts() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    return List.generate(maps.length, (i) {
      return Product.fromMap(maps[i]);
    });
  }

  Future<Product?> getProductByUniqueId(String uniqueId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'unique_id = ?',
      whereArgs: [uniqueId],
    );
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  /// Vyhľadá produkt podľa EAN kódu (čiarový kód).
  Future<Product?> getProductByEan(String ean) async {
    if (ean.isEmpty) return null;
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'ean = ?',
      whereArgs: [ean.trim()],
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
    return await db.update(
      'products',
      product.toMap(),
      where: 'unique_id = ?',
      whereArgs: [product.uniqueId],
    );
  }

  Future<int> deleteProduct(String id) async {
    Database db = await database;
    return await db.delete('products', where: 'unique_id = ?', whereArgs: [id]);
  }

  /// Aktualizuje EAN lokálnych produktov podľa zoznamu z backendu (EAN priradené na webe).
  /// Aktualizuje len keď backend má neprázdny EAN – lokálny EAN sa nikdy nevyčistí z backendu.
  Future<void> updateProductEanFromBackend(List<Map<String, dynamic>> backendProducts) async {
    for (final map in backendProducts) {
      final uniqueId = map['unique_id'] as String?;
      if (uniqueId == null || uniqueId.isEmpty) continue;
      final eanRaw = map['ean'];
      final ean = eanRaw is String ? eanRaw.trim() : null;
      if (ean == null || ean.isEmpty) continue;
      final product = await getProductByUniqueId(uniqueId);
      if (product == null || product.ean == ean) continue;
      await updateProduct(product.copyWith(ean: ean));
    }
  }

  // Receptúra – zložky (suroviny) receptúry
  Future<List<RecepturaPolozka>> getRecepturaPolozky(String recepturaKartaId) async {
    Database db = await database;
    final maps = await db.query(
      'receptura_polozky',
      where: 'receptura_karta_id = ?',
      whereArgs: [recepturaKartaId],
    );
    return maps.map((m) => RecepturaPolozka.fromMap(m)).toList();
  }

  Future<int> insertRecepturaPolozka(RecepturaPolozka polozka, String recepturaKartaId) async {
    Database db = await database;
    return await db.insert(
      'receptura_polozky',
      polozka.toMap(recepturaKartaId: recepturaKartaId),
    );
  }

  Future<int> deleteRecepturaPolozkyByRecepturaKartaId(String recepturaKartaId) async {
    Database db = await database;
    return await db.delete(
      'receptura_polozky',
      where: 'receptura_karta_id = ?',
      whereArgs: [recepturaKartaId],
    );
  }

  // Inbound receipts
  Future<int> insertInboundReceipt(InboundReceipt receipt) async {
    Database db = await database;
    return await db.insert('inbound_receipts', receipt.toMap());
  }

  /// Príjemky zoradené od najnovších. Ak [warehouseId] je zadané, len príjemky daného skladu.
  Future<List<InboundReceipt>> getInboundReceipts({int? warehouseId}) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = warehouseId != null
        ? await db.query(
            'inbound_receipts',
            where: 'warehouse_id = ?',
            whereArgs: [warehouseId],
            orderBy: 'created_at DESC',
          )
        : await db.query(
            'inbound_receipts',
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
    final List<Map<String, dynamic>> maps = await db.query(
      'inbound_receipts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return InboundReceipt.fromMap(maps.first);
  }

  Future<List<InboundReceiptItem>> getInboundReceiptItems(int receiptId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inbound_receipt_items',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
    );
    return maps.map((m) => InboundReceiptItem.fromMap(m)).toList();
  }

  Future<int> insertInboundReceiptItem(InboundReceiptItem item) async {
    Database db = await database;
    return await db.insert('inbound_receipt_items', item.toMap());
  }

  Future<int> updateInboundReceipt(InboundReceipt receipt) async {
    Database db = await database;
    return await db.update(
      'inbound_receipts',
      receipt.toMap(),
      where: 'id = ?',
      whereArgs: [receipt.id],
    );
  }

  Future<int> updateInboundReceiptStatus(
    int id,
    InboundReceiptStatus status,
  ) async {
    Database db = await database;
    return await db.update(
      'inbound_receipts',
      {'status': status.value},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteInboundReceiptItemsByReceiptId(int receiptId) async {
    Database db = await database;
    return await db.delete(
      'inbound_receipt_items',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
    );
  }

  /// Vymaže príjemku a jej položky. Len neschválené príjemky.
  Future<int> deleteInboundReceipt(int receiptId) async {
    Database db = await database;
    final receipt = await getInboundReceiptById(receiptId);
    if (receipt == null || receipt.isApproved) return 0;
    await db.delete(
      'inbound_receipt_items',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
    );
    return await db.delete(
      'inbound_receipts',
      where: 'id = ?',
      whereArgs: [receiptId],
    );
  }

  /// História nákupných cien produktu z príjemok (vykázané + schválené).
  Future<List<Map<String, dynamic>>> getPurchasePriceHistory(
    String productUniqueId,
  ) async {
    Database db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT r.receipt_number, r.created_at, r.prices_include_vat,
             i.unit_price, i.qty, i.unit
      FROM inbound_receipt_items i
      JOIN inbound_receipts r ON i.receipt_id = r.id
      WHERE i.product_unique_id = ?
      ORDER BY r.created_at DESC
    ''',
      [productUniqueId],
    );
    return rows;
  }

  Future<String> getNextReceiptNumber() async {
    Database db = await database;
    final year = DateTime.now().year;
    final prefix = 'PR-$year-';
    final result = await db.rawQuery(
      'SELECT receipt_number FROM inbound_receipts WHERE receipt_number LIKE ? ORDER BY id DESC LIMIT 1',
      ['$prefix%'],
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
    return await db.insert('suppliers', supplier.toMap());
  }

  Future<List<Supplier>> getSuppliers() async {
    Database db = await database;
    final maps = await db.query('suppliers', orderBy: 'name ASC');
    return maps.map((m) => Supplier.fromMap(m)).toList();
  }

  Future<List<Supplier>> getActiveSuppliers() async {
    Database db = await database;
    final maps = await db.query(
      'suppliers',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
    return maps.map((m) => Supplier.fromMap(m)).toList();
  }

  Future<Supplier?> getSupplierById(int id) async {
    Database db = await database;
    final maps = await db.query('suppliers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Supplier.fromMap(maps.first);
  }

  Future<int> updateSupplier(Supplier supplier) async {
    if (supplier.id == null) return 0;
    Database db = await database;
    return await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  Future<int> deleteSupplier(int id) async {
    Database db = await database;
    return await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  // Customer CRUD
  Future<int> insertCustomer(Customer customer) async {
    Database db = await database;
    return await db.insert('customers', customer.toMap());
  }

  Future<List<Customer>> getCustomers() async {
    Database db = await database;
    final maps = await db.query('customers', orderBy: 'name ASC');
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<List<Customer>> getActiveCustomers() async {
    Database db = await database;
    final maps = await db.query(
      'customers',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    Database db = await database;
    final maps = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<int> updateCustomer(Customer customer) async {
    if (customer.id == null) return 0;
    Database db = await database;
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    Database db = await database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  /// Nahradí lokálnych zákazníkov zoznamom z backendu (napr. po úpravách na webe).
  /// Vymaže lokálne záznamy a vloží položky z [list]. Nikdy nevolajte s prázdnym zoznamom – dáta by sa v apke vymazali.
  Future<void> replaceCustomersFromBackend(List<Map<String, dynamic>> list) async {
    if (list.isEmpty) return;
    Database db = await database;
    await db.delete('customers');
    for (final map in list) {
      final c = Customer.fromMap(Map<String, dynamic>.from(map));
      await db.insert('customers', c.toMap());
    }
  }

  // Quote CRUD
  Future<String> getNextQuoteNumber() async {
    Database db = await database;
    final year = DateTime.now().year;
    final prefix = 'CP-$year-';
    final result = await db.rawQuery(
      'SELECT quote_number FROM quotes WHERE quote_number LIKE ? ORDER BY id DESC LIMIT 1',
      ['$prefix%'],
    );
    if (result.isEmpty) return '${prefix}0001';
    final last = result.first['quote_number'] as String;
    final numPart = last.replaceFirst(prefix, '');
    final next = (int.tryParse(numPart) ?? 0) + 1;
    return '$prefix${next.toString().padLeft(4, '0')}';
  }

  Future<int> insertQuote(Quote quote) async {
    Database db = await database;
    return await db.insert('quotes', quote.toMap());
  }

  Future<Quote?> getQuoteById(int id) async {
    Database db = await database;
    final maps = await db.query('quotes', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Quote.fromMap(maps.first);
  }

  Future<List<Quote>> getQuotes() async {
    Database db = await database;
    final maps = await db.query('quotes', orderBy: 'created_at DESC');
    return maps.map((m) => Quote.fromMap(m)).toList();
  }

  Future<List<Quote>> getQuotesByCustomerId(int customerId) async {
    Database db = await database;
    final maps = await db.query(
      'quotes',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Quote.fromMap(m)).toList();
  }

  Future<int> updateQuote(Quote quote) async {
    if (quote.id == null) return 0;
    Database db = await database;
    return await db.update(
      'quotes',
      quote.toMap(),
      where: 'id = ?',
      whereArgs: [quote.id],
    );
  }

  Future<int> deleteQuote(int id) async {
    Database db = await database;
    await db.delete('quote_items', where: 'quote_id = ?', whereArgs: [id]);
    return await db.delete('quotes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<QuoteItem>> getQuoteItems(int quoteId) async {
    Database db = await database;
    final maps = await db.query(
      'quote_items',
      where: 'quote_id = ?',
      whereArgs: [quoteId],
      orderBy: 'id ASC',
    );
    return maps.map((m) => QuoteItem.fromMap(m)).toList();
  }

  Future<int> insertQuoteItem(QuoteItem item) async {
    Database db = await database;
    return await db.insert('quote_items', item.toMap());
  }

  Future<int> updateQuoteItem(QuoteItem item) async {
    if (item.id == null) return 0;
    Database db = await database;
    return await db.update(
      'quote_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteQuoteItem(int id) async {
    Database db = await database;
    return await db.delete('quote_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteQuoteItemsByQuoteId(int quoteId) async {
    Database db = await database;
    return await db.delete(
      'quote_items',
      where: 'quote_id = ?',
      whereArgs: [quoteId],
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
    final maps = await db.query('warehouse_transfers', orderBy: 'created_at DESC');
    return maps.map((m) => WarehouseTransfer.fromMap(m)).toList();
  }

  Future<int> insertWarehouseTransfer(WarehouseTransfer transfer) async {
    Database db = await database;
    return await db.insert('warehouse_transfers', transfer.toMap());
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
      return await txn.insert('warehouse_transfers', transfer.toMap());
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

    // Počet produktov
    final productCountResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products',
    );
    int productCount = Sqflite.firstIntValue(productCountResult) ?? 0;

    // Počet zákazníkov
    final customerCountResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM customers',
    );
    int customerCount = Sqflite.firstIntValue(customerCountResult) ?? 0;

    // Počet quotes (ako objednávky)
    final quotesCountResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM quotes',
    );
    int quotesCount = Sqflite.firstIntValue(quotesCountResult) ?? 0;

    // Počet príjemiek
    final inboundCountResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM inbound_receipts',
    );
    int inboundCount = Sqflite.firstIntValue(inboundCountResult) ?? 0;

    // Počet výdajok (zatiaľ 0, keďže nemáme outbound_receipts tabuľku)
    int outboundCount = 0;

    // Výpočet tržieb z quotes (súčet celkových súm s DPH)
    double revenue = 0.0;
    try {
      final revenueResult = await db.rawQuery('''
        SELECT SUM(
          (SELECT SUM(qi.qty * qi.unit_price * (1 + qi.vat_percent / 100.0))
           FROM quote_items qi
           WHERE qi.quote_id = q.id)
        ) as total
        FROM quotes q
        WHERE q.status != 'draft'
      ''');
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
    final receipts = await db.query('inbound_receipts', orderBy: 'created_at DESC', limit: limit);
    final result = <Map<String, dynamic>>[];
    for (final r in receipts) {
      final items = await db.query('inbound_receipt_items', where: 'receipt_id = ?', whereArgs: [r['id']]);
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
    final outs = await db.query('stock_outs', orderBy: 'created_at DESC', limit: limit);
    final result = <Map<String, dynamic>>[];
    for (final o in outs) {
      final items = await db.query('stock_out_items', where: 'stock_out_id = ?', whereArgs: [o['id']]);
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
    await db.insert('transports', transport.toMap());
  }

  Future<List<StockOut>> getStockOuts() async {
    Database db = await database;
    final maps = await db.query('stock_outs', orderBy: 'created_at DESC');
    return maps.map((m) => StockOut.fromMap(m)).toList();
  }

  /// Výdajky pre daný sklad; ak [warehouseId] je null, vráti všetky.
  Future<List<StockOut>> getStockOutsByWarehouseId(int? warehouseId) async {
    Database db = await database;
    final maps = warehouseId == null
        ? await db.query('stock_outs', orderBy: 'created_at DESC')
        : await db.query(
            'stock_outs',
            where: 'warehouse_id = ?',
            whereArgs: [warehouseId],
            orderBy: 'created_at DESC',
          );
    return maps.map((m) => StockOut.fromMap(m)).toList();
  }

  Future<StockOut?> getStockOutById(int id) async {
    Database db = await database;
    final maps = await db.query('stock_outs', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return StockOut.fromMap(maps.first);
  }

  Future<List<StockOutItem>> getStockOutItems(int stockOutId) async {
    Database db = await database;
    final maps = await db.query('stock_out_items', where: 'stock_out_id = ?', whereArgs: [stockOutId]);
    return maps.map((m) => StockOutItem.fromMap(m)).toList();
  }

  Future<String> getNextStockOutNumber() async {
    Database db = await database;
    final year = DateTime.now().year;
    final prefix = 'VY-$year-';
    final result = await db.rawQuery('SELECT document_number FROM stock_outs WHERE document_number LIKE ? ORDER BY id DESC LIMIT 1', ['$prefix%']);
    if (result.isEmpty) return '${prefix}0001';
    final last = result.first['document_number'] as String;
    final next = (int.tryParse(last.replaceFirst(prefix, '')) ?? 0) + 1;
    return '$prefix${next.toString().padLeft(4, '0')}';
  }

  Future<int> insertStockOut(StockOut stockOut) async {
    Database db = await database;
    return await db.insert('stock_outs', stockOut.toMap());
  }

  Future<void> insertStockOutItem(StockOutItem item) async {
    Database db = await database;
    await db.insert('stock_out_items', item.toMap());
  }

  Future<void> deleteStockOutItemsByStockOutId(int stockOutId) async {
    Database db = await database;
    await db.delete('stock_out_items', where: 'stock_out_id = ?', whereArgs: [stockOutId]);
  }

  Future<int> updateStockOut(StockOut stockOut) async {
    if (stockOut.id == null) return 0;
    Database db = await database;
    return await db.update('stock_outs', stockOut.toMap(), where: 'id = ?', whereArgs: [stockOut.id]);
  }

  Future<void> updateStockOutStatus(int stockOutId, StockOutStatus status) async {
    Database db = await database;
    await db.update('stock_outs', {'status': status.value}, where: 'id = ?', whereArgs: [stockOutId]);
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
    final maps = await db.query(
      'stock_movements',
      where: 'stock_out_id = ?',
      whereArgs: [stockOutId],
    );
    return maps.map((m) => StockMovement.fromMap(m)).toList();
  }

  Future<int> insertStockMovement(StockMovement sm) async {
    Database db = await database;
    return await db.insert('stock_movements', sm.toMap());
  }

  Future<void> deleteStockMovementsByStockOutId(int stockOutId) async {
    Database db = await database;
    await db.delete('stock_movements', where: 'stock_out_id = ?', whereArgs: [stockOutId]);
  }

  /// Výdajové pohyby (z výdajok) s warehouse_id; ak [warehouseId] je zadané, len daný sklad.
  Future<List<WarehouseMovementRecord>> getStockMovementRecordsOut({int? warehouseId}) async {
    Database db = await database;
    final sql = '''
      SELECT sm.id, sm.document_number, sm.created_at, sm.product_unique_id, sm.product_name, sm.plu, sm.qty, sm.unit, sm.direction, so.warehouse_id
      FROM stock_movements sm
      JOIN stock_outs so ON sm.stock_out_id = so.id
      ${warehouseId != null ? 'WHERE so.warehouse_id = ?' : ''}
      ORDER BY sm.created_at DESC
    ''';
    final maps = warehouseId != null
        ? await db.rawQuery(sql, [warehouseId])
        : await db.rawQuery(sql);
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
    final sql = '''
      SELECT i.id, r.receipt_number AS document_number, r.created_at, i.product_unique_id, i.product_name, i.plu, i.qty, i.unit, r.warehouse_id
      FROM inbound_receipt_items i
      JOIN inbound_receipts r ON i.receipt_id = r.id
      ${warehouseId != null ? 'WHERE r.warehouse_id = ?' : ''}
      ORDER BY r.created_at DESC
    ''';
    final maps = warehouseId != null
        ? await db.rawQuery(sql, [warehouseId])
        : await db.rawQuery(sql);
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
}
