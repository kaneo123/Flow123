import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:crypto/crypto.dart';

/// Schema synchronization service
/// Ensures local SQLite database structure mirrors Supabase schema
/// Runs on app startup to detect and apply schema changes
/// 
/// OFFLINE TRANSACTION SUPPORT:
/// - Adds local-only columns to transactional tables (orders, order_items, transactions)
/// - Creates local-only sync_queue table for offline change tracking
/// - Preserves local-only columns during schema updates
class SchemaSyncService {
  static final SchemaSyncService _instance = SchemaSyncService._internal();
  factory SchemaSyncService() => _instance;
  SchemaSyncService._internal();

  final AppDatabase _db = AppDatabase.instance;

  /// Tables to sync schema from Supabase
  static const List<String> _tablesToSync = [
    'outlets',
    'outlet_settings',
    'categories',
    'products',
    'staff',
    'staff_outlets',
    'printers',
    'tax_rates',
    'promotions',
    'outlet_tables',
    'modifier_groups',
    'modifier_options',
    'product_modifier_groups',
    'packaged_deals',
    'packaged_deal_components',
    'inventory_items',
    'stock_movements',
    'orders',
    'order_items',
    'transactions',
    'loyalty_customers',
    'loyalty_transactions',
  ];

  /// Tables that require local-only offline sync columns
  static const Set<String> _tablesWithOfflineSupport = {
    'orders',
    'order_items',
    'transactions',
  };

  /// Local-only columns for offline transaction tracking
  /// These columns do NOT exist in Supabase but are added to local mirror tables
  /// 
  /// IMPORTANT: Default 'pending' applies to NEW locally-created records only.
  /// Records mirrored from Supabase are explicitly set to 'synced' by MirrorContentSyncService.
  static const Map<String, String> _localOnlyColumns = {
    'sync_status': 'TEXT DEFAULT "pending"',
    'sync_error': 'TEXT',
    'last_sync_attempt_at': 'INTEGER',
    'sync_attempt_count': 'INTEGER DEFAULT 0',
    'device_id': 'TEXT',
  };

  /// Map Supabase (PostgreSQL) types to SQLite types
  String _mapSupabaseTypeToSQLite(String supabaseType) {
    final type = supabaseType.toLowerCase();
    
    if (type.contains('int') || type.contains('bigint') || type.contains('smallint')) {
      return 'INTEGER';
    } else if (type.contains('decimal') || type.contains('numeric') || 
               type.contains('real') || type.contains('double') || type.contains('float')) {
      return 'REAL';
    } else if (type.contains('bool')) {
      return 'INTEGER'; // SQLite uses INTEGER for boolean (0/1)
    } else if (type.contains('json') || type.contains('jsonb')) {
      return 'TEXT'; // Store JSON as TEXT in SQLite
    } else if (type.contains('timestamp') || type.contains('date') || type.contains('time')) {
      return 'INTEGER'; // Store timestamps as INTEGER (milliseconds since epoch)
    } else {
      return 'TEXT'; // Default to TEXT for varchar, text, uuid, etc.
    }
  }

  /// Fetch schema from Supabase for a specific table
  Future<Map<String, String>> _fetchSupabaseTableSchema(String tableName) async {
    debugPrint('  🔍 Fetching schema for table: $tableName');
    
    try {
      final supabase = SupabaseConfig.client;
      
      // Query PostgreSQL information_schema to get column definitions
      final response = await supabase.rpc('get_table_columns', params: {
        'table_name_param': tableName,
      });

      final columns = <String, String>{};
      
      if (response is List) {
        for (final row in response) {
          final columnName = row['column_name'] as String;
          final dataType = row['data_type'] as String;
          final sqliteType = _mapSupabaseTypeToSQLite(dataType);
          columns[columnName] = sqliteType;
          debugPrint('    📋 $columnName: $dataType → $sqliteType');
        }
      }

      debugPrint('  ✅ Found ${columns.length} columns in $tableName');
      return columns;
    } catch (e) {
      debugPrint('  ⚠️ Failed to fetch schema for $tableName: $e');
      return {};
    }
  }

  /// Check if a local table exists
  Future<bool> _localTableExists(Database db, String tableName) async {
    try {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('  ❌ Error checking table existence for $tableName: $e');
      return false;
    }
  }

  /// Fetch current local SQLite table schema
  Future<Map<String, String>> _fetchLocalTableSchema(String tableName) async {
    try {
      final db = await _db.database;
      
      // Check if table exists
      final exists = await _localTableExists(db, tableName);

      if (!exists) {
        debugPrint('  ℹ️ Table $tableName does not exist locally');
        return {};
      }

      // Get table schema using PRAGMA table_info
      final result = await db.rawQuery('PRAGMA table_info($tableName)');
      final columns = <String, String>{};
      
      for (final row in result) {
        final columnName = row['name'] as String;
        final dataType = (row['type'] as String).toUpperCase();
        columns[columnName] = dataType;
      }

      debugPrint('  📊 Local $tableName has ${columns.length} columns');
      return columns;
    } catch (e) {
      debugPrint('  ❌ Error fetching local schema for $tableName: $e');
      return {};
    }
  }

  /// Create a new local mirror table from scratch
  Future<void> _createLocalMirrorTable(
    Database db,
    String tableName,
    Map<String, String> columns,
  ) async {
    try {
      debugPrint('  🆕 Creating new local mirror table: $tableName');
      
      // Build column definitions
      final columnDefs = <String>[];
      
      for (final entry in columns.entries) {
        final columnName = entry.key;
        final columnType = entry.value;
        
        // Special handling for 'id' column as primary key
        if (columnName == 'id') {
          columnDefs.add('$columnName $columnType PRIMARY KEY');
        } else {
          columnDefs.add('$columnName $columnType');
        }
      }

      // Add local-only columns for offline-enabled tables
      if (_tablesWithOfflineSupport.contains(tableName)) {
        debugPrint('  📲 Adding local-only offline sync columns to $tableName');
        for (final entry in _localOnlyColumns.entries) {
          columnDefs.add('${entry.key} ${entry.value}');
        }
      }
      
      final createTableSQL = '''
        CREATE TABLE IF NOT EXISTS $tableName (
          ${columnDefs.join(',\n          ')}
        )
      ''';
      
      debugPrint('  📝 CREATE TABLE statement:');
      debugPrint('$createTableSQL');
      
      await db.execute(createTableSQL);
      debugPrint('  ✅ Successfully created table: $tableName');
    } catch (e) {
      debugPrint('  ❌ Failed to create table $tableName: $e');
      rethrow;
    }
  }

  /// Add local-only offline sync columns to existing table
  /// Used when a table exists but is missing local-only columns
  Future<void> _ensureLocalOnlyColumns(Database db, String tableName) async {
    if (!_tablesWithOfflineSupport.contains(tableName)) {
      return; // Table doesn't need offline columns
    }

    try {
      debugPrint('  🔍 Checking for local-only columns in $tableName');
      
      // Get current local schema
      final result = await db.rawQuery('PRAGMA table_info($tableName)');
      final existingColumns = result.map((row) => row['name'] as String).toSet();
      
      // Check which local-only columns are missing
      final missingColumns = <String, String>{};
      for (final entry in _localOnlyColumns.entries) {
        if (!existingColumns.contains(entry.key)) {
          missingColumns[entry.key] = entry.value;
        }
      }

      if (missingColumns.isEmpty) {
        debugPrint('  ✅ All local-only columns already exist in $tableName');
        return;
      }

      // Add missing local-only columns
      debugPrint('  ➕ Adding ${missingColumns.length} missing local-only columns to $tableName');
      for (final entry in missingColumns.entries) {
        final columnName = entry.key;
        final columnDef = entry.value;
        
        try {
          await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnDef');
          debugPrint('    ✅ Added local-only column: $columnName');
        } catch (e) {
          debugPrint('    ⚠️ Failed to add local-only column $columnName: $e');
        }
      }
      
      debugPrint('  ✅ Local-only columns ensured for $tableName');
    } catch (e) {
      debugPrint('  ⚠️ Error ensuring local-only columns for $tableName: $e');
    }
  }

  /// Create local-only sync_queue table
  /// This table exists ONLY locally and is never synced to Supabase
  Future<void> _ensureSyncQueueTable(Database db) async {
    try {
      debugPrint('🔄 Ensuring local-only sync_queue table exists');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id TEXT PRIMARY KEY,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          operation TEXT NOT NULL,
          payload TEXT,
          status TEXT NOT NULL DEFAULT 'pending',
          created_at INTEGER NOT NULL,
          updated_at INTEGER,
          last_attempt_at INTEGER,
          attempt_count INTEGER DEFAULT 0,
          error_message TEXT,
          priority INTEGER DEFAULT 0
        )
      ''');

      // Create indexes for efficient queue processing
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sync_queue_status 
        ON sync_queue(status, priority DESC, created_at ASC)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sync_queue_entity 
        ON sync_queue(entity_type, entity_id)
      ''');

      debugPrint('  ✅ sync_queue table ready (local-only)');
    } catch (e) {
      debugPrint('  ❌ Failed to create sync_queue table: $e');
      rethrow;
    }
  }

  /// Add missing columns to local SQLite table
  Future<void> _addMissingColumns(
    Database db,
    String tableName,
    Map<String, String> missingColumns,
  ) async {
    if (missingColumns.isEmpty) return;

    try {
      debugPrint('  ➕ Altering existing local mirror table: $tableName');
      debugPrint('  ➕ Adding ${missingColumns.length} missing columns');
      
      for (final entry in missingColumns.entries) {
        final columnName = entry.key;
        final columnType = entry.value;
        
        try {
          await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnType');
          debugPrint('    ✅ Added column: $columnName ($columnType)');
        } catch (e) {
          debugPrint('    ⚠️ Failed to add column $columnName: $e');
        }
      }
      
      debugPrint('  ✅ Added missing columns: ${missingColumns.length}');
    } catch (e) {
      debugPrint('  ❌ Error adding columns to $tableName: $e');
    }
  }

  /// Compute hash of schema for change detection
  String _computeSchemaHash(Map<String, String> schema) {
    final sortedKeys = schema.keys.toList()..sort();
    final schemaString = sortedKeys.map((k) => '$k:${schema[k]}').join(',');
    final bytes = utf8.encode(schemaString);
    return md5.convert(bytes).toString();
  }

  /// Get last synced schema hash from local database
  Future<String?> _getLastSchemaHash(String tableName) async {
    try {
      final db = await _db.database;
      final result = await db.query(
        'schema_snapshot',
        where: 'table_name = ?',
        whereArgs: [tableName],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return result.first['schema_hash'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('  ⚠️ Could not read schema hash for $tableName: $e');
      return null;
    }
  }

  /// Update schema snapshot after sync
  Future<void> _updateSchemaSnapshot(String tableName, String schemaHash) async {
    try {
      final db = await _db.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(
        'schema_snapshot',
        {
          'table_name': tableName,
          'schema_hash': schemaHash,
          'last_synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('  💾 Updated schema snapshot for $tableName');
    } catch (e) {
      debugPrint('  ⚠️ Failed to update schema snapshot: $e');
    }
  }

  /// Sync schema for a single table
  Future<void> _syncTableSchema(String tableName) async {
    debugPrint('🔄 Syncing schema for: $tableName');

    try {
      final db = await _db.database;
      
      // Fetch schemas from both sources
      final supabaseSchema = await _fetchSupabaseTableSchema(tableName);
      if (supabaseSchema.isEmpty) {
        debugPrint('  ⏭️ Skipping $tableName (no schema from Supabase)');
        return;
      }

      // Check if local table exists
      final tableExists = await _localTableExists(db, tableName);
      debugPrint('  🔍 Local table exists: $tableExists');

      if (!tableExists) {
        // TABLE DOES NOT EXIST - CREATE IT FROM SCRATCH
        debugPrint('  🆕 Table does not exist locally, creating from scratch...');
        await _createLocalMirrorTable(db, tableName, supabaseSchema);
        
        // Local-only columns are already added by _createLocalMirrorTable for offline-enabled tables
        
        // Update schema snapshot after successful creation
        final newSchemaHash = _computeSchemaHash(supabaseSchema);
        await _updateSchemaSnapshot(tableName, newSchemaHash);
        
        debugPrint('  ✅ Schema sync completed for $tableName (new table created)');
        return;
      }

      // TABLE EXISTS - CHECK FOR SCHEMA CHANGES
      final newSchemaHash = _computeSchemaHash(supabaseSchema);
      final lastSchemaHash = await _getLastSchemaHash(tableName);

      // Check if schema has changed
      if (lastSchemaHash == newSchemaHash) {
        debugPrint('  ✅ Schema unchanged for $tableName (hash: ${newSchemaHash.substring(0, 8)}...)');
        return;
      }

      debugPrint('  🔀 Schema change detected for $tableName');
      debugPrint('    Old hash: ${lastSchemaHash?.substring(0, 8) ?? 'none'}');
      debugPrint('    New hash: ${newSchemaHash.substring(0, 8)}');

      // For mirror tables, drop and rebuild instead of trying to migrate
      // This avoids NOT NULL constraint conflicts from legacy columns
      debugPrint('  🔨 [SCHEMA_SYNC] Rebuilding incompatible mirror table: $tableName');
      
      // Drop the existing table
      await db.execute('DROP TABLE IF EXISTS $tableName');
      debugPrint('  🗑️ Dropped legacy table: $tableName');
      
      // Recreate table from current Supabase schema
      // This automatically includes local-only columns for offline-enabled tables
      await _createLocalMirrorTable(db, tableName, supabaseSchema);
      debugPrint('  🆕 Recreated table with current schema: $tableName');

      // Update schema snapshot
      await _updateSchemaSnapshot(tableName, newSchemaHash);

      debugPrint('  ✅ Schema sync completed for $tableName (table rebuilt)');
    } catch (e, stackTrace) {
      debugPrint('  ❌ Schema sync failed for $tableName: $e');
      debugPrint('  Stack: $stackTrace');
    }
  }

  /// Initialize schema sync - run on app startup
  /// This ensures local database structure matches Supabase before any data operations
  Future<void> initialize() async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🔧 SCHEMA SYNC SERVICE - STARTUP');
    debugPrint('═══════════════════════════════════════════════════════════');

    try {
      final db = await _db.database;

      // Ensure schema_snapshot table exists
      await _ensureSchemaSnapshotTable();

      // Ensure local-only sync_queue table exists
      await _ensureSyncQueueTable(db);

      // Sync all Supabase mirror tables
      for (final tableName in _tablesToSync) {
        await _syncTableSchema(tableName);
      }

      // Ensure local-only columns exist on offline-enabled tables
      // This handles backward compatibility for existing databases
      debugPrint('');
      debugPrint('🔄 Ensuring local-only offline sync columns...');
      for (final tableName in _tablesWithOfflineSupport) {
        await _ensureLocalOnlyColumns(db, tableName);
      }

      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('✅ SCHEMA SYNC COMPLETED');
      debugPrint('   Synced ${_tablesToSync.length} Supabase mirror tables');
      debugPrint('   Ensured local-only columns for ${_tablesWithOfflineSupport.length} offline-enabled tables');
      debugPrint('   Created local-only sync_queue table');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('❌ SCHEMA SYNC FAILED: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('');
    }
  }

  /// Ensure schema_snapshot table exists
  Future<void> _ensureSchemaSnapshotTable() async {
    try {
      final db = await _db.database;
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS schema_snapshot (
          table_name TEXT PRIMARY KEY,
          schema_hash TEXT NOT NULL,
          last_synced_at INTEGER NOT NULL
        )
      ''');

      debugPrint('✅ Schema snapshot table ready');
    } catch (e) {
      debugPrint('❌ Failed to create schema_snapshot table: $e');
      rethrow;
    }
  }
}
