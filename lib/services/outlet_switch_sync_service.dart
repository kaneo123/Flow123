import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:flowtill/services/mirror_content_sync_service.dart';

/// Specialized service for syncing required data during outlet switching
/// Focuses only on the minimum required tables for a functional POS outlet
class OutletSwitchSyncService {
  static final OutletSwitchSyncService _instance = OutletSwitchSyncService._internal();
  factory OutletSwitchSyncService() => _instance;
  OutletSwitchSyncService._internal();

  final AppDatabase _db = AppDatabase.instance;

  /// Minimum required tables for outlet switching
  /// This matches the tables needed for a functioning POS outlet
  static const List<String> requiredTables = [
    'outlet_settings',
    'categories',
    'products',
    'tax_rates',
    'staff_outlets',
    'printers',
    'modifier_groups',
    'modifier_options',
    'product_modifier_groups',
    'trading_days',
  ];

  /// Sync only the required tables for outlet switching
  /// Much faster than full sync - only syncs what's needed for operation
  Future<OutletSwitchSyncResult> syncRequiredOutletData(String outletId) async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[OUTLET_SWITCH_SYNC] SYNCING REQUIRED DATA FOR OUTLET SWITCH');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[OUTLET_SWITCH_SYNC] Outlet ID: $outletId');
    debugPrint('[OUTLET_SWITCH_SYNC] Mode: ONLINE');

    final Map<String, int> tableCounts = {};
    final List<String> failedTables = [];
    int totalRows = 0;

    try {
      for (final tableName in requiredTables) {
        debugPrint('[OUTLET_SWITCH_SYNC] Syncing: $tableName');
        
        final result = await _syncSingleTable(tableName, outletId);
        
        if (result.success) {
          tableCounts[tableName] = result.rowsSynced;
          totalRows += result.rowsSynced;
          debugPrint('[OUTLET_SWITCH_SYNC]   ✅ $tableName: ${result.rowsSynced} rows');
        } else {
          failedTables.add(tableName);
          tableCounts[tableName] = 0;
          debugPrint('[OUTLET_SWITCH_SYNC]   ❌ $tableName: FAILED - ${result.error}');
        }
      }

      final success = failedTables.isEmpty;

      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      if (success) {
        debugPrint('[OUTLET_SWITCH_SYNC] ✅ SYNC COMPLETED SUCCESSFULLY');
        debugPrint('[OUTLET_SWITCH_SYNC] Total rows synced: $totalRows');
      } else {
        debugPrint('[OUTLET_SWITCH_SYNC] ⚠️ SYNC COMPLETED WITH ERRORS');
        debugPrint('[OUTLET_SWITCH_SYNC] Failed tables: ${failedTables.join(", ")}');
      }
      debugPrint('[OUTLET_SWITCH_SYNC] Table counts:');
      for (final entry in tableCounts.entries) {
        debugPrint('[OUTLET_SWITCH_SYNC]   • ${entry.key}: ${entry.value} rows');
      }
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');

      return OutletSwitchSyncResult(
        success: success,
        totalRows: totalRows,
        tableCounts: tableCounts,
        failedTables: failedTables,
      );

    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('[OUTLET_SWITCH_SYNC] ❌ SYNC FAILED WITH EXCEPTION: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');

      return OutletSwitchSyncResult(
        success: false,
        totalRows: totalRows,
        tableCounts: tableCounts,
        failedTables: requiredTables,
        error: e.toString(),
      );
    }
  }

  /// Verify that all required tables have data for the outlet
  /// Returns true only if ALL required tables have at least one row
  Future<OutletVerificationResult> verifyOutletReadyLocally(String outletId) async {
    debugPrint('');
    debugPrint('[OUTLET_SWITCH_SYNC] VERIFYING OUTLET DATA LOCALLY');
    debugPrint('[OUTLET_SWITCH_SYNC] Outlet ID: $outletId');

    final Map<String, int> tableCounts = {};
    final List<String> emptyTables = [];

    try {
      final db = await _db.database;

      for (final tableName in requiredTables) {
        final count = await _getRowCount(db, tableName, outletId);
        tableCounts[tableName] = count;

        if (count == 0) {
          emptyTables.add(tableName);
          debugPrint('[OUTLET_SWITCH_SYNC]   ⚠️ $tableName: 0 rows (EMPTY)');
        } else {
          debugPrint('[OUTLET_SWITCH_SYNC]   ✅ $tableName: $count rows');
        }
      }

      final isReady = emptyTables.isEmpty;

      if (isReady) {
        debugPrint('[OUTLET_SWITCH_SYNC] ✅ VERIFICATION PASSED - Outlet is ready');
      } else {
        debugPrint('[OUTLET_SWITCH_SYNC] ❌ VERIFICATION FAILED - Missing data');
        debugPrint('[OUTLET_SWITCH_SYNC] Empty tables: ${emptyTables.join(", ")}');
      }
      debugPrint('');

      return OutletVerificationResult(
        isReady: isReady,
        tableCounts: tableCounts,
        emptyTables: emptyTables,
      );

    } catch (e, stackTrace) {
      debugPrint('[OUTLET_SWITCH_SYNC] ❌ VERIFICATION ERROR: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('');

      return OutletVerificationResult(
        isReady: false,
        tableCounts: tableCounts,
        emptyTables: requiredTables,
        error: e.toString(),
      );
    }
  }

  /// Sync a single table from Supabase to local mirror
  /// Reuses logic from MirrorContentSyncService but with focused logging
  Future<_TableSyncResult> _syncSingleTable(String tableName, String outletId) async {
    try {
      final db = await _db.database;
      final supabase = SupabaseConfig.client;

      // Check if table exists locally
      final tableExists = await _tableExists(db, tableName);
      if (!tableExists) {
        return _TableSyncResult(
          success: false,
          rowsSynced: 0,
          error: 'Table does not exist locally',
        );
      }

      // Fetch data from Supabase with outlet filter
      var query = supabase.from(tableName).select();
      
      // All required tables should be filtered by outlet_id
      query = query.eq('outlet_id', outletId);

      final response = await query;
      final rows = response as List<dynamic>;

      // Clear existing local data for this outlet
      await db.delete(
        tableName,
        where: 'outlet_id = ?',
        whereArgs: [outletId],
      );

      // Get local table columns
      final localColumns = await _getLocalTableColumns(db, tableName);

      // Insert data into local mirror
      int insertedCount = 0;
      
      for (final row in rows) {
        try {
          final rowData = row as Map<String, dynamic>;
          final sanitizedData = _sanitizeDataForSQLite(rowData);
          
          // Filter to only include columns that exist in local table
          final filteredData = <String, dynamic>{};
          for (final entry in sanitizedData.entries) {
            if (localColumns.contains(entry.key)) {
              filteredData[entry.key] = entry.value;
            }
          }
          
          await db.insert(
            tableName,
            filteredData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          insertedCount++;
        } catch (e) {
          debugPrint('[OUTLET_SWITCH_SYNC]     ⚠️ Failed to insert row: $e');
        }
      }

      return _TableSyncResult(
        success: true,
        rowsSynced: insertedCount,
      );

    } catch (e) {
      return _TableSyncResult(
        success: false,
        rowsSynced: 0,
        error: e.toString(),
      );
    }
  }

  /// Check if table exists in local database
  Future<bool> _tableExists(dynamic db, String tableName) async {
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

  /// Get row count for a table filtered by outlet_id
  Future<int> _getRowCount(dynamic db, String tableName, String outletId) async {
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE outlet_id = ?',
        [outletId],
      );
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      debugPrint('[OUTLET_SWITCH_SYNC] ⚠️ Failed to count rows for $tableName: $e');
      return 0;
    }
  }

  /// Get list of column names for a local table
  Future<List<String>> _getLocalTableColumns(dynamic db, String tableName) async {
    try {
      final columnsResult = await db.rawQuery('PRAGMA table_info($tableName)');
      return columnsResult.map((col) => col['name'] as String).toList();
    } catch (e) {
      debugPrint('[OUTLET_SWITCH_SYNC] ⚠️ Failed to get columns for $tableName: $e');
      return [];
    }
  }

  /// Sanitize data for SQLite storage
  Map<String, dynamic> _sanitizeDataForSQLite(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value == null) {
        sanitized[key] = null;
      } else if (value is Map || value is List) {
        // Convert complex types to JSON strings
        sanitized[key] = value.toString();
      } else if (value is DateTime) {
        sanitized[key] = value.toIso8601String();
      } else {
        sanitized[key] = value;
      }
    }
    
    return sanitized;
  }
}

/// Result of outlet switch sync operation
class OutletSwitchSyncResult {
  final bool success;
  final int totalRows;
  final Map<String, int> tableCounts;
  final List<String> failedTables;
  final String? error;

  OutletSwitchSyncResult({
    required this.success,
    required this.totalRows,
    required this.tableCounts,
    required this.failedTables,
    this.error,
  });

  String get summary {
    if (error != null) return 'Error: $error';
    if (success) return 'Synced $totalRows rows across ${tableCounts.length} tables';
    return 'Failed to sync ${failedTables.length} tables: ${failedTables.join(", ")}';
  }
}

/// Result of outlet verification operation
class OutletVerificationResult {
  final bool isReady;
  final Map<String, int> tableCounts;
  final List<String> emptyTables;
  final String? error;

  OutletVerificationResult({
    required this.isReady,
    required this.tableCounts,
    required this.emptyTables,
    this.error,
  });

  String get summary {
    if (error != null) return 'Verification error: $error';
    if (isReady) return 'All required tables populated';
    return 'Missing data in ${emptyTables.length} tables: ${emptyTables.join(", ")}';
  }
}

/// Internal result for single table sync
class _TableSyncResult {
  final bool success;
  final int rowsSynced;
  final String? error;

  _TableSyncResult({
    required this.success,
    required this.rowsSynced,
    this.error,
  });
}
