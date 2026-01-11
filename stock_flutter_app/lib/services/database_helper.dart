import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart' as model;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'stock_portfolio.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createTransactionsTable(db);
        await _createSettingsTable(db);
        await _createStockSymbolsTable(db);
        await _createStockPricesTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createSettingsTable(db);
        }
        if (oldVersion < 3) {
          await _createStockSymbolsTable(db);
        }
        if (oldVersion < 4) {
          await _createStockPricesTable(db);
        }
      },
    );
  }

  Future<void> _createTransactionsTable(Database db) async {
    await db.execute('''
          CREATE TABLE transactions(
            id TEXT PRIMARY KEY,
            symbol TEXT,
            date TEXT,
            type TEXT,
            shares INTEGER,
            price REAL
          )
        ''');
  }

  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<void> _createStockSymbolsTable(Database db) async {
    await db.execute('''
      CREATE TABLE stock_symbols(
        symbol TEXT PRIMARY KEY,
        name TEXT,
        type TEXT
      )
    ''');
  }

  Future<void> _createStockPricesTable(Database db) async {
    await db.execute('''
      CREATE TABLE latest_stock_prices(
        symbol TEXT PRIMARY KEY,
        regularMarketPrice REAL,
        regularMarketChange REAL,
        regularMarketChangePercent REAL,
        shortName TEXT,
        longName TEXT,
        lastUpdated INTEGER
      )
    ''');
  }

  Future<void> saveApiKey(String key) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': 'fugle_api_key', 'value': key},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getApiKey() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['fugle_api_key'],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  Future<void> setLastSyncTime(int timestamp) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': 'last_stock_sync_time', 'value': timestamp.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int?> getLastSyncTime() async {
    final db = await database;
    final maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['last_stock_sync_time'],
    );
    if (maps.isNotEmpty && maps.first['value'] != null) {
      return int.tryParse(maps.first['value'] as String);
    }
    return null;
  }

  Future<int> insertTransaction(model.Transaction t) async {
    final db = await database;
    return await db.insert(
      'transactions',
      t.toJson(), // We can reuse toJson if it matches our table columns
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<model.Transaction>> getTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('transactions');
    return List.generate(maps.length, (i) {
      return model.Transaction.fromJson(maps[i]);
    });
  }

  Future<int> updateTransaction(model.Transaction t) async {
    final db = await database;
    return await db.update(
      'transactions',
      t.toJson(),
      where: 'id = ?',
      whereArgs: [t.id],
    );
  }

  Future<int> deleteTransaction(String id) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Stock Symbol Methods ---

  Future<void> batchInsertStockSymbols(
      List<Map<String, dynamic>> stocks) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var s in stocks) {
        batch.insert('stock_symbols', s,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> searchLocalSymbols(String query) async {
    final db = await database;
    return await db.query(
      'stock_symbols',
      where: 'symbol LIKE ? OR name LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 20,
    );
  }

  Future<int> getStockSymbolCount() async {
    final db = await database;
    // Use rawQuery for count
    final x = await db.rawQuery('SELECT COUNT(*) FROM stock_symbols');
    return Sqflite.firstIntValue(x) ?? 0;
  }

  // --- Latest Stock Prices Methods ---

  Future<void> upsertStockPrices(List<dynamic> stocks) async {
    // Accepts List<StockData>, using dynamic to avoid circular dependency if possible,
    // but better to import model. We already import 'transaction.dart' as model.
    // We should probably import stock.dart in this file or pass Maps.
    // Let's assume the caller converts to Map or we cast.
    // Actually, let's just take List<Map<String, dynamic>> to be safe and clean.
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var s in stocks) {
        // s can be StockData object. Let's make the signature accept list of Maps.
        // Caller (Provider) will convert StockData to Map.
        Map<String, dynamic> data = s; 
        data['lastUpdated'] = now;
        batch.insert('latest_stock_prices', data,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> getLatestStockPrices() async {
    final db = await database;
    return await db.query('latest_stock_prices');
  }
}
