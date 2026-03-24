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
  
  /// Tables with offline sync support (require special metadata handling)
  static const Set<String> offlineEnabledTables = {
    'orders',
    'order_items',
    'transactions',
  };

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
      
      // Final validation: Summary of sync status for offline-enabled tables
      await _validateOverallSyncStatus(outletId);

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
      
      // Check if this table has offline sync support
      final hasOfflineSupport = localColumns.contains('sync_status');
      if (hasOfflineSupport) {
        debugPrint('[MIRROR_SYNC]   ✅ Table has offline sync columns - mirrored records will be marked as "synced"');
      }

      // Insert data into local mirror using safe upsert pattern
      int insertedCount = 0;
      int updatedCount = 0;
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
          
          // CRITICAL: Mark mirrored records as 'synced' since they came from Supabase
          // Only locally-created records should be marked as 'pending'
          if (localColumns.contains('sync_status')) {
            filteredData['sync_status'] = 'synced';
            filteredData['sync_error'] = null;
            filteredData['last_sync_attempt_at'] = null;
            filteredData['sync_attempt_count'] = 0;
            filteredData['device_id'] = null;
          }
          
          // SAFE UPSERT: Update existing row first, insert if not exists
          // This prevents REPLACE from deleting and recreating rows (which wipes metadata)
          final rowId = filteredData['id'];
          final wasInserted = await _safeUpsert(db, tableName, filteredData, rowId);
          
          if (wasInserted) {
            insertedCount++;
          } else {
            updatedCount++;
          }
          
          // Debug logging for offline-enabled tables - log first 3 rows
          if (hasOfflineSupport && (insertedCount + updatedCount) <= 3) {
            final syncStatus = filteredData['sync_status'] ?? 'NOT_SET';
            final action = wasInserted ? 'INSERTED' : 'UPDATED';
            debugPrint('[MIRROR_SYNC]   📥 $action row: id=$rowId, sync_status=$syncStatus, uploadable=false (cloud-origin)');
          }
        } catch (e) {
          debugPrint('[MIRROR_SYNC]   ⚠️ Failed to upsert row: $e');
        }
      }
      
      // Log skipped columns summary (not per-row to reduce noise)
      if (skippedColumnNames.isNotEmpty) {
        debugPrint('[MIRROR_SYNC]   ℹ️ Skipped ${skippedColumns} column write(s) for non-existent columns: ${skippedColumnNames.join(", ")}');
      }

      // Update content sync timestamp
      await _updateContentSyncTimestamp(tableName);

      final totalSynced = insertedCount + updatedCount;
      debugPrint('[MIRROR_SYNC]   ✅ Synced $totalSynced rows for $tableName (inserted: $insertedCount, updated: $updatedCount)');
      
      // Additional logging for staff_outlets
      if (tableName == 'staff_outlets') {
        debugPrint('[STAFF_OUTLETS_SYNC] local upsert count = $totalSynced');
      }
      
      // Validation: Verify sync_status for offline-enabled tables
      if (hasOfflineSupport && totalSynced > 0) {
        await _validateMirrorSyncStatus(db, tableName, outletId);
      }

      return TableSyncResult(
        tableName: tableName,
        success: true,
        rowsSynced: totalSynced,
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
  
  /// Safe upsert: Update existing row, insert if not exists
  /// Returns true if inserted, false if updated
  /// This prevents REPLACE from deleting and recreating rows
  Future<bool> _safeUpsert(
    Database db,
    String tableName,
    Map<String, dynamic> data,
    dynamic rowId,
  ) async {
    if (rowId == null) {
      // No ID provided, just insert
      await db.insert(tableName, data);
      return true;
    }
    
    // Try update first
    final updateCount = await db.update(
      tableName,
      data,
      where: 'id = ?',
      whereArgs: [rowId],
    );
    
    if (updateCount > 0) {
      // Row existed and was updated
      return false;
    } else {
      // Row doesn't exist, insert it
      await db.insert(tableName, data);
      return true;
    }
  }
  
  /// Import mirrored row with explicit cloud-origin metadata
  /// PUBLIC method for use by other services (e.g., Bucket C import)
  /// 
  /// IMPORTANT: This method is ONLY for cloud-origin rows downloaded from Supabase.
  /// Do NOT use this for locally-created rows.
  Future<void> importMirroredRow(
    String tableName,
    Map<String, dynamic> rowData, {
    String context = 'IMPORT',
  }) async {
    try {
      final db = await _db.database;
      
      // Get local table columns
      final localColumns = await _getLocalTableColumns(db, tableName);
      
      // Sanitize and filter data
      final sanitized = sanitizeDataForSQLite(rowData);
      final filtered = <String, dynamic>{};
      for (final entry in sanitized.entries) {
        if (localColumns.contains(entry.key)) {
          filtered[entry.key] = entry.value;
        }
      }
      
      // CRITICAL: Mark as synced for cloud-origin rows
      if (localColumns.contains('sync_status')) {
        filtered['sync_status'] = 'synced';
        filtered['sync_error'] = null;
        filtered['last_sync_attempt_at'] = null;
        filtered['sync_attempt_count'] = 0;
        filtered['device_id'] = null;
      }
      
      // Safe upsert
      final rowId = filtered['id'];
      final wasInserted = await _safeUpsert(db, tableName, filtered, rowId);
      
      final action = wasInserted ? 'INSERTED' : 'UPDATED';
      debugPrint('[$context]   📥 $action mirrored row to $tableName: id=$rowId, sync_status=synced');
      
    } catch (e, stackTrace) {
      debugPrint('[$context]   ⚠️ Failed to import mirrored row to $tableName: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
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
  
  /// Validate mirror sync status after import
  /// Ensures mirrored cloud-origin rows are not marked as pending
  Future<void> _validateMirrorSyncStatus(Database db, String tableName, String outletId) async {
    try {
      // Count rows by sync_status
      String whereClause = '';
      List<dynamic> whereArgs = [];
      
      if (outletFilteredTables.contains(tableName)) {
        whereClause = 'outlet_id = ?';
        whereArgs = [outletId];
      }
      
      final syncedCountResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE ${whereClause.isNotEmpty ? "$whereClause AND " : ""}sync_status = ?',
        [...whereArgs, 'synced'],
      );
      final syncedCount = syncedCountResult.first['count'] as int;
      
      final pendingCountResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE ${whereClause.isNotEmpty ? "$whereClause AND " : ""}sync_status = ?',
        [...whereArgs, 'pending'],
      );
      final pendingCount = pendingCountResult.first['count'] as int;
      
      debugPrint('[MIRROR_SYNC]   📊 Sync status validation for $tableName:');
      debugPrint('[MIRROR_SYNC]      - Synced (cloud-origin): $syncedCount');
      debugPrint('[MIRROR_SYNC]      - Pending (local-created): $pendingCount');
      
      if (pendingCount > 0) {
        debugPrint('[MIRROR_SYNC]   ⚠️ WARNING: $pendingCount mirrored rows have sync_status=pending (should be 0)');
        
        // Log sample pending rows for debugging
        final samplePending = await db.query(
          tableName,
          where: '${whereClause.isNotEmpty ? "$whereClause AND " : ""}sync_status = ?',
          whereArgs: [...whereArgs, 'pending'],
          limit: 3,
        );
        
        for (final row in samplePending) {
          debugPrint('[MIRROR_SYNC]      - Pending row sample: id=${row['id']}, sync_status=${row['sync_status']}');
        }
      } else {
        debugPrint('[MIRROR_SYNC]   ✅ VALIDATION PASSED: No mirrored rows marked as pending');
      }
    } catch (e) {
      debugPrint('[MIRROR_SYNC]   ⚠️ Failed to validate sync status: $e');
    }
  }
  
  /// Validate overall sync status across all offline-enabled tables
  /// This final check ensures cloud-origin rows are never marked as pending
  Future<void> _validateOverallSyncStatus(String outletId) async {
    try {
      final db = await _db.database;
      
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('[MIRROR_SYNC] 🔍 FINAL SYNC STATUS VALIDATION');
      debugPrint('═══════════════════════════════════════════════════════════');
      
      int totalPending = 0;
      int totalSynced = 0;
      bool allValid = true;
      
      for (final tableName in offlineEnabledTables) {
        // Check if table exists and has sync_status column
        final tableExists = await _localTableExists(db, tableName);
        if (!tableExists) {
          debugPrint('[MIRROR_SYNC]   ⏭️ $tableName: table does not exist locally');
          continue;
        }
        
        final columns = await _getLocalTableColumns(db, tableName);
        if (!columns.contains('sync_status')) {
          debugPrint('[MIRROR_SYNC]   ⏭️ $tableName: no sync_status column');
          continue;
        }
        
        // Count by sync_status
        String whereClause = '';
        List<dynamic> whereArgs = [];
        
        if (outletFilteredTables.contains(tableName)) {
          whereClause = 'outlet_id = ?';
          whereArgs = [outletId];
        }
        
        final syncedResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE ${whereClause.isNotEmpty ? "$whereClause AND " : ""}sync_status = ?',
          [...whereArgs, 'synced'],
        );
        final synced = syncedResult.first['count'] as int;
        
        final pendingResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE ${whereClause.isNotEmpty ? "$whereClause AND " : ""}sync_status = ?',
          [...whereArgs, 'pending'],
        );
        final pending = pendingResult.first['count'] as int;
        
        totalSynced += synced;
        totalPending += pending;
        
        final status = pending == 0 ? '✅' : '⚠️';
        debugPrint('[MIRROR_SYNC]   $status $tableName: synced=$synced, pending=$pending');
        
        if (pending > 0) {
          allValid = false;
        }
      }
      
      debugPrint('[MIRROR_SYNC]');
      debugPrint('[MIRROR_SYNC]   📊 SUMMARY:');
      debugPrint('[MIRROR_SYNC]      Total cloud-origin (synced): $totalSynced');
      debugPrint('[MIRROR_SYNC]      Total local-created (pending): $totalPending');
      
      if (allValid) {
        debugPrint('[MIRROR_SYNC]   ✅ VALIDATION PASSED: All mirrored rows marked as synced');
      } else {
        debugPrint('[MIRROR_SYNC]   ⚠️ VALIDATION WARNING: Some mirrored rows may be marked as pending');
        debugPrint('[MIRROR_SYNC]      This could cause duplicate uploads during outbound sync');
      }
      
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');
    } catch (e, stackTrace) {
      debugPrint('[MIRROR_SYNC]   ❌ Overall validation failed: $e');
      debugPrint('Stack: $stackTrace');
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
