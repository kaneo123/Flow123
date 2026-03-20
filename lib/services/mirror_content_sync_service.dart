import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/supabase/supabase_config.dart';

/// Mirror content synchronization service
/// Handles manual download of data from Supabase to local SQLite mirror tables
class MirrorContentSyncService {
  static final MirrorContentSyncService _instance = MirrorContentSyncService._internal();
  factory MirrorContentSyncService() => _instance;
  MirrorContentSyncService._internal();

  final AppDatabase _db = AppDatabase.instance;

  /// All tables available for mirror content sync
  static const List<String> availableTables = [
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
    'trading_days',
  ];

  /// Tables that should be filtered by outlet_id
  static const List<String> outletFilteredTables = [
    'outlet_settings',
    'categories',
    'products',
    'staff_outlets',
    'printers',
    // NOTE: tax_rates is GLOBAL/SHARED across outlets (no outlet_id column)
    // DO NOT add tax_rates to this list - it should sync all tax rates for all outlets
    'promotions',
    'outlet_tables',
    'modifier_groups',
    'modifier_options',
    'product_modifier_groups',
    'packaged_deals',
    'inventory_items',
    'stock_movements',
    'orders',
    'transactions',
    'trading_days',
  ];

  /// Sync all mirror content for a specific outlet
  Future<SyncAllResult> syncAllMirrorContent(String outletId) async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[MIRROR_SYNC] SYNC ALL MIRROR CONTENT - START');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[MIRROR_SYNC] Outlet ID: $outletId');

    final results = <String, TableSyncResult>{};
    int totalRows = 0;

    try {
      for (final tableName in availableTables) {
        final result = await syncSingleTable(tableName, outletId);
        results[tableName] = result;
        totalRows += result.rowsSynced;
      }

      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('[MIRROR_SYNC] ✅ SYNC ALL COMPLETED');
      debugPrint('[MIRROR_SYNC] Total rows synced: $totalRows');
      debugPrint('[MIRROR_SYNC] Tables synced: ${results.length}');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');

      return SyncAllResult(
        success: true,
        totalRows: totalRows,
        tableResults: results,
      );
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('[MIRROR_SYNC] ❌ SYNC ALL FAILED: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('');

      return SyncAllResult(
        success: false,
        totalRows: totalRows,
        tableResults: results,
        error: e.toString(),
      );
    }
  }

  /// Sync a single table from Supabase to local mirror
  Future<TableSyncResult> syncSingleTable(String tableName, String outletId) async {
    debugPrint('[MIRROR_SYNC] Syncing table: $tableName');

    try {
      final db = await _db.database;
      final supabase = SupabaseConfig.client;

      // Check if table exists locally
      final tableExists = await _localTableExists(db, tableName);
      if (!tableExists) {
        debugPrint('[MIRROR_SYNC] ⚠️ Table $tableName does not exist locally - run schema sync first');
        return TableSyncResult(
          tableName: tableName,
          success: false,
          rowsSynced: 0,
          error: 'Table does not exist locally',
        );
      }

      // Fetch data from Supabase
      debugPrint('[MIRROR_SYNC]   Fetching from Supabase...');
      
      var query = supabase.from(tableName).select();
      
      // Apply outlet filter for relevant tables
      if (outletFilteredTables.contains(tableName)) {
        query = query.eq('outlet_id', outletId);
        debugPrint('[MIRROR_SYNC]   Filtering by outlet_id: $outletId');
        
        // Additional logging for staff_outlets
        if (tableName == 'staff_outlets') {
          debugPrint('[STAFF_OUTLETS_SYNC] outlet_id filter = $outletId');
        }
      }

      final response = await query;
      final rows = response as List<dynamic>;
      
      debugPrint('[MIRROR_SYNC]   Fetched ${rows.length} rows from Supabase');
      
      // Additional logging for staff_outlets
      if (tableName == 'staff_outlets') {
        debugPrint('[STAFF_OUTLETS_SYNC] source row count = ${rows.length}');
        if (rows.isNotEmpty) {
          debugPrint('[STAFF_OUTLETS_SYNC] sample row: ${rows.first}');
        }
      }

      // Clear existing local data for this table
      if (outletFilteredTables.contains(tableName)) {
        await db.delete(
          tableName,
          where: 'outlet_id = ?',
          whereArgs: [outletId],
        );
        debugPrint('[MIRROR_SYNC]   Cleared existing local data for outlet');
      } else {
        await db.delete(tableName);
        debugPrint('[MIRROR_SYNC]   Cleared existing local data for table');
      }

      // Get local table columns once for efficiency
      final localColumns = await _getLocalTableColumns(db, tableName);
      debugPrint('[MIRROR_SYNC]   📋 Local table has ${localColumns.length} columns: ${localColumns.join(", ")}');

      // Insert data into local mirror
      int insertedCount = 0;
      int skippedColumns = 0;
      final Set<String> skippedColumnNames = {};
      
      for (final row in rows) {
        try {
          final rowData = row as Map<String, dynamic>;
          final sanitizedData = sanitizeDataForSQLite(rowData);
          
          // Filter to only include columns that exist in local table
          final filteredData = <String, dynamic>{};
          for (final entry in sanitizedData.entries) {
            if (localColumns.contains(entry.key)) {
              filteredData[entry.key] = entry.value;
            } else {
              skippedColumns++;
              skippedColumnNames.add(entry.key);
            }
          }
          
          await db.insert(
            tableName,
            filteredData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          insertedCount++;
        } catch (e) {
          debugPrint('[MIRROR_SYNC]   ⚠️ Failed to insert row: $e');
        }
      }
      
      // Log skipped columns summary (not per-row to reduce noise)
      if (skippedColumnNames.isNotEmpty) {
        debugPrint('[MIRROR_SYNC]   ℹ️ Skipped ${skippedColumns} column write(s) for non-existent columns: ${skippedColumnNames.join(", ")}');
      }

      // Update content sync timestamp
      await _updateContentSyncTimestamp(tableName);

      debugPrint('[MIRROR_SYNC]   ✅ Synced $insertedCount rows for $tableName');
      
      // Additional logging for staff_outlets
      if (tableName == 'staff_outlets') {
        debugPrint('[STAFF_OUTLETS_SYNC] local insert count = $insertedCount');
      }

      return TableSyncResult(
        tableName: tableName,
        success: true,
        rowsSynced: insertedCount,
      );
    } catch (e, stackTrace) {
      debugPrint('[MIRROR_SYNC]   ❌ Failed to sync $tableName: $e');
      debugPrint('Stack: $stackTrace');

      return TableSyncResult(
        tableName: tableName,
        success: false,
        rowsSynced: 0,
        error: e.toString(),
      );
    }
  }

  /// Clear all mirror content (keeps schema, removes data)
  Future<ClearResult> clearAllMirrorContent() async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[MIRROR_SYNC] CLEAR ALL MIRROR CONTENT - START');
    debugPrint('═══════════════════════════════════════════════════════════');

    int clearedTables = 0;

    try {
      final db = await _db.database;

      for (final tableName in availableTables) {
        final exists = await _localTableExists(db, tableName);
        if (exists) {
          await db.delete(tableName);
          clearedTables++;
          debugPrint('[MIRROR_SYNC] ✅ Cleared $tableName');
        }
      }

      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('[MIRROR_SYNC] ✅ CLEAR COMPLETED');
      debugPrint('[MIRROR_SYNC] Cleared $clearedTables tables');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');

      return ClearResult(
        success: true,
        clearedTables: clearedTables,
      );
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('[MIRROR_SYNC] ❌ CLEAR FAILED: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('');

      return ClearResult(
        success: false,
        clearedTables: clearedTables,
        error: e.toString(),
      );
    }
  }

  /// Clear content from a single mirror table (keeps schema, removes data only)
  Future<ClearResult> clearSingleTable(String tableName) async {
    debugPrint('[MIRROR_SYNC] Clearing table: $tableName');

    try {
      final db = await _db.database;

      // Check if table exists
      final exists = await _localTableExists(db, tableName);
      if (!exists) {
        debugPrint('[MIRROR_SYNC] ⚠️ Table $tableName does not exist locally');
        return ClearResult(
          success: false,
          clearedTables: 0,
          error: 'Table does not exist locally',
        );
      }

      // Clear the table
      await db.delete(tableName);
      debugPrint('[MIRROR_SYNC] ✅ Cleared $tableName');

      return ClearResult(
        success: true,
        clearedTables: 1,
      );
    } catch (e, stackTrace) {
      debugPrint('[MIRROR_SYNC] ❌ Failed to clear $tableName: $e');
      debugPrint('Stack: $stackTrace');

      return ClearResult(
        success: false,
        clearedTables: 0,
        error: e.toString(),
      );
    }
  }

  /// Get diagnostics for all mirror tables
  Future<MirrorDiagnostics> getMirrorDiagnostics(String? outletId) async {
    debugPrint('');
    debugPrint('[MIRROR_DIAGNOSTICS] Generating diagnostics report');
    if (outletId != null) {
      debugPrint('[MIRROR_DIAGNOSTICS] Outlet ID: $outletId');
    }

    final tables = <TableDiagnostic>[];

    try {
      final db = await _db.database;
      final supabase = SupabaseConfig.client;

      for (final tableName in availableTables) {
        debugPrint('[MIRROR_DIAGNOSTICS] Checking $tableName...');

        // Check if local table exists
        final localExists = await _localTableExists(db, tableName);
        
        int localRowCount = 0;
        int? supabaseRowCount;
        String? schemaHashLocal;
        String? schemaHashLatest;
        DateTime? lastContentSync;

        if (localExists) {
          // Get local row count
          if (outletId != null && outletFilteredTables.contains(tableName)) {
            final result = await db.rawQuery(
              'SELECT COUNT(*) as count FROM $tableName WHERE outlet_id = ?',
              [outletId],
            );
            localRowCount = result.first['count'] as int;
          } else {
            final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
            localRowCount = result.first['count'] as int;
          }

          // Get local schema hash
          final schemaSnapshot = await db.query(
            'schema_snapshot',
            where: 'table_name = ?',
            whereArgs: [tableName],
            limit: 1,
          );
          
          if (schemaSnapshot.isNotEmpty) {
            schemaHashLocal = schemaSnapshot.first['schema_hash'] as String?;
            schemaHashLatest = schemaHashLocal; // Same for now
          }

          // Get last content sync timestamp
          final contentSync = await db.query(
            'mirror_content_sync',
            where: 'table_name = ?',
            whereArgs: [tableName],
            limit: 1,
          );
          
          if (contentSync.isNotEmpty) {
            final timestamp = contentSync.first['last_synced_at'] as int?;
            if (timestamp != null) {
              lastContentSync = DateTime.fromMillisecondsSinceEpoch(timestamp);
            }
          }
        }

        // Try to get Supabase row count
        try {
          var query = supabase.from(tableName).select('id');
          
          if (outletId != null && outletFilteredTables.contains(tableName)) {
            query = query.eq('outlet_id', outletId);
          }
          
          final response = await query;
          supabaseRowCount = (response as List).length;
        } catch (e) {
          debugPrint('[MIRROR_DIAGNOSTICS]   ⚠️ Could not fetch Supabase row count: $e');
        }

        // Determine source currently used
        String sourceUsed = 'N/A';
        if (localExists && localRowCount > 0) {
          sourceUsed = 'local';
        } else if (supabaseRowCount != null && supabaseRowCount > 0) {
          sourceUsed = 'supabase fallback';
        }

        tables.add(TableDiagnostic(
          tableName: tableName,
          localTableExists: localExists,
          localRowCount: localRowCount,
          supabaseRowCount: supabaseRowCount,
          schemaHashLocal: schemaHashLocal,
          schemaHashLatest: schemaHashLatest,
          lastContentSync: lastContentSync,
          sourceCurrentlyUsed: sourceUsed,
        ));

        debugPrint('[MIRROR_DIAGNOSTICS]   ✅ $tableName: local=$localExists, rows=$localRowCount, source=$sourceUsed');
      }

      debugPrint('[MIRROR_DIAGNOSTICS] ✅ Diagnostics complete');
      debugPrint('');

      return MirrorDiagnostics(
        tables: tables,
        outletId: outletId,
        generatedAt: DateTime.now(),
      );
    } catch (e, stackTrace) {
      debugPrint('[MIRROR_DIAGNOSTICS] ❌ Failed to generate diagnostics: $e');
      debugPrint('Stack: $stackTrace');
      
      return MirrorDiagnostics(
        tables: tables,
        outletId: outletId,
        generatedAt: DateTime.now(),
        error: e.toString(),
      );
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
      return false;
    }
  }

  /// Get list of column names for a local table
  Future<Set<String>> _getLocalTableColumns(Database db, String tableName) async {
    try {
      final result = await db.rawQuery('PRAGMA table_info($tableName)');
      final columns = <String>{};
      for (final row in result) {
        final columnName = row['name'] as String;
        columns.add(columnName);
      }
      return columns;
    } catch (e) {
      debugPrint('[MIRROR_SYNC] ⚠️ Failed to get columns for $tableName: $e');
      return {};
    }
  }

  /// Sanitize data for SQLite storage (public for use by orchestrator)
  Map<String, dynamic> sanitizeDataForSQLite(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value == null) {
        sanitized[key] = null;
      } else if (value is Map || value is List) {
        // Convert complex types to JSON string
        sanitized[key] = jsonEncode(value);
      } else if (value is DateTime) {
        // Convert DateTime to milliseconds
        sanitized[key] = value.millisecondsSinceEpoch;
      } else if (value is bool) {
        // Convert bool to int (0/1)
        sanitized[key] = value ? 1 : 0;
      } else {
        sanitized[key] = value;
      }
    }

    return sanitized;
  }

  /// Update content sync timestamp
  Future<void> _updateContentSyncTimestamp(String tableName) async {
    try {
      final db = await _db.database;
      
      // Ensure mirror_content_sync table exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mirror_content_sync (
          table_name TEXT PRIMARY KEY,
          last_synced_at INTEGER NOT NULL
        )
      ''');

      final now = DateTime.now().millisecondsSinceEpoch;
      
      await db.insert(
        'mirror_content_sync',
        {
          'table_name': tableName,
          'last_synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[MIRROR_SYNC] ⚠️ Failed to update content sync timestamp: $e');
    }
  }
}

/// Result of syncing all tables
class SyncAllResult {
  final bool success;
  final int totalRows;
  final Map<String, TableSyncResult> tableResults;
  final String? error;

  SyncAllResult({
    required this.success,
    required this.totalRows,
    required this.tableResults,
    this.error,
  });
}

/// Result of syncing a single table
class TableSyncResult {
  final String tableName;
  final bool success;
  final int rowsSynced;
  final String? error;

  TableSyncResult({
    required this.tableName,
    required this.success,
    required this.rowsSynced,
    this.error,
  });
}

/// Result of clearing mirror content
class ClearResult {
  final bool success;
  final int clearedTables;
  final String? error;

  ClearResult({
    required this.success,
    required this.clearedTables,
    this.error,
  });
}

/// Mirror diagnostics report
class MirrorDiagnostics {
  final List<TableDiagnostic> tables;
  final String? outletId;
  final DateTime generatedAt;
  final String? error;

  MirrorDiagnostics({
    required this.tables,
    required this.outletId,
    required this.generatedAt,
    this.error,
  });
}

/// Diagnostic info for a single table
class TableDiagnostic {
  final String tableName;
  final bool localTableExists;
  final int localRowCount;
  final int? supabaseRowCount;
  final String? schemaHashLocal;
  final String? schemaHashLatest;
  final DateTime? lastContentSync;
  final String sourceCurrentlyUsed;

  TableDiagnostic({
    required this.tableName,
    required this.localTableExists,
    required this.localRowCount,
    this.supabaseRowCount,
    this.schemaHashLocal,
    this.schemaHashLatest,
    this.lastContentSync,
    required this.sourceCurrentlyUsed,
  });
}
