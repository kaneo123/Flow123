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
  ];

  static const List<String> _bucketBSecondary = [
    'promotions',
    'packaged_deals',
    'packaged_deal_components',
    'inventory_items',
  ];

  // Bucket C is handled separately with status filters for live operational data

  /// Run automatic startup content sync
  /// Must be called after schema sync completes
  /// Returns true if sync completed successfully, false otherwise
  Future<bool> runStartupSync(String outletId) async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[STARTUP_SYNC] AUTOMATIC STARTUP CONTENT SYNC - BEGIN');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[STARTUP_SYNC] Outlet ID: $outletId');

    try {
      _updateProgress(
        currentStepLabel: 'Preparing database...',
        percentComplete: 0,
        isRunning: true,
      );

      // Bucket A: Core required data (60% of progress)
      debugPrint('[STARTUP_SYNC] === Bucket A: Core Required Data ===');
      await _syncBucketA(outletId);

      // Bucket B: Secondary content (20% of progress)
      debugPrint('[STARTUP_SYNC] === Bucket B: Secondary Content ===');
      await _syncBucketB(outletId);

      // Bucket C: Live operational data (20% of progress)
      debugPrint('[STARTUP_SYNC] === Bucket C: Live Operational Data ===');
      await _syncBucketC(outletId);

      // Run validation and diagnostics
      debugPrint('[STARTUP_SYNC] === Running Validation & Diagnostics ===');
      if (!kIsWeb) {
        await _validation.validateOutletData(outletId);
      }

      _updateProgress(
        currentStepLabel: 'Ready to go!',
        percentComplete: 100,
        isRunning: false,
        isComplete: true,
      );

      debugPrint('[STARTUP_SYNC] ✅ AUTOMATIC STARTUP CONTENT SYNC - SUCCESS');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');

      return true;

    } catch (e, stackTrace) {
      debugPrint('[STARTUP_SYNC] ❌ STARTUP SYNC FAILED: $e');
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

  /// Sync Bucket A: Core required data
  Future<void> _syncBucketA(String outletId) async {
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
    };

    for (final tableName in _bucketACoreRequired) {
      final label = friendlyLabels[tableName] ?? 'Loading $tableName';
      
      _updateProgress(
        currentStepLabel: '$label...',
        percentComplete: (completed / totalTables * 60).round(), // 0-60%
        isRunning: true,
      );

      debugPrint('[STARTUP_SYNC] Syncing core table: $tableName');
      final result = await _mirrorSync.syncSingleTable(tableName, outletId);
      
      if (result.success) {
        debugPrint('[STARTUP_SYNC]   ✅ $tableName: ${result.rowsSynced} rows');
      } else {
        debugPrint('[STARTUP_SYNC]   ⚠️ $tableName failed: ${result.error}');
        // Continue with other tables even if one fails
      }

      completed++;
    }

    debugPrint('[STARTUP_SYNC] Bucket A complete: $completed/$totalTables tables');
  }

  /// Sync Bucket B: Secondary content
  Future<void> _syncBucketB(String outletId) async {
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

      debugPrint('[STARTUP_SYNC] Syncing secondary table: $tableName');
      final result = await _mirrorSync.syncSingleTable(tableName, outletId);
      
      if (result.success) {
        debugPrint('[STARTUP_SYNC]   ✅ $tableName: ${result.rowsSynced} rows');
      } else {
        debugPrint('[STARTUP_SYNC]   ⚠️ $tableName failed: ${result.error}');
        // Continue with other tables even if one fails
      }

      completed++;
    }

    debugPrint('[STARTUP_SYNC] Bucket B complete: $completed/$totalTables tables');
  }

  /// Sync Bucket C: Live operational data only (no historical data)
  Future<void> _syncBucketC(String outletId) async {
    _updateProgress(
      currentStepLabel: 'Syncing live tables...',
      percentComplete: 80,
      isRunning: true,
    );

    debugPrint('[STARTUP_SYNC] Syncing live operational data...');

    // Sync open/parked orders only
    _updateProgress(
      currentStepLabel: 'Loading active orders...',
      percentComplete: 85,
      isRunning: true,
    );
    await _syncLiveOrders(outletId);

    // 4. Table sessions are cloud-only (no longer synced to local mirror)
    debugPrint('[STARTUP_SYNC] 4. Table sessions: SKIPPED (cloud-only live presence data)');

    _updateProgress(
      currentStepLabel: 'Almost there...',
      percentComplete: 98,
      isRunning: true,
    );

    debugPrint('[STARTUP_SYNC] Bucket C complete');
  }

  /// Sync only open/parked orders and their items
  Future<void> _syncLiveOrders(String outletId) async {
    try {
      final supabase = SupabaseConfig.client;

      // Fetch open/parked orders only
      debugPrint('[STARTUP_SYNC]   Fetching open/parked orders...');
      final ordersResponse = await supabase
          .from('orders')
          .select()
          .eq('outlet_id', outletId)
          .inFilter('status', ['open', 'parked']);

      final orders = ordersResponse as List<dynamic>;
      debugPrint('[STARTUP_SYNC]   Found ${orders.length} active orders');

      // Write orders to local mirror
      final insertedOrders = await _writeOrdersToLocalMirror(orders);
      
      if (orders.isNotEmpty && insertedOrders == 0) {
        debugPrint('[STARTUP_SYNC]   ⚠️ Table failed: fetched ${orders.length} orders, inserted 0');
      }

      // Fetch order items for these orders
      if (orders.isNotEmpty) {
        final orderIds = orders.map((o) => o['id']).toList();
        debugPrint('[STARTUP_SYNC]   Fetching order items for active orders...');
        
        final itemsResponse = await supabase
            .from('order_items')
            .select()
            .inFilter('order_id', orderIds);

        final items = itemsResponse as List<dynamic>;
        debugPrint('[STARTUP_SYNC]   Found ${items.length} order items');

        // Write order items to local mirror
        final insertedItems = await _writeOrderItemsToLocalMirror(items);
        
        if (items.isNotEmpty && insertedItems == 0) {
          debugPrint('[STARTUP_SYNC]   ⚠️ Table failed: fetched ${items.length} order items, inserted 0');
        } else {
          debugPrint('[STARTUP_SYNC]   ✅ Order items synced: $insertedItems rows');
        }
      }

      debugPrint('[STARTUP_SYNC]   ✅ Live orders synced: $insertedOrders orders');
    } catch (e, stackTrace) {
      debugPrint('[STARTUP_SYNC]   ⚠️ Live orders sync failed: $e');
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
  Future<int> _writeOrdersToLocalMirror(List<dynamic> orders) async {
    try {
      final db = await AppDatabase.instance.database;
      
      // Get local table columns
      final localColumns = await _getLocalTableColumns(db, 'orders');
      debugPrint('[STARTUP_SYNC]   📋 Local orders table has ${localColumns.length} columns');
      
      // Delete existing open/parked orders
      await db.delete(
        'orders',
        where: 'status IN (?, ?)',
        whereArgs: ['open', 'parked'],
      );

      // Insert new orders
      int insertedCount = 0;
      final Set<String> skippedColumns = {};
      
      for (final order in orders) {
        try {
          final orderData = order as Map<String, dynamic>;
          final sanitized = _mirrorSync.sanitizeDataForSQLite(orderData);
          
          // Filter to only include columns that exist in local table
          final filtered = _filterToLocalColumns(sanitized, localColumns);
          
          // Track skipped columns
          for (final key in sanitized.keys) {
            if (!localColumns.contains(key)) {
              skippedColumns.add(key);
            }
          }
          
          await db.insert('orders', filtered);
          insertedCount++;
        } catch (e) {
          debugPrint('[STARTUP_SYNC]     ⚠️ Failed to insert order: $e');
        }
      }
      
      if (skippedColumns.isNotEmpty) {
        debugPrint('[STARTUP_SYNC]   ℹ️ Skipped non-existent columns during orders insert: ${skippedColumns.join(", ")}');
      }
      
      return insertedCount;
    } catch (e, stackTrace) {
      debugPrint('[STARTUP_SYNC]   ⚠️ Failed to write orders to local mirror: $e');
      debugPrint('Stack: $stackTrace');
      return 0;
    }
  }

  /// Write order items to local mirror table
  /// Returns the count of successfully inserted rows
  Future<int> _writeOrderItemsToLocalMirror(List<dynamic> items) async {
    try {
      final db = await AppDatabase.instance.database;
      
      // Get local table columns
      final localColumns = await _getLocalTableColumns(db, 'order_items');
      
      // For order items, we'll replace all since we only have active orders
      await db.delete('order_items');

      // Insert new items
      int insertedCount = 0;
      for (final item in items) {
        try {
          final itemData = item as Map<String, dynamic>;
          final sanitized = _mirrorSync.sanitizeDataForSQLite(itemData);
          
          // Filter to only include columns that exist in local table
          final filtered = _filterToLocalColumns(sanitized, localColumns);
          
          await db.insert('order_items', filtered);
          insertedCount++;
        } catch (e) {
          debugPrint('[STARTUP_SYNC]     ⚠️ Failed to insert order item: $e');
        }
      }
      
      return insertedCount;
    } catch (e, stackTrace) {
      debugPrint('[STARTUP_SYNC]   ⚠️ Failed to write order items to local mirror: $e');
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

  /// Dispose resources
  void dispose() {
    _progressController.close();
  }
}
