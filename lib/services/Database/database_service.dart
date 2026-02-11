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
import '../../models/transport.dart';
import '../../models/user.dart';
import '../../models/warehouse.dart';
import '../../models/warehouse_transfer.dart';
import '../../models/stock_out.dart';
import '../../models/product_kind.dart';

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
    return await openDatabase(
      path,
      version: 27,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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

    await db.insert(
      'users',
      User(
        username: 'skladnik',
        password: 'user123',
        fullName: 'Ján Skladník',
        role: 'user',
        email: 'jan@stockpilot.sk',
        phone: '+421 900 333 444',
        department: 'Skladové oddelenie',
        avatarUrl: 'https://i.pravatar.cc/150?u=skladnik',
        joinDate: DateTime.now(),
      ).toMap(),
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Verzia 27: doplnenie chýbajúcich tabuliek (stock_outs, warehouse_transfers) pre DB vytvorené starším kódom
    if (oldVersion < 27) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_outs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_number TEXT UNIQUE NOT NULL,
          created_at TEXT NOT NULL,
          recipient_name TEXT,
          notes TEXT,
          username TEXT,
          status TEXT NOT NULL DEFAULT 'vykazana',
          vat_rate INTEGER,
          issue_type TEXT DEFAULT 'SALE',
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
          FOREIGN KEY (stock_out_id) REFERENCES stock_outs(id),
          FOREIGN KEY (product_unique_id) REFERENCES products(unique_id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS warehouse_transfers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          from_warehouse_id INTEGER NOT NULL,
          to_warehouse_id INTEGER NOT NULL,
          product_unique_id TEXT NOT NULL,
          product_name TEXT,
          product_plu TEXT,
          quantity INTEGER NOT NULL,
          unit TEXT NOT NULL DEFAULT 'ks',
          created_at TEXT NOT NULL,
          notes TEXT,
          username TEXT,
          FOREIGN KEY (from_warehouse_id) REFERENCES warehouses(id),
          FOREIGN KEY (to_warehouse_id) REFERENCES warehouses(id)
        )
      ''');
    }
    if (oldVersion < 26) {
      final productsInfo = await db.rawQuery('PRAGMA table_info(products)');
      final hasWarehouseId = productsInfo.any((c) => (c['name'] as String?) == 'warehouse_id');
      if (!hasWarehouseId) {
        await db.execute('ALTER TABLE products ADD COLUMN warehouse_id INTEGER REFERENCES warehouses(id)');
      }
    }
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

    if (oldVersion < 18) {
      final whInfo = await db.rawQuery('PRAGMA table_info(warehouses)');
      final hasWarehouseType =
          whInfo.any((c) => (c['name'] as String?) == 'warehouse_type');
      if (!hasWarehouseType) {
        await db.execute(
          "ALTER TABLE warehouses ADD COLUMN warehouse_type TEXT DEFAULT 'Predaj'",
        );
      }
    }

    if (oldVersion < 25) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS product_kinds (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE
        )
      ''');
      final productsInfo = await db.rawQuery('PRAGMA table_info(products)');
      final hasKindId = productsInfo.any((c) => (c['name'] as String?) == 'kind_id');
      if (!hasKindId) {
        await db.execute('ALTER TABLE products ADD COLUMN kind_id INTEGER REFERENCES product_kinds(id)');
      }
    }

    if (oldVersion < 24) {
      final productsInfo = await db.rawQuery('PRAGMA table_info(products)');
      final hasLastPurchasePriceWithoutVat = productsInfo.any(
          (c) => (c['name'] as String?) == 'last_purchase_price_without_vat');
      if (!hasLastPurchasePriceWithoutVat) {
        await db.execute(
            "ALTER TABLE products ADD COLUMN last_purchase_price_without_vat REAL DEFAULT 0.0");
      }
    }

    if (oldVersion < 23) {
      final productsInfo = await db.rawQuery('PRAGMA table_info(products)');
      final hasSupplierName = productsInfo.any((c) => (c['name'] as String?) == 'supplier_name');
      if (!hasSupplierName) {
        await db.execute("ALTER TABLE products ADD COLUMN supplier_name TEXT");
      }
    }

    if (oldVersion < 22) {
      final stockOutsInfo = await db.rawQuery('PRAGMA table_info(stock_outs)');
      final hasIssueType = stockOutsInfo.any((c) => (c['name'] as String?) == 'issue_type');
      if (!hasIssueType) {
        await db.execute("ALTER TABLE stock_outs ADD COLUMN issue_type TEXT DEFAULT 'SALE'");
      }
      final hasWriteOffReason = stockOutsInfo.any((c) => (c['name'] as String?) == 'write_off_reason');
      if (!hasWriteOffReason) {
        await db.execute('ALTER TABLE stock_outs ADD COLUMN write_off_reason TEXT');
      }
    }

    if (oldVersion < 21) {
      final stockOutsInfo = await db.rawQuery('PRAGMA table_info(stock_outs)');
      final hasVatRate = stockOutsInfo.any((c) => (c['name'] as String?) == 'vat_rate');
      if (!hasVatRate) {
        await db.execute('ALTER TABLE stock_outs ADD COLUMN vat_rate INTEGER');
      }
    }

    if (oldVersion < 20) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_outs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_number TEXT UNIQUE NOT NULL,
          created_at TEXT NOT NULL,
          recipient_name TEXT,
          notes TEXT,
          username TEXT,
          status TEXT NOT NULL DEFAULT 'vykazana',
          vat_rate INTEGER,
          issue_type TEXT DEFAULT 'SALE',
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
          FOREIGN KEY (stock_out_id) REFERENCES stock_outs(id),
          FOREIGN KEY (product_unique_id) REFERENCES products(unique_id)
        )
      ''');
    }

    if (oldVersion < 19) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS warehouse_transfers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          from_warehouse_id INTEGER NOT NULL,
          to_warehouse_id INTEGER NOT NULL,
          product_unique_id TEXT NOT NULL,
          product_name TEXT,
          product_plu TEXT,
          quantity INTEGER NOT NULL,
          unit TEXT NOT NULL DEFAULT 'ks',
          created_at TEXT NOT NULL,
          notes TEXT,
          username TEXT,
          FOREIGN KEY (from_warehouse_id) REFERENCES warehouses(id),
          FOREIGN KEY (to_warehouse_id) REFERENCES warehouses(id)
        )
      ''');
    }

    if (oldVersion < 17) {
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
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_kinds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
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
        FOREIGN KEY (kind_id) REFERENCES product_kinds(id)
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
        warehouse_type TEXT NOT NULL DEFAULT 'Predaj',
        address TEXT,
        city TEXT,
        postal_code TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_outs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_number TEXT UNIQUE NOT NULL,
        created_at TEXT NOT NULL,
        recipient_name TEXT,
        notes TEXT,
        username TEXT,
        status TEXT NOT NULL DEFAULT 'vykazana',
        vat_rate INTEGER,
        issue_type TEXT DEFAULT 'SALE',
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
        FOREIGN KEY (stock_out_id) REFERENCES stock_outs(id),
        FOREIGN KEY (product_unique_id) REFERENCES products(unique_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouse_transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_warehouse_id INTEGER NOT NULL,
        to_warehouse_id INTEGER NOT NULL,
        product_unique_id TEXT NOT NULL,
        product_name TEXT,
        product_plu TEXT,
        quantity INTEGER NOT NULL,
        unit TEXT NOT NULL DEFAULT 'ks',
        created_at TEXT NOT NULL,
        notes TEXT,
        username TEXT,
        FOREIGN KEY (from_warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY (to_warehouse_id) REFERENCES warehouses(id)
      )
    ''');

    await _insertSampleProducts(db);
    await _insertSampleUsers(db);
  }

  Future<void> _insertSampleProducts(Database db) async {
    // Skontroluj, či už existujú produkty v databáze
    final existingProducts = await db.query('products');
    if (existingProducts.isNotEmpty) {
      print('Databáza už obsahuje produkty, preskakujem vloženie testovacích dát.');
      return;
    }

    final List<Product> sampleProducts = [
      Product(
        uniqueId: 'uuid-1',
        name: 'iPhone 15 Pro',
        plu: '1005',
        category: 'Sklad',
        qty: 12,
        unit: 'ks',
        price: 999.00,
        withoutVat: 832.50,
        vat: 20,
        discount: 0,
        lastPurchasePrice: 15.20,
        lastPurchaseDate: '2025-10-15',
        currency: 'EUR',
        location: 'A-12-04',
      ),
      Product(
        uniqueId: 'uuid-2',
        name: 'MacBook Air M2',
        plu: '1008',
        category: 'Výroba',
        qty: 5,
        unit: 'ks',
        price: 1249.50,
        withoutVat: 1041.25,
        vat: 20,
        discount: 0,
        lastPurchasePrice: 15.20,
        lastPurchaseDate: '2025-10-15',
        currency: 'EUR',
        location: 'B-01-02',
      ),
    ];

    for (var product in sampleProducts) {
      await db.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _insertSampleUsers(Database db) async {
    // Skontroluj, či už existujú používatelia v databáze
    final existingUsers = await db.query('users');
    if (existingUsers.isNotEmpty) {
      print('Databáza už obsahuje používateľov, preskakujem vloženie testovacích dát.');
      return;
    }

    final List<User> sampleUsers = [
      User(
        username: 'admin',
        password: 'admin123',
        fullName: 'Pavol Administrátor',
        role: 'admin',
        email: 'admin@stockpilot.sk',
        phone: '+421 900 111 222',
        department: 'IT a Správa',
        avatarUrl: 'https://i.pravatar.cc/150?u=admin',
        joinDate: DateTime(2023, 1, 1),
      ),
      User(
        username: 'skladnik',
        password: 'user123',
        fullName: 'Ján Skladník',
        role: 'user',
        email: 'jan@stockpilot.sk',
        phone: '+421 900 333 444',
        department: 'Skladové oddelenie',
        avatarUrl: 'https://i.pravatar.cc/150?u=skladnik',
        joinDate: DateTime(2023, 6, 15),
      ),
    ];

    for (var user in sampleUsers) {
      await db.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
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

  Future<int> updateUser(User user) async {
    Database db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
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

  /// Produkty priradené danému skladu (podľa warehouse_id).
  Future<List<Product>> getProductsByWarehouseId(int warehouseId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'warehouse_id = ?',
      whereArgs: [warehouseId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  /// Aktualizuje množstva produktov po inventúre. [changes]: unique_id -> nové množstvo.
  Future<void> updateStockAfterAudit(
    int warehouseId,
    Map<String, int> changes,
  ) async {
    if (changes.isEmpty) return;
    final db = await database;
    for (final entry in changes.entries) {
      await db.update(
        'products',
        {'qty': entry.value},
        where: 'unique_id = ? AND warehouse_id = ?',
        whereArgs: [entry.key, warehouseId],
      );
    }
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

  // Product kinds (Druhy produktov)
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
    return await db.update(
      'product_kinds',
      kind.toMap(),
      where: 'id = ?',
      whereArgs: [kind.id],
    );
  }

  Future<int> deleteProductKind(int id) async {
    Database db = await database;
    await db.update('products', {'kind_id': null}, where: 'kind_id = ?', whereArgs: [id]);
    return await db.delete('product_kinds', where: 'id = ?', whereArgs: [id]);
  }

  // Inbound receipts
  Future<int> insertInboundReceipt(InboundReceipt receipt) async {
    Database db = await database;
    return await db.insert('inbound_receipts', receipt.toMap());
  }

  Future<List<InboundReceipt>> getInboundReceipts() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inbound_receipts',
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => InboundReceipt.fromMap(m)).toList();
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

  // Warehouse transfers
  Future<int> insertWarehouseTransfer(WarehouseTransfer t) async {
    Database db = await database;
    return await db.insert('warehouse_transfers', t.toMap());
  }

  Future<List<WarehouseTransfer>> getWarehouseTransfers() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'warehouse_transfers',
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => WarehouseTransfer.fromMap(m)).toList();
  }

  // Stock out (výdajky)
  Future<int> insertStockOut(StockOut stockOut) async {
    Database db = await database;
    return await db.insert('stock_outs', stockOut.toMap());
  }

  Future<List<StockOut>> getStockOuts() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'stock_outs',
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => StockOut.fromMap(m)).toList();
  }

  Future<StockOut?> getStockOutById(int id) async {
    Database db = await database;
    final maps = await db.query(
      'stock_outs',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return StockOut.fromMap(maps.first);
  }

  Future<List<StockOutItem>> getStockOutItems(int stockOutId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'stock_out_items',
      where: 'stock_out_id = ?',
      whereArgs: [stockOutId],
    );
    return maps.map((m) => StockOutItem.fromMap(m)).toList();
  }

  Future<int> insertStockOutItem(StockOutItem item) async {
    Database db = await database;
    return await db.insert('stock_out_items', item.toMap());
  }

  Future<int> updateStockOut(StockOut stockOut) async {
    Database db = await database;
    return await db.update(
      'stock_outs',
      stockOut.toMap(),
      where: 'id = ?',
      whereArgs: [stockOut.id],
    );
  }

  Future<int> updateStockOutStatus(int id, StockOutStatus status) async {
    Database db = await database;
    return await db.update(
      'stock_outs',
      {'status': status.value},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteStockOutItemsByStockOutId(int stockOutId) async {
    Database db = await database;
    return await db.delete(
      'stock_out_items',
      where: 'stock_out_id = ?',
      whereArgs: [stockOutId],
    );
  }

  Future<String> getNextStockOutNumber() async {
    Database db = await database;
    final year = DateTime.now().year;
    final prefix = 'VD-$year-';
    final result = await db.rawQuery(
      'SELECT document_number FROM stock_outs WHERE document_number LIKE ? ORDER BY id DESC LIMIT 1',
      ['$prefix%'],
    );
    if (result.isEmpty) return '${prefix}0001';
    final last = result.first['document_number'] as String;
    final numPart = last.replaceFirst(prefix, '');
    final next = (int.tryParse(numPart) ?? 0) + 1;
    return '$prefix${next.toString().padLeft(4, '0')}';
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

  /// Počet produktov (druhov) na sklad – podľa warehouse_id v produktoch.
  Future<Map<int, int>> getProductCountPerWarehouse() async {
    Database db = await database;
    final rows = await db.rawQuery(
      'SELECT warehouse_id, COUNT(*) as cnt FROM products WHERE warehouse_id IS NOT NULL GROUP BY warehouse_id',
    );
    final map = <int, int>{};
    for (final r in rows) {
      final id = r['warehouse_id'] as int?;
      if (id != null) map[id] = (r['cnt'] as int?) ?? 0;
    }
    return map;
  }

  Future<List<Warehouse>> getWarehouses() async {
    Database db = await database;
    final maps = await db.query('warehouses', orderBy: 'name ASC');
    return maps.map((m) => Warehouse.fromMap(m)).toList();
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

    // Počet výdajok
    final outboundCountResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM stock_outs',
    );
    int outboundCount = Sqflite.firstIntValue(outboundCountResult) ?? 0;

    // Výpočet tržieb z quotes (súčet celkových súm s DPH)
    double revenue = 0.0;
    try {
      final revenueResult = await db.rawQuery('''
        SELECT SUM(
          (SELECT SUM(qi.quantity * qi.price_per_unit * (1 + qi.vat_rate / 100.0))
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
      // Ak výpočet zlyhá, revenue zostane 0
      revenue = 0.0;
    }

    return {
      'products': productCount,
      'orders': quotesCount, // Používame quotes ako objednávky
      'customers': customerCount,
      'revenue': revenue,
      'inboundCount': inboundCount,
      'outboundCount': outboundCount,
      'quotesCount': quotesCount,
    };
  }

  /// Posledné príjemky s celkovou sumou (created_at, total).
  Future<List<Map<String, dynamic>>> getRecentInboundReceiptsWithTotal(
      {int limit = 5}) async {
    Database db = await database;
    final rows = await db.rawQuery('''
      SELECT r.created_at as created_at,
             COALESCE(SUM(i.qty * i.unit_price), 0) as total
      FROM inbound_receipts r
      LEFT JOIN inbound_receipt_items i ON i.receipt_id = r.id
      GROUP BY r.id
      ORDER BY r.created_at DESC
      LIMIT ?
    ''', [limit]);
    return rows;
  }

  /// Posledné výdajky s celkovou sumou (created_at, total).
  Future<List<Map<String, dynamic>>> getRecentStockOutsWithTotal(
      {int limit = 5}) async {
    Database db = await database;
    final rows = await db.rawQuery('''
      SELECT s.created_at as created_at,
             COALESCE(SUM(i.qty * i.unit_price), 0) as total
      FROM stock_outs s
      LEFT JOIN stock_out_items i ON i.stock_out_id = s.id
      GROUP BY s.id
      ORDER BY s.created_at DESC
      LIMIT ?
    ''', [limit]);
    return rows;
  }

  // Transport operations
  Future<int> insertTransport(Transport transport) async {
    Database db = await database;
    return await db.insert('transports', transport.toMap());
  }

  Future<List<Transport>> getTransports() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transports',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) {
      return Transport.fromMap(maps[i]);
    });
  }

  Future<Transport?> getTransportById(int id) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transports',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Transport.fromMap(maps.first);
  }

  Future<int> deleteTransport(int id) async {
    Database db = await database;
    return await db.delete('transports', where: 'id = ?', whereArgs: [id]);
  }

  /// Vymaže všetky dáta z databázy (okrem používateľov). Len pre admin.
  /// Volajte po potvrdení cez UI.
  Future<void> clearAllData() async {
    final db = await database;
    await db.execute('DELETE FROM quote_items');
    await db.execute('DELETE FROM quotes');
    await db.execute('DELETE FROM inbound_receipt_items');
    await db.execute('DELETE FROM inbound_receipts');
    await db.execute('DELETE FROM stock_out_items');
    await db.execute('DELETE FROM stock_outs');
    await db.execute('DELETE FROM warehouse_transfers');
    await db.execute('DELETE FROM transports');
    await db.execute('DELETE FROM products');
    await db.execute('DELETE FROM product_kinds');
    await db.execute('DELETE FROM suppliers');
    await db.execute('DELETE FROM customers');
    await db.execute('DELETE FROM warehouses');
    await db.rawUpdate(
      'UPDATE company SET name = ?, address = ?, city = ?, postal_code = ?, country = ?, ico = ?, ic_dph = ?, phone = ?, email = ?, web = ?, iban = ?, swift = ?, bank_name = ?, account = ?, register_info = ?, logo_path = ? WHERE id = 1',
      ['Moja firma', null, null, null, null, null, null, null, null, null, null, null, null, null, null, null],
    );
  }

  // Zapamätanie prihlásenia (zapamätaj si) – ukladanie do SharedPreferences
  static const String _keyRememberMe = 'remember_me';
  static const String _keySavedUsername = 'saved_username';

  Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setBool(_keyRememberMe, true);
    } else {
      await prefs.remove(_keyRememberMe);
      await prefs.remove(_keySavedUsername);
    }
  }

  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? false;
  }

  Future<void> setSavedUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavedUsername, username);
  }

  Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySavedUsername);
  }

  /// Vymaže uložené prihlásenie (volať pri odhlásení).
  Future<void> clearSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRememberMe);
    await prefs.remove(_keySavedUsername);
  }
}
