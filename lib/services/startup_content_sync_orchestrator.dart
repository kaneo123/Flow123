import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flowtill/models/startup_sync_progress.dart';
import 'package:flowtill/services/mirror_content_sync_service.dart';
import 'package:flowtill/services/startup_validation_service.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/supabase/supabase_config.dart';

/// Orchestrates automatic content sync on app startup after schema sync
/// Syncs essential content tables + live operational data only (no history)
class StartupContentSyncOrchestrator {
  static final StartupContentSyncOrchestrator _instance = StartupContentSyncOrchestrator._internal();
  factory StartupContentSyncOrchestrator() => _instance;
  StartupContentSyncOrchestrator._internal();

  final MirrorContentSyncService _mirrorSync = MirrorContentSyncService();
  final StartupValidationService _validation = StartupValidationService();
  
  // Progress stream for UI
  final _progressController = StreamController<StartupSyncProgress>.broadcast();
  Stream<StartupSyncProgress> get progressStream => _progressController.stream;
  
  StartupSyncProgress _currentProgress = StartupSyncProgress.initial();
  StartupSyncProgress get currentProgress => _currentProgress;

  // Sync buckets
  static const List<String> _bucketACoreRequired = [
    'outlets',
    'outlet_settings',
    'categories',
    'products',
    'tax_rates',
    'staff',
    'staff_outlets',
    'printers',
    'outlet_tables',
    'modifier_groups',
    'modifier_options',
    'product_modifier_groups',
    'trading_days', // CRITICAL: Required for Start Trading Day flows
  ];

  static const List<String> _bucketBSecondary = [
    'promotions',
    'packaged_deals',
    'packaged_deal_components',
    'inventory_items',
  ];

  // Bucket C is handled separately with status filters for live operational data

  /// UNIVERSAL METHOD: Prepare outlet for use by syncing all required data
  /// This is used for BOTH startup sync AND manual outlet switching
  /// Must be called after schema sync completes (for startup) or when switching outlets
  /// Returns true if sync completed successfully, false otherwise
  Future<bool> prepareOutletForUse(String outletId, {String context = 'STARTUP'}) async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[$context] PREPARING OUTLET FOR USE - BEGIN');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[$context] Outlet ID: $outletId');

    try {
      _updateProgress(
        currentStepLabel: 'Preparing database...',
        percentComplete: 0,
        isRunning: true,
      );

      // Bucket A: Core required data (60% of progress)
      debugPrint('[$context] === Bucket A: Core Required Data ===');
      await _syncBucketA(outletId, context: context);

      // Bucket B: Secondary content (20% of progress)
      debugPrint('[$context] === Bucket B: Secondary Content ===');
      await _syncBucketB(outletId, context: context);

      // Bucket C: Live operational data (20% of progress)
      debugPrint('[$context] === Bucket C: Live Operational Data ===');
      await _syncBucketC(outletId, context: context);

      // Run validation and diagnostics
      debugPrint('[$context] === Running Validation & Diagnostics ===');
      if (!kIsWeb) {
        await _validation.validateOutletData(outletId);
        
        // Print final sync summary
        debugPrint('');
        debugPrint('[$context] === FINAL SYNC SUMMARY ===');
        debugPrint('[$context] Tables scheduled for sync:');
        for (final table in _bucketACoreRequired) {
          final count = await _getLocalRowCount(table, outletId);
          debugPrint('[$context]   • $table: $count rows');
        }
        for (final table in _bucketBSecondary) {
          final count = await _getLocalRowCount(table, outletId);
          debugPrint('[$context]   • $table: $count rows');
        }
        debugPrint('[$context] === END SUMMARY ===');
        debugPrint('');
      }

      _updateProgress(
        currentStepLabel: 'Ready to go!',
        percentComplete: 100,
        isRunning: false,
        isComplete: true,
      );

      debugPrint('[$context] ✅ OUTLET PREPARATION - SUCCESS');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');

      return true;

    } catch (e, stackTrace) {
      debugPrint('[$context] ❌ OUTLET PREPARATION FAILED: $e');
      debugPrint('Stack: $stackTrace');
      
      _updateProgress(
        currentStepLabel: 'Sync failed',
        percentComplete: _currentProgress.percentComplete,
        isRunning: false,
        isComplete: false,
        errorMessage: e.toString(),
      );

      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');

      return false;
    }
  }

  /// Backward compatibility wrapper for startup flow
  /// Calls prepareOutletForUse with 'STARTUP_SYNC' context
  @Deprecated('Use prepareOutletForUse() instead')
  Future<bool> runStartupSync(String outletId) => prepareOutletForUse(outletId, context: 'STARTUP_SYNC');

  /// Sync Bucket A: Core required data
  Future<void> _syncBucketA(String outletId, {String context = 'STARTUP'}) async {
    final totalTables = _bucketACoreRequired.length;
    int completed = 0;

    // Map table names to user-friendly labels
    final Map<String, String> friendlyLabels = {
      'outlets': 'Loading outlets',
      'outlet_settings': 'Loading settings',
      'categories': 'Loading menu categories',
      'products': 'Syncing menu items',
      'tax_rates': 'Loading tax rates',
      'staff': 'Loading staff',
      'staff_outlets': 'Loading staff assignments',
      'printers': 'Loading printers',
      'outlet_tables': 'Loading tables',
      'modifier_groups': 'Loading modifiers',
      'modifier_options': 'Loading modifier options',
      'product_modifier_groups': 'Linking modifiers',
      'trading_days': 'Loading trading days',
    };

    for (final tableName in _bucketACoreRequired) {
      final label = friendlyLabels[tableName] ?? 'Loading $tableName';
      
      _updateProgress(
        currentStepLabel: '$label...',
        percentComplete: (completed / totalTables * 60).round(), // 0-60%
        isRunning: true,
      );

      debugPrint('[$context] Syncing core table: $tableName');
      final result = await _mirrorSync.syncSingleTable(tableName, outletId);
      
      if (result.success) {
        debugPrint('[$context]   ✅ $tableName: ${result.rowsSynced} rows synced');
        
        // Log local row count verification
        final localCount = await _getLocalRowCount(tableName, outletId);
        debugPrint('[$context]   📊 $tableName: local table now has $localCount rows');
      } else {
        debugPrint('[$context]   ⚠️ $tableName failed: ${result.error}');
        // Continue with other tables even if one fails
      }

      completed++;
    }

    debugPrint('[$context] Bucket A complete: $completed/$totalTables tables');
  }

  /// Sync Bucket B: Secondary content
  Future<void> _syncBucketB(String outletId, {String context = 'STARTUP'}) async {
    final totalTables = _bucketBSecondary.length;
    int completed = 0;

    // Map table names to user-friendly labels
    final Map<String, String> friendlyLabels = {
      'promotions': 'Loading promotions',
      'packaged_deals': 'Loading deals',
      'packaged_deal_components': 'Loading deal components',
      'inventory_items': 'Loading inventory',
    };

    for (final tableName in _bucketBSecondary) {
      final label = friendlyLabels[tableName] ?? 'Loading $tableName';
      
      _updateProgress(
        currentStepLabel: '$label...',
        percentComplete: 60 + (completed / totalTables * 20).round(), // 60-80%
        isRunning: true,
      );

      debugPrint('[$context] Syncing secondary table: $tableName');
      final result = await _mirrorSync.syncSingleTable(tableName, outletId);
      
      if (result.success) {
        debugPrint('[$context]   ✅ $tableName: ${result.rowsSynced} rows synced');
        
        // Log local row count verification
        final localCount = await _getLocalRowCount(tableName, outletId);
        debugPrint('[$context]   📊 $tableName: local table now has $localCount rows');
      } else {
        debugPrint('[$context]   ⚠️ $tableName failed: ${result.error}');
        // Continue with other tables even if one fails
      }

      completed++;
    }

    debugPrint('[$context] Bucket B complete: $completed/$totalTables tables');
  }

  /// Sync Bucket C: Live operational data only (no historical data)
  Future<void> _syncBucketC(String outletId, {String context = 'STARTUP'}) async {
    _updateProgress(
      currentStepLabel: 'Syncing live tables...',
      percentComplete: 80,
      isRunning: true,
    );

    debugPrint('[$context] Syncing live operational data...');

    // Sync open/parked orders only
    _updateProgress(
      currentStepLabel: 'Loading active orders...',
      percentComplete: 85,
      isRunning: true,
    );
    await _syncLiveOrders(outletId, context: context);

    // 4. Table sessions are cloud-only (no longer synced to local mirror)
    debugPrint('[$context] 4. Table sessions: SKIPPED (cloud-only live presence data)');

    _updateProgress(
      currentStepLabel: 'Almost there...',
      percentComplete: 98,
      isRunning: true,
    );

    debugPrint('[$context] Bucket C complete');
  }

  /// Sync only open/parked orders and their items
  Future<void> _syncLiveOrders(String outletId, {String context = 'STARTUP'}) async {
    try {
      final supabase = SupabaseConfig.client;

      // Fetch open/parked orders only
      debugPrint('[$context]   Fetching open/parked orders...');
      final ordersResponse = await supabase
          .from('orders')
          .select()
          .eq('outlet_id', outletId)
          .inFilter('status', ['open', 'parked']);

      final orders = ordersResponse as List<dynamic>;
      debugPrint('[$context]   Found ${orders.length} active orders');

      // Write orders to local mirror
      final insertedOrders = await _writeOrdersToLocalMirror(orders, context: context);
      
      if (orders.isNotEmpty && insertedOrders == 0) {
        debugPrint('[$context]   ⚠️ Table failed: fetched ${orders.length} orders, inserted 0');
      }

      // Fetch order items for these orders
      if (orders.isNotEmpty) {
        final orderIds = orders.map((o) => o['id']).toList();
        debugPrint('[$context]   Fetching order items for active orders...');
        
        final itemsResponse = await supabase
            .from('order_items')
            .select()
            .inFilter('order_id', orderIds);

        final items = itemsResponse as List<dynamic>;
        debugPrint('[$context]   Found ${items.length} order items');

        // Write order items to local mirror
        final insertedItems = await _writeOrderItemsToLocalMirror(items, context: context);
        
        if (items.isNotEmpty && insertedItems == 0) {
          debugPrint('[$context]   ⚠️ Table failed: fetched ${items.length} order items, inserted 0');
        } else {
          debugPrint('[$context]   ✅ Order items synced: $insertedItems rows');
        }
      }

      debugPrint('[$context]   ✅ Live orders synced: $insertedOrders orders');
    } catch (e, stackTrace) {
      debugPrint('[$context]   ⚠️ Live orders sync failed: $e');
      debugPrint('Stack: $stackTrace');
      // Don't throw - allow startup to continue even if live orders fail
    }
  }

  /// Table sessions are cloud-only and not synced to local mirror
  /// This method is kept for reference but no longer called
  /// Reason: table_sessions is volatile live-presence data that should be queried from Supabase only when needed
  Future<void> _syncActiveTableSessions_DEPRECATED(String outletId) async {
    // NO LONGER USED - table_sessions is cloud-only
  }

  /// Write orders to local mirror table (replace existing open/parked orders)
  /// Returns the count of successfully inserted rows
  /// 
  /// CRITICAL: Uses importMirroredRow to ensure cloud-origin orders are marked as synced
  Future<int> _writeOrdersToLocalMirror(List<dynamic> orders, {String context = 'STARTUP'}) async {
    try {
      final db = await AppDatabase.instance.database;
      
      // Get local table columns
      final localColumns = await _getLocalTableColumns(db, 'orders');
      debugPrint('[$context]   📋 Local orders table has ${localColumns.length} columns');
      
      // Check if table has offline sync support
      final hasOfflineSupport = localColumns.contains('sync_status');
      if (hasOfflineSupport) {
        debugPrint('[$context]   ✅ orders table has offline sync columns');
      }
      
      // Delete existing open/parked orders
      await db.delete(
        'orders',
        where: 'status IN (?, ?)',
        whereArgs: ['open', 'parked'],
      );

      // Import new orders using safe mirror import path
      int importedCount = 0;
      
      for (final order in orders) {
        try {
          final orderData = order as Map<String, dynamic>;
          
          // CRITICAL: Use importMirroredRow to ensure sync_status='synced'
          // This is a cloud-origin row, NOT a locally-created row
          await _mirrorSync.importMirroredRow('orders', orderData, context: context);
          importedCount++;
          
        } catch (e) {
          debugPrint('[$context]     ⚠️ Failed to import order: $e');
        }
      }
      
      // Validate sync status after import
      if (hasOfflineSupport && importedCount > 0) {
        await _validateBucketCSyncStatus(db, 'orders', context: context);
      }
      
      return importedCount;
    } catch (e, stackTrace) {
      debugPrint('[$context]   ⚠️ Failed to write orders to local mirror: $e');
      debugPrint('Stack: $stackTrace');
      return 0;
    }
  }

  /// Write order items to local mirror table
  /// Returns the count of successfully inserted rows
  /// 
  /// CRITICAL: Uses importMirroredRow to ensure cloud-origin items are marked as synced
  Future<int> _writeOrderItemsToLocalMirror(List<dynamic> items, {String context = 'STARTUP'}) async {
    try {
      final db = await AppDatabase.instance.database;
      
      // Get local table columns
      final localColumns = await _getLocalTableColumns(db, 'order_items');
      
      // Check if table has offline sync support
      final hasOfflineSupport = localColumns.contains('sync_status');
      if (hasOfflineSupport) {
        debugPrint('[$context]   ✅ order_items table has offline sync columns');
      }
      
      // For order items, we'll replace all since we only have active orders
      await db.delete('order_items');

      // Import new items using safe mirror import path
      int importedCount = 0;
      for (final item in items) {
        try {
          final itemData = item as Map<String, dynamic>;
          
          // CRITICAL: Use importMirroredRow to ensure sync_status='synced'
          // This is a cloud-origin row, NOT a locally-created row
          await _mirrorSync.importMirroredRow('order_items', itemData, context: context);
          importedCount++;
          
        } catch (e) {
          debugPrint('[$context]     ⚠️ Failed to import order item: $e');
        }
      }
      
      // Validate sync status after import
      if (hasOfflineSupport && importedCount > 0) {
        await _validateBucketCSyncStatus(db, 'order_items', context: context);
      }
      
      return importedCount;
    } catch (e, stackTrace) {
      debugPrint('[$context]   ⚠️ Failed to write order items to local mirror: $e');
      debugPrint('Stack: $stackTrace');
      return 0;
    }
  }

  /// DEPRECATED - Table sessions are cloud-only and no longer written to local mirror
  Future<int> _writeTableSessionsToLocalMirror_DEPRECATED(List<dynamic> sessions) async {
    // NO LONGER USED - table_sessions is cloud-only
    return 0;
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
      debugPrint('[STARTUP_SYNC] ⚠️ Failed to get columns for $tableName: $e');
      return {};
    }
  }

  /// Filter data to only include columns that exist in local table
  Map<String, dynamic> _filterToLocalColumns(
    Map<String, dynamic> data,
    Set<String> localColumns,
  ) {
    final filtered = <String, dynamic>{};
    for (final entry in data.entries) {
      if (localColumns.contains(entry.key)) {
        filtered[entry.key] = entry.value;
      }
    }
    return filtered;
  }

  /// Get local row count for a table (for diagnostics)
  /// Filters by outlet_id for outlet-scoped tables
  Future<int> _getLocalRowCount(String tableName, String outletId) async {
    try {
      final db = await AppDatabase.instance.database;
      
      // Tables that should be filtered by outlet_id
      // NOTE: Global tables like 'outlets', 'staff', 'tax_rates', 'packaged_deal_components' have no outlet_id column
      final outletFilteredTables = [
        'outlet_settings', 'categories', 'products', 'staff_outlets', 'printers',
        'promotions', 'outlet_tables', 'modifier_groups', 'modifier_options',
        'product_modifier_groups', 'packaged_deals',
        'inventory_items', 'stock_movements',
        'orders', 'order_items', 'transactions', 'trading_days',
      ];
      
      String query;
      List<dynamic> args;
      
      if (outletFilteredTables.contains(tableName)) {
        query = 'SELECT COUNT(*) as count FROM $tableName WHERE outlet_id = ?';
        args = [outletId];
      } else {
        // Global tables (outlets, staff, tax_rates, packaged_deal_components) - no outlet_id filter
        query = 'SELECT COUNT(*) as count FROM $tableName';
        args = [];
      }
      
      final result = await db.rawQuery(query, args);
      return result.first['count'] as int;
    } catch (e) {
      debugPrint('[STARTUP_SYNC] ⚠️ Failed to get row count for $tableName: $e');
      return 0;
    }
  }

  /// Update progress and emit to stream
  void _updateProgress({
    required String currentStepLabel,
    required int percentComplete,
    required bool isRunning,
    bool isComplete = false,
    String? errorMessage,
  }) {
    _currentProgress = StartupSyncProgress(
      currentStepLabel: currentStepLabel,
      percentComplete: percentComplete,
      isRunning: isRunning,
      isComplete: isComplete,
      errorMessage: errorMessage,
    );

    _progressController.add(_currentProgress);
  }

  /// Validate Bucket C sync status after import
  /// Ensures cloud-origin operational data is marked as synced
  Future<void> _validateBucketCSyncStatus(Database db, String tableName, {String context = 'STARTUP'}) async {
    try {
      final syncedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE sync_status = ?',
        ['synced'],
      );
      final synced = syncedResult.first['count'] as int;
      
      final pendingResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE sync_status = ?',
        ['pending'],
      );
      final pending = pendingResult.first['count'] as int;
      
      debugPrint('[$context]   📊 Bucket C validation for $tableName:');
      debugPrint('[$context]      - Synced (cloud-origin): $synced');
      debugPrint('[$context]      - Pending (should be 0): $pending');
      
      if (pending > 0) {
        debugPrint('[$context]   ⚠️ WARNING: $pending Bucket C rows incorrectly marked as pending');
        
        // Log sample
        final samplePending = await db.query(
          tableName,
          where: 'sync_status = ?',
          whereArgs: ['pending'],
          limit: 3,
        );
        
        for (final row in samplePending) {
          debugPrint('[$context]      - Incorrect pending row: id=${row['id']}');
        }
      } else {
        debugPrint('[$context]   ✅ VALIDATION PASSED: All Bucket C rows marked as synced');
      }
    } catch (e) {
      debugPrint('[$context]   ⚠️ Failed to validate Bucket C sync status: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _progressController.close();
  }
}
