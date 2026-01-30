import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../Models/product.dart';
import '../Models/user.dart';

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
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> initializeWithAdmin(User admin) async {
    String basePath = _customPath ?? await getDatabasesPath();
    String path = join(basePath, 'stock_pilot.db');
    
    // Pred inicializáciou sa uistíme, že všetko je zatvorené
    if (_database != null) {
      await _database!.close();
      _database = null;
      _dbFuture = null;
    }

    // Aby sme sa vyhli chybe "Cannot delete file because it is being used",
    // radšej databázu len otvoríme a preformátujeme tabuľky ak existuje,
    // alebo ju vymažeme len ak nie je zamknutá.
    try {
      if (await File(path).exists()) {
        await File(path).delete();
      }
    } catch (e) {
      print("Warning: Could not delete old DB file (maybe locked), clearing tables instead: $e");
    }

    Database db = await database;
    
    // Vyčistíme tabuľku používateľov a vložíme nového admina
    await db.delete('users');
    await db.insert('users', admin.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Pridáme aj predvoleného skladníka, aby sa dalo testovať
    await db.insert('users', User(
      username: 'skladnik',
      password: 'user123',
      fullName: 'Ján Skladník',
      role: 'user',
      email: 'jan@stockpilot.sk',
      phone: '+421 900 333 444',
      department: 'Skladové oddelenie',
      avatarUrl: 'https://i.pravatar.cc/150?u=skladnik',
      joinDate: DateTime.now(),
    ).toMap());
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
      // Check if password column exists before adding it
      var tableInfo = await db.rawQuery('PRAGMA table_info(users)');
      bool hasPassword = tableInfo.any((column) => column['name'] == 'password');
      
      if (!hasPassword) {
        await db.execute('ALTER TABLE users ADD COLUMN password TEXT');
        // Set default passwords for existing users
        await db.update('users', {'password': 'password123'});
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
        last_purchase_date TEXT,
        currency TEXT,
        location TEXT
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

    await _insertSampleProducts(db);
    await _insertSampleUsers(db);
  }

  Future<void> _insertSampleProducts(Database db) async {
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
      await db.insert('products', product.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _insertSampleUsers(Database db) async {
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
      await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
    return await db.delete(
      'products',
      where: 'unique_id = ?',
      whereArgs: [id],
    );
  }

  // Helper method for dashboard stats
  Future<Map<String, dynamic>> getDashboardStats() async {
    Database db = await database;
    
    final productCountResult = await db.rawQuery('SELECT COUNT(*) as count FROM products');
    int productCount = Sqflite.firstIntValue(productCountResult) ?? 0;
    
    // For now, these are mocked since we don't have orders/customers tables yet
    // but we can structure the query if we had them.
    return {
      'products': productCount,
      'orders': 150, // Mocked
      'customers': 45, // Mocked
      'revenue': 12450.0, // Mocked
      'inboundCount': 24, // Mocked
      'outboundCount': 12, // Mocked
    };
  }
}

