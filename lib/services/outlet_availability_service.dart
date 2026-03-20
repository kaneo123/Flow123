import 'package:flutter/foundation.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/services/connection_service.dart';

/// Service to check if an outlet is available for offline use
/// Verifies that all required tables have local data for the outlet
class OutletAvailabilityService {
  static final OutletAvailabilityService _instance = OutletAvailabilityService._internal();
  factory OutletAvailabilityService() => _instance;
  OutletAvailabilityService._internal();

  final AppDatabase _db = AppDatabase.instance;
  final ConnectionService _connectionService = ConnectionService();

  /// Minimum required tables for offline operation
  /// Must match OutletSwitchSyncService.requiredTables
  static const List<String> _requiredTables = [
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

  /// Optional but recommended tables
  static const List<String> _recommendedTables = [
    'promotions',
    'packaged_deals',
    'packaged_deal_components',
  ];

  /// Global/shared tables that should NOT be filtered by outlet_id
  /// These tables are synced globally and shared across all outlets
  /// Must match MirrorContentSyncService.outletFilteredTables (inverse)
  static const List<String> _globalTables = [
    'outlets',
    'staff',
    'tax_rates',
    'packaged_deal_components',
    'order_items', // linked to orders, not outlet-scoped directly
  ];

  /// Check if an outlet is available for offline use
  /// Returns true if all required tables have data for this outlet
  Future<OutletAvailabilityResult> isOutletAvailableOffline(String outletId) async {
    debugPrint('');
    debugPrint('[OUTLET_AVAILABILITY] Checking availability for outlet: $outletId');
    
    try {
      final db = await _db.database;
      final Map<String, int> tableCounts = {};
      final List<String> missingTables = [];
      final List<String> emptyTables = [];

      // Check each required table
      for (final tableName in _requiredTables) {
        final exists = await _tableExists(db, tableName);
        
        if (!exists) {
          debugPrint('[OUTLET_AVAILABILITY]   ❌ $tableName: table does not exist');
          missingTables.add(tableName);
          tableCounts[tableName] = 0;
          continue;
        }

        final count = await _getRowCount(db, tableName, outletId);
        tableCounts[tableName] = count;

        if (count == 0) {
          debugPrint('[OUTLET_AVAILABILITY]   ⚠️ $tableName: 0 rows (EMPTY)');
          emptyTables.add(tableName);
        } else {
          debugPrint('[OUTLET_AVAILABILITY]   ✅ $tableName: $count rows');
        }
      }

      // Also check recommended tables (for diagnostics only)
      for (final tableName in _recommendedTables) {
        final exists = await _tableExists(db, tableName);
        if (exists) {
          final count = await _getRowCount(db, tableName, outletId);
          tableCounts[tableName] = count;
          debugPrint('[OUTLET_AVAILABILITY]   ℹ️ $tableName: $count rows (optional)');
        }
      }

      final isAvailable = missingTables.isEmpty && emptyTables.isEmpty;
      
      debugPrint('[OUTLET_AVAILABILITY] Result: ${isAvailable ? "✅ AVAILABLE" : "❌ NOT AVAILABLE"}');
      if (!isAvailable) {
        if (missingTables.isNotEmpty) {
          debugPrint('[OUTLET_AVAILABILITY] Missing tables: ${missingTables.join(", ")}');
        }
        if (emptyTables.isNotEmpty) {
          debugPrint('[OUTLET_AVAILABILITY] Empty tables: ${emptyTables.join(", ")}');
        }
      }
      debugPrint('');

      return OutletAvailabilityResult(
        outletId: outletId,
        isAvailable: isAvailable,
        tableCounts: tableCounts,
        missingTables: missingTables,
        emptyTables: emptyTables,
      );
    } catch (e, stackTrace) {
      debugPrint('[OUTLET_AVAILABILITY] ❌ Error checking availability: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('');
      
      return OutletAvailabilityResult(
        outletId: outletId,
        isAvailable: false,
        tableCounts: {},
        missingTables: [],
        emptyTables: [],
        error: e.toString(),
      );
    }
  }

  /// Check if outlet switching is allowed based on online/offline status
  Future<OutletSwitchValidation> validateOutletSwitch(
    String currentOutletId,
    String newOutletId,
  ) async {
    debugPrint('[OUTLET_AVAILABILITY] Validating outlet switch');
    debugPrint('[OUTLET_AVAILABILITY]   From: $currentOutletId');
    debugPrint('[OUTLET_AVAILABILITY]   To: $newOutletId');

    final isOnline = _connectionService.isOnline;
    debugPrint('[OUTLET_AVAILABILITY]   Connection: ${isOnline ? "ONLINE" : "OFFLINE"}');

    if (isOnline) {
      // Online: switching is allowed, but we should sync first
      debugPrint('[OUTLET_AVAILABILITY]   ✅ Switch allowed (online mode)');
      debugPrint('[OUTLET_AVAILABILITY]   Will trigger sync for new outlet');
      return OutletSwitchValidation(
        canSwitch: true,
        requiresSync: true,
        reason: 'Online - will sync outlet data',
      );
    } else {
      // Offline: check if new outlet is available locally
      final availability = await isOutletAvailableOffline(newOutletId);
      
      if (availability.isAvailable) {
        debugPrint('[OUTLET_AVAILABILITY]   ✅ Switch allowed (outlet available offline)');
        return OutletSwitchValidation(
          canSwitch: true,
          requiresSync: false,
          reason: 'Outlet data available locally',
        );
      } else {
        debugPrint('[OUTLET_AVAILABILITY]   ❌ Switch blocked (outlet not available offline)');
        
        String reason = 'This outlet has not been downloaded for offline use yet.';
        if (availability.emptyTables.isNotEmpty) {
          reason += '\n\nMissing data for: ${availability.emptyTables.join(", ")}';
        }
        
        return OutletSwitchValidation(
          canSwitch: false,
          requiresSync: false,
          reason: reason,
          availability: availability,
        );
      }
    }
  }

  /// Check if a table exists in local database
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

  /// Get row count for a table
  /// Global/shared tables are counted globally (all rows)
  /// Outlet-scoped tables are filtered by outlet_id
  Future<int> _getRowCount(dynamic db, String tableName, String outletId) async {
    try {
      // Check if this is a global/shared table first
      if (_globalTables.contains(tableName)) {
        // Global table - count ALL rows (not filtered by outlet)
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
        final count = (result.first['count'] as int?) ?? 0;
        debugPrint('[OUTLET_AVAILABILITY]   🌍 $tableName: global table, counting all rows');
        return count;
      }
      
      // Check if table has outlet_id column
      final columnsResult = await db.rawQuery('PRAGMA table_info($tableName)');
      final hasOutletId = columnsResult.any((col) => col['name'] == 'outlet_id');
      
      if (hasOutletId) {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE outlet_id = ?',
          [outletId],
        );
        return (result.first['count'] as int?) ?? 0;
      } else {
        // For tables without outlet_id, just count all rows
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
        return (result.first['count'] as int?) ?? 0;
      }
    } catch (e) {
      debugPrint('[OUTLET_AVAILABILITY] ⚠️ Failed to count rows for $tableName: $e');
      return 0;
    }
  }
}

/// Result of outlet availability check
class OutletAvailabilityResult {
  final String outletId;
  final bool isAvailable;
  final Map<String, int> tableCounts;
  final List<String> missingTables;
  final List<String> emptyTables;
  final String? error;

  OutletAvailabilityResult({
    required this.outletId,
    required this.isAvailable,
    required this.tableCounts,
    required this.missingTables,
    required this.emptyTables,
    this.error,
  });

  String get summary {
    if (error != null) return 'Error: $error';
    if (isAvailable) return 'Available offline';
    
    final issues = <String>[];
    if (missingTables.isNotEmpty) {
      issues.add('Missing: ${missingTables.join(", ")}');
    }
    if (emptyTables.isNotEmpty) {
      issues.add('Empty: ${emptyTables.join(", ")}');
    }
    return issues.join(' | ');
  }
}

/// Result of outlet switch validation
class OutletSwitchValidation {
  final bool canSwitch;
  final bool requiresSync;
  final String reason;
  final OutletAvailabilityResult? availability;

  OutletSwitchValidation({
    required this.canSwitch,
    required this.requiresSync,
    required this.reason,
    this.availability,
  });
}
