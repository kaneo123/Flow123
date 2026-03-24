import 'dart:convert';
import 'dart:io' show Platform;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

/// SQLite database for offline data storage
/// Uses sqflite_ffi for desktop/mobile and sqflite_ffi_web for web
class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  static Database? _database;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String dbPath;
    
    if (kIsWeb) {
      // Web: Use FFI web adapter
      databaseFactory = databaseFactoryFfiWeb;
      dbPath = 'flowtill.db';
      debugPrint('📊 AppDatabase: Initializing WEB SQLite (IndexedDB)');
    } else {
      // Check if desktop (Windows/macOS/Linux) or mobile (Android/iOS)
      final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
      
      if (isDesktop) {
        // Desktop: Use FFI backend
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        dbPath = join(await getDatabasesPath(), 'flowtill.db');
        debugPrint('📊 AppDatabase: Initializing DESKTOP SQLite (FFI)');
        debugPrint('   Path: $dbPath');
      } else {
        // Android/iOS: Use native sqflite (default factory)
        // DO NOT set databaseFactory - use platform default
        final appDocDir = await getApplicationDocumentsDirectory();
        dbPath = join(appDocDir.path, 'flowtill.db');
        debugPrint('📊 AppDatabase: Initializing MOBILE SQLite (native)');
        debugPrint('   Path: $dbPath');
      }
    }
    
    return await openDatabase(
      dbPath,
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Products table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category_id TEXT NOT NULL,
        price REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        has_stock INTEGER NOT NULL DEFAULT 0,
        stock_quantity REAL NOT NULL DEFAULT 0,
        tax_rate_id TEXT,
        image_url TEXT,
        color TEXT,
        is_carvery INTEGER NOT NULL DEFAULT 0,
        printer_id TEXT,
        course TEXT,
        plu TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        color TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Staff table (has outlet_id for legacy compatibility + uses staff_outlets junction table)
    await db.execute('''
      CREATE TABLE staff (
        id TEXT PRIMARY KEY,
        outlet_id TEXT,
        full_name TEXT NOT NULL,
        pin_code TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        associated_outlets TEXT,
        role_id TEXT,
        permission_level INTEGER,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Staff outlets junction table (many-to-many relationship)
    await db.execute('''
      CREATE TABLE staff_outlets (
        id TEXT PRIMARY KEY,
        staff_id TEXT NOT NULL,
        outlet_id TEXT NOT NULL,
        role_id TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        UNIQUE(staff_id, outlet_id)
      )
    ''');

    // Printers table
    await db.execute('''
      CREATE TABLE printers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        ip_address TEXT NOT NULL,
        port INTEGER NOT NULL,
        printer_type TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        print_receipt INTEGER NOT NULL DEFAULT 0,
        print_kitchen INTEGER NOT NULL DEFAULT 0,
        assigned_categories TEXT,
        code_page TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Outlets table
    await db.execute('''
      CREATE TABLE outlets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        settings TEXT,
        enable_service_charge INTEGER NOT NULL DEFAULT 0,
        service_charge_percent REAL NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Outlet settings table
    await db.execute('''
      CREATE TABLE outlet_settings (
        outlet_id TEXT PRIMARY KEY,
        currency TEXT NOT NULL,
        tax_inclusive INTEGER NOT NULL DEFAULT 1,
        receipt_footer TEXT,
        receipt_codepage TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Tax rates table
    await db.execute('''
      CREATE TABLE tax_rates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        rate REAL NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Promotions table
    await db.execute('''
      CREATE TABLE promotions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        promotion_type TEXT NOT NULL,
        discount_value REAL NOT NULL,
        discount_type TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        start_date INTEGER,
        end_date INTEGER,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Promotion products junction table
    await db.execute('''
      CREATE TABLE promotion_products (
        promotion_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        PRIMARY KEY (promotion_id, product_id)
      )
    ''');

    // Promotion categories junction table
    await db.execute('''
      CREATE TABLE promotion_categories (
        promotion_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        PRIMARY KEY (promotion_id, category_id)
      )
    ''');

    // Orders table
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        table_id TEXT,
        staff_id TEXT,
        status TEXT NOT NULL,
        order_type TEXT NOT NULL,
        items TEXT NOT NULL,
        subtotal REAL NOT NULL,
        tax_total REAL NOT NULL,
        discount_total REAL NOT NULL,
        total REAL NOT NULL,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        synced_at INTEGER
      )
    ''');

    // Outbox queue for offline changes
    await db.execute('''
      CREATE TABLE outbox_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Till adjustments table
    await db.execute('''
      CREATE TABLE till_adjustments (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        staff_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        amount_pennies INTEGER NOT NULL,
        adjustment_type TEXT NOT NULL,
        reason TEXT NOT NULL,
        notes TEXT
      )
    ''');

    // Trading days table
    await db.execute('''
      CREATE TABLE trading_days (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        trading_date INTEGER NOT NULL,
        opened_at INTEGER NOT NULL,
        opened_by_staff_id TEXT NOT NULL,
        opening_float_amount REAL NOT NULL,
        opening_float_source TEXT NOT NULL,
        closed_at INTEGER,
        closed_by_staff_id TEXT,
        closing_cash_counted REAL,
        cash_variance REAL,
        carry_forward_cash REAL,
        is_carry_forward INTEGER,
        total_cash_sales REAL,
        total_card_sales REAL,
        total_sales REAL
      )
    ''');

    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_products_category ON products(category_id)');
    await db.execute('CREATE INDEX idx_orders_outlet ON orders(outlet_id)');
    await db.execute('CREATE INDEX idx_orders_created ON orders(created_at DESC)');
    await db.execute('CREATE INDEX idx_outbox_created ON outbox_queue(created_at ASC)');
    await db.execute('CREATE INDEX idx_till_adjustments_outlet ON till_adjustments(outlet_id)');
    await db.execute('CREATE INDEX idx_till_adjustments_timestamp ON till_adjustments(timestamp DESC)');
    await db.execute('CREATE INDEX idx_staff_outlets_staff ON staff_outlets(staff_id)');
    await db.execute('CREATE INDEX idx_staff_outlets_outlet ON staff_outlets(outlet_id)');
    await db.execute('CREATE INDEX idx_staff_outlets_outlet_role ON staff_outlets(outlet_id, role_id)');
    await db.execute('CREATE INDEX idx_trading_days_outlet ON trading_days(outlet_id)');
    await db.execute('CREATE INDEX idx_trading_days_opened ON trading_days(opened_at DESC)');

    debugPrint('AppDatabase: Database created successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('AppDatabase: Upgrading from version $oldVersion to $newVersion');
    
    if (oldVersion < 2) {
      // Migrate till_adjustments table from v1 to v2
      // Change 'amount' (REAL) to 'amount_pennies' (INTEGER)
      // Change 'type' to 'adjustment_type'
      
      // Check if table exists first
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='till_adjustments'"
      );
      
      if (tables.isNotEmpty) {
        // Create temp table with new schema
        await db.execute('''
          CREATE TABLE till_adjustments_new (
            id TEXT PRIMARY KEY,
            outlet_id TEXT NOT NULL,
            staff_id TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            amount_pennies INTEGER NOT NULL,
            adjustment_type TEXT NOT NULL,
            reason TEXT NOT NULL,
            notes TEXT
          )
        ''');
        
        // Copy data, converting amount to pennies
        await db.execute('''
          INSERT INTO till_adjustments_new 
          (id, outlet_id, staff_id, timestamp, amount_pennies, adjustment_type, reason, notes)
          SELECT id, outlet_id, staff_id, timestamp, 
                 CAST(amount * 100 AS INTEGER), 
                 type, reason, notes
          FROM till_adjustments
        ''');
        
        // Drop old table
        await db.execute('DROP TABLE till_adjustments');
        
        // Rename new table
        await db.execute('ALTER TABLE till_adjustments_new RENAME TO till_adjustments');
        
        // Recreate indexes
        await db.execute('CREATE INDEX idx_till_adjustments_outlet ON till_adjustments(outlet_id)');
        await db.execute('CREATE INDEX idx_till_adjustments_timestamp ON till_adjustments(timestamp DESC)');
        
        debugPrint('✅ AppDatabase: till_adjustments table migrated successfully');
      }
    }

    if (oldVersion < 3) {
      // Add is_carvery flag for kitchen ticket splitting
      await db.execute('ALTER TABLE products ADD COLUMN is_carvery INTEGER NOT NULL DEFAULT 0');
      debugPrint('✅ AppDatabase: Added is_carvery column to products');
    }

    if (oldVersion < 4) {
      // Add missing printer routing and product metadata columns
      await db.execute('ALTER TABLE products ADD COLUMN printer_id TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN course TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN plu TEXT');
      debugPrint('✅ AppDatabase: Added printer_id, course, and plu columns to products');
    }

    if (oldVersion < 5) {
      // Add staff outlet association and role/permission columns
      await db.execute('ALTER TABLE staff ADD COLUMN associated_outlets TEXT');
      await db.execute('ALTER TABLE staff ADD COLUMN role_id TEXT');
      await db.execute('ALTER TABLE staff ADD COLUMN permission_level INTEGER');
      debugPrint('✅ AppDatabase: Added outlet association columns to staff table');
    }

    if (oldVersion < 6) {
      // Create staff_outlets junction table for many-to-many relationship
      await db.execute('''
        CREATE TABLE IF NOT EXISTS staff_outlets (
          id TEXT PRIMARY KEY,
          staff_id TEXT NOT NULL,
          outlet_id TEXT NOT NULL,
          role_id TEXT,
          active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          UNIQUE(staff_id, outlet_id)
        )
      ''');
      
      // Create indexes for staff_outlets table
      await db.execute('CREATE INDEX IF NOT EXISTS idx_staff_outlets_staff ON staff_outlets(staff_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_staff_outlets_outlet ON staff_outlets(outlet_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_staff_outlets_outlet_role ON staff_outlets(outlet_id, role_id)');
      
      debugPrint('✅ AppDatabase: Created staff_outlets junction table');
    }

    if (oldVersion < 7) {
      // Migrate staff table to use current schema field names: full_name and pin_code
      debugPrint('🔄 AppDatabase: Migrating staff table to use full_name and pin_code');
      
      // Create new staff table with correct schema
      await db.execute('''
        CREATE TABLE staff_new (
          id TEXT PRIMARY KEY,
          outlet_id TEXT,
          full_name TEXT NOT NULL,
          pin_code TEXT NOT NULL,
          active INTEGER NOT NULL DEFAULT 1,
          associated_outlets TEXT,
          role_id TEXT,
          permission_level INTEGER,
          updated_at INTEGER NOT NULL
        )
      ''');
      
      // Copy existing data (try to copy outlet_id if it exists in old table)
      try {
        await db.execute('''
          INSERT INTO staff_new (id, outlet_id, full_name, pin_code, active, associated_outlets, role_id, permission_level, updated_at)
          SELECT id, outlet_id, name, pin, active, associated_outlets, role_id, permission_level, updated_at
          FROM staff
        ''');
      } catch (e) {
        // If outlet_id doesn't exist in old table, copy without it
        debugPrint('⚠️ Old staff table missing outlet_id, copying without it: $e');
        await db.execute('''
          INSERT INTO staff_new (id, full_name, pin_code, active, associated_outlets, role_id, permission_level, updated_at)
          SELECT id, name, pin, active, associated_outlets, role_id, permission_level, updated_at
          FROM staff
        ''');
      }
      
      // Drop old table
      await db.execute('DROP TABLE staff');
      
      // Rename new table
      await db.execute('ALTER TABLE staff_new RENAME TO staff');
      
      debugPrint('✅ AppDatabase: Staff table migrated to use full_name and pin_code');
    }

    if (oldVersion < 8) {
      // Add outlet_id back to staff table for legacy compatibility
      // This allows offline auth to fall back to staff.outlet_id when staff_outlets is not populated
      try {
        await db.execute('ALTER TABLE staff ADD COLUMN outlet_id TEXT');
        debugPrint('✅ AppDatabase: Added outlet_id column to staff table for legacy compatibility');
      } catch (e) {
        // Column might already exist from old schema
        debugPrint('⚠️ AppDatabase: Could not add outlet_id to staff (might already exist): $e');
      }
    }

    if (oldVersion < 9) {
      // Add trading_days table for offline support
      await db.execute('''
        CREATE TABLE IF NOT EXISTS trading_days (
          id TEXT PRIMARY KEY,
          outlet_id TEXT NOT NULL,
          trading_date INTEGER NOT NULL,
          opened_at INTEGER NOT NULL,
          opened_by_staff_id TEXT NOT NULL,
          opening_float_amount REAL NOT NULL,
          opening_float_source TEXT NOT NULL,
          closed_at INTEGER,
          closed_by_staff_id TEXT,
          closing_cash_counted REAL,
          cash_variance REAL,
          carry_forward_cash REAL,
          is_carry_forward INTEGER,
          total_cash_sales REAL,
          total_card_sales REAL,
          total_sales REAL
        )
      ''');
      
      await db.execute('CREATE INDEX IF NOT EXISTS idx_trading_days_outlet ON trading_days(outlet_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_trading_days_opened ON trading_days(opened_at DESC)');
      
      debugPrint('✅ AppDatabase: Created trading_days table for offline support');
    }
  }

  // Products operations
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await database;
    return await db.query('products', where: 'is_active = 1', orderBy: 'sort_order ASC, name ASC');
  }

  Future<List<Map<String, dynamic>>> getProductsByCategory(String categoryId) async {
    final db = await database;
    return await db.query('products', where: 'category_id = ? AND is_active = 1', whereArgs: [categoryId], orderBy: 'sort_order ASC, name ASC');
  }

  Future<void> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    await db.insert('products', product, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertProducts(List<Map<String, dynamic>> products) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final product in products) {
        batch.insert('products', product, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> deleteAllProducts() async {
    final db = await database;
    await db.delete('products');
  }

  // Categories operations
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    return await db.query('categories', orderBy: 'sort_order ASC, name ASC');
  }

  Future<List<Map<String, dynamic>>> getActiveCategoriesWithProducts() async {
    final db = await database;
    final categories = await db.query('categories', orderBy: 'sort_order ASC, name ASC');
    
    final result = <Map<String, dynamic>>[];
    for (final category in categories) {
      final products = await db.query('products', where: 'category_id = ? AND is_active = 1', whereArgs: [category['id']]);
      if (products.isNotEmpty) {
        result.add(category);
      }
    }
    return result;
  }

  Future<void> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    await db.insert('categories', category, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertCategories(List<Map<String, dynamic>> categories) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final category in categories) {
        batch.insert('categories', category, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  // Staff operations
  Future<List<Map<String, dynamic>>> getAllActiveStaff() async {
    final db = await database;
    return await db.query('staff', where: 'active = 1', orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getStaffByPin(String pin) async {
    final db = await database;
    final results = await db.query('staff', where: 'pin_code = ? AND active = 1', whereArgs: [pin]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertStaff(Map<String, dynamic> staff) async {
    final db = await database;
    await db.insert('staff', staff, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertStaffList(List<Map<String, dynamic>> staffList) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final staff in staffList) {
        batch.insert('staff', staff, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  // Staff outlets operations (junction table for many-to-many relationship)
  Future<List<Map<String, dynamic>>> getStaffOutletsByStaffId(String staffId) async {
    final db = await database;
    return await db.query('staff_outlets', where: 'staff_id = ? AND active = 1', whereArgs: [staffId]);
  }

  Future<Map<String, dynamic>?> getStaffOutletByStaffAndOutlet(String staffId, String outletId) async {
    final db = await database;
    final results = await db.query('staff_outlets', where: 'staff_id = ? AND outlet_id = ? AND active = 1', whereArgs: [staffId, outletId]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertStaffOutlet(Map<String, dynamic> staffOutlet) async {
    final db = await database;
    await db.insert('staff_outlets', staffOutlet, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertStaffOutlets(List<Map<String, dynamic>> staffOutlets) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final staffOutlet in staffOutlets) {
        batch.insert('staff_outlets', staffOutlet, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  // Printers operations
  Future<List<Map<String, dynamic>>> getAllActivePrinters() async {
    final db = await database;
    return await db.query('printers', where: 'is_active = 1');
  }

  Future<Map<String, dynamic>?> getPrinterById(String id) async {
    final db = await database;
    final results = await db.query('printers', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertPrinter(Map<String, dynamic> printer) async {
    final db = await database;
    await db.insert('printers', printer, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertPrinters(List<Map<String, dynamic>> printers) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final printer in printers) {
        batch.insert('printers', printer, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  // Outlet settings operations
  Future<Map<String, dynamic>?> getOutletSettings(String outletId) async {
    final db = await database;
    final results = await db.query('outlet_settings', where: 'outlet_id = ?', whereArgs: [outletId]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertOutletSettings(Map<String, dynamic> settings) async {
    final db = await database;
    await db.insert('outlet_settings', settings, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Tax rates operations
  Future<List<Map<String, dynamic>>> getAllTaxRates() async {
    final db = await database;
    return await db.query('tax_rates');
  }

  Future<Map<String, dynamic>?> getTaxRateById(String id) async {
    final db = await database;
    final results = await db.query('tax_rates', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertTaxRate(Map<String, dynamic> taxRate) async {
    final db = await database;
    await db.insert('tax_rates', taxRate, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertTaxRates(List<Map<String, dynamic>> taxRates) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final taxRate in taxRates) {
        batch.insert('tax_rates', taxRate, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  // Promotions operations
  Future<List<Map<String, dynamic>>> getActivePromotions() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.query('promotions', where: 'is_active = 1 AND (start_date IS NULL OR start_date <= ?) AND (end_date IS NULL OR end_date >= ?)', whereArgs: [now, now]);
  }

  Future<Map<String, dynamic>?> getPromotionById(String id) async {
    final db = await database;
    final results = await db.query('promotions', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertPromotion(Map<String, dynamic> promotion) async {
    final db = await database;
    await db.insert('promotions', promotion, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertPromotions(List<Map<String, dynamic>> promotions) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final promotion in promotions) {
        batch.insert('promotions', promotion, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> insertPromotionProducts(String promotionId, List<String> productIds) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final productId in productIds) {
        batch.insert('promotion_products', {'promotion_id': promotionId, 'product_id': productId}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> insertPromotionCategories(String promotionId, List<String> categoryIds) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final categoryId in categoryIds) {
        batch.insert('promotion_categories', {'promotion_id': promotionId, 'category_id': categoryId}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<String>> getPromotionProducts(String promotionId) async {
    final db = await database;
    final results = await db.query('promotion_products', where: 'promotion_id = ?', whereArgs: [promotionId]);
    return results.map((row) => row['product_id'] as String).toList();
  }

  Future<List<String>> getPromotionCategories(String promotionId) async {
    final db = await database;
    final results = await db.query('promotion_categories', where: 'promotion_id = ?', whereArgs: [promotionId]);
    return results.map((row) => row['category_id'] as String).toList();
  }

  // Orders operations
  Future<void> insertOrder(Map<String, dynamic> order) async {
    final db = await database;
    await db.insert('orders', order, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getOrdersByOutlet(String outletId, {int limit = 100}) async {
    final db = await database;
    return await db.query('orders', where: 'outlet_id = ?', whereArgs: [outletId], orderBy: 'created_at DESC', limit: limit);
  }

  Future<Map<String, dynamic>?> getOrderById(String id) async {
    final db = await database;
    final results = await db.query('orders', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateOrder(String id, Map<String, dynamic> updates) async {
    final db = await database;
    await db.update('orders', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteOrder(String id) async {
    final db = await database;
    await db.delete('orders', where: 'id = ?', whereArgs: [id]);
  }

  // Outlets operations
  Future<void> insertOutlets(List<Map<String, dynamic>> outlets) async {
    final db = await database;
    final batch = db.batch();
    for (final outlet in outlets) {
      batch.insert('outlets', outlet, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getAllOutlets() async {
    final db = await database;
    return await db.query('outlets', where: 'active = 1', orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getOutletById(String id) async {
    final db = await database;
    final results = await db.query('outlets', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  // Outbox queue operations (for offline sync)
  Future<int> addToOutbox({
    required String operation,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    return await db.insert('outbox_queue', {
      'operation': operation,
      'entity_type': entityType,
      'entity_id': entityId,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'retry_count': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOutboxItems({int limit = 50}) async {
    final db = await database;
    return await db.query('outbox_queue', orderBy: 'created_at ASC', limit: limit);
  }

   Future<bool> outboxItemExists({required String entityType, required String entityId}) async {
     final db = await database;
     final result = await db.query(
       'outbox_queue',
       where: 'entity_type = ? AND entity_id = ?',
       whereArgs: [entityType, entityId],
       limit: 1,
     );
     return result.isNotEmpty;
   }

  Future<void> markOutboxItemProcessed(int id) async {
    final db = await database;
    await db.delete('outbox_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementOutboxRetry(int id, String error) async {
    final db = await database;
    await db.rawUpdate('UPDATE outbox_queue SET retry_count = retry_count + 1, last_error = ? WHERE id = ?', [error, id]);
  }

  Future<int> deleteFailedOutboxItems(int maxRetries) async {
    final db = await database;
    return await db.delete('outbox_queue', where: 'retry_count >= ?', whereArgs: [maxRetries]);
  }

  // Cleanup operations for transactional data
  // This removes old synced orders to prevent database bloat
  // Only deletes orders that have been successfully synced to Supabase
  Future<void> cleanupOldOrders(int daysToKeep) async {
    final db = await database;
    final cutoffTime = DateTime.now().subtract(Duration(days: daysToKeep)).millisecondsSinceEpoch;
    
    // Check if table has sync_status column
    final tableInfo = await db.rawQuery('PRAGMA table_info(orders)');
    final hasSyncStatus = tableInfo.any((col) => col['name'] == 'sync_status');
    
    int deleted;
    if (hasSyncStatus) {
      // Use sync_status='synced' for new offline sync system
      deleted = await db.delete('orders', where: 'created_at < ? AND sync_status = ?', whereArgs: [cutoffTime, 'synced']);
    } else {
      // Fallback: delete all old orders if no sync tracking
      deleted = await db.delete('orders', where: 'created_at < ?', whereArgs: [cutoffTime]);
    }
    
    debugPrint('🧹 AppDatabase: Cleaned up $deleted orders older than $daysToKeep days (synced only)');
  }

  // Trading days operations
  Future<Map<String, dynamic>?> getCurrentTradingDay(String outletId) async {
    final db = await database;
    final results = await db.query(
      'trading_days',
      where: 'outlet_id = ? AND closed_at IS NULL',
      whereArgs: [outletId],
      orderBy: 'opened_at DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getLastClosedTradingDay(String outletId) async {
    final db = await database;
    final results = await db.query(
      'trading_days',
      where: 'outlet_id = ? AND closed_at IS NOT NULL',
      whereArgs: [outletId],
      orderBy: 'closed_at DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getTradingDays(String outletId, {int limit = 50}) async {
    final db = await database;
    return await db.query(
      'trading_days',
      where: 'outlet_id = ?',
      whereArgs: [outletId],
      orderBy: 'trading_date DESC',
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getTradingDayById(String id) async {
    final db = await database;
    final results = await db.query('trading_days', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertTradingDay(Map<String, dynamic> tradingDay) async {
    final db = await database;
    await db.insert('trading_days', tradingDay, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertTradingDays(List<Map<String, dynamic>> tradingDays) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final tradingDay in tradingDays) {
        batch.insert('trading_days', tradingDay, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> updateTradingDay(String id, Map<String, dynamic> updates) async {
    final db = await database;
    await db.update('trading_days', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllData() async {
    final db = await database;
    final batch = db.batch();
    batch.delete('products');
    batch.delete('categories');
    batch.delete('staff');
    batch.delete('printers');
    batch.delete('outlet_settings');
    batch.delete('tax_rates');
    batch.delete('promotions');
    batch.delete('promotion_products');
    batch.delete('promotion_categories');
    batch.delete('orders');
    batch.delete('outbox_queue');
    await batch.commit(noResult: true);
    debugPrint('AppDatabase: All data cleared');
  }

  // Helper to get database path (for debugging)
  Future<String> getDatabasePath() async {
    if (kIsWeb) {
      return 'IndexedDB: flowtill.db';
    }
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    if (isDesktop) {
      return join(await getDatabasesPath(), 'flowtill.db');
    } else {
      // Android/iOS
      final appDocDir = await getApplicationDocumentsDirectory();
      return join(appDocDir.path, 'flowtill.db');
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
