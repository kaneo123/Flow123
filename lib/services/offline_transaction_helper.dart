import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/services/device_identification_service.dart';

/// Helper service for managing local-only offline sync columns
/// in transactional tables (orders, order_items, transactions)
/// 
/// These columns track sync status and are NOT part of Supabase schema
class OfflineTransactionHelper {
  static final OfflineTransactionHelper _instance = OfflineTransactionHelper._internal();
  factory OfflineTransactionHelper() => _instance;
  OfflineTransactionHelper._internal();

  final AppDatabase _db = AppDatabase.instance;
  final DeviceIdentificationService _deviceService = DeviceIdentificationService.instance;

  /// Sync statuses
  static const String statusPending = 'pending';
  static const String statusSynced = 'synced';
  static const String statusFailed = 'failed';

  /// Get device ID for tracking which device created the transaction
  Future<String> _getDeviceId() async {
    return await _deviceService.getDeviceId();
  }

  /// Mark a transaction as pending sync
  /// Call this when creating/updating orders, order_items, or transactions locally
  Future<void> markAsPending({
    required String tableName,
    required String entityId,
  }) async {
    try {
      final db = await _db.database;
      final deviceId = await _getDeviceId();
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.update(
        tableName,
        {
          'sync_status': statusPending,
          'sync_error': null,
          'last_sync_attempt_at': null,
          'sync_attempt_count': 0,
          'device_id': deviceId,
        },
        where: 'id = ?',
        whereArgs: [entityId],
      );

      debugPrint('📝 Marked $tableName/$entityId as pending sync');
    } catch (e) {
      debugPrint('⚠️ Failed to mark as pending: $e');
    }
  }

  /// Mark a transaction as successfully synced
  Future<void> markAsSynced({
    required String tableName,
    required String entityId,
  }) async {
    try {
      final db = await _db.database;

      await db.update(
        tableName,
        {
          'sync_status': statusSynced,
          'sync_error': null,
          'last_sync_attempt_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [entityId],
      );

      debugPrint('✅ Marked $tableName/$entityId as synced');
    } catch (e) {
      debugPrint('⚠️ Failed to mark as synced: $e');
    }
  }

  /// Mark a transaction as failed to sync
  Future<void> markAsFailed({
    required String tableName,
    required String entityId,
    required String errorMessage,
  }) async {
    try {
      final db = await _db.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Get current attempt count
      final result = await db.query(
        tableName,
        columns: ['sync_attempt_count'],
        where: 'id = ?',
        whereArgs: [entityId],
      );

      final currentAttempts = result.isNotEmpty 
          ? (result.first['sync_attempt_count'] as int?) ?? 0
          : 0;

      await db.update(
        tableName,
        {
          'sync_status': statusFailed,
          'sync_error': errorMessage,
          'last_sync_attempt_at': now,
          'sync_attempt_count': currentAttempts + 1,
        },
        where: 'id = ?',
        whereArgs: [entityId],
      );

      debugPrint('❌ Marked $tableName/$entityId as failed (attempts: ${currentAttempts + 1})');
    } catch (e) {
      debugPrint('⚠️ Failed to mark as failed: $e');
    }
  }

  /// Get all pending transactions for a specific table
  Future<List<Map<String, dynamic>>> getPendingTransactions(String tableName) async {
    try {
      final db = await _db.database;

      final result = await db.query(
        tableName,
        where: 'sync_status = ?',
        whereArgs: [statusPending],
        orderBy: 'created_at ASC',
      );

      return result;
    } catch (e) {
      debugPrint('❌ Failed to get pending transactions from $tableName: $e');
      return [];
    }
  }

  /// Get all failed transactions for a specific table
  Future<List<Map<String, dynamic>>> getFailedTransactions(String tableName) async {
    try {
      final db = await _db.database;

      final result = await db.query(
        tableName,
        where: 'sync_status = ?',
        whereArgs: [statusFailed],
        orderBy: 'last_sync_attempt_at ASC',
      );

      return result;
    } catch (e) {
      debugPrint('❌ Failed to get failed transactions from $tableName: $e');
      return [];
    }
  }

  /// Get sync statistics for a table
  Future<Map<String, int>> getSyncStats(String tableName) async {
    try {
      final db = await _db.database;

      final result = await db.rawQuery('''
        SELECT sync_status, COUNT(*) as count 
        FROM $tableName 
        WHERE sync_status IS NOT NULL
        GROUP BY sync_status
      ''');

      final stats = <String, int>{
        statusPending: 0,
        statusSynced: 0,
        statusFailed: 0,
      };

      for (final row in result) {
        final status = row['sync_status'] as String?;
        final count = row['count'] as int;
        if (status != null) {
          stats[status] = count;
        }
      }

      return stats;
    } catch (e) {
      debugPrint('❌ Failed to get sync stats for $tableName: $e');
      return {};
    }
  }

  /// Get all sync statistics across all transactional tables
  Future<Map<String, Map<String, int>>> getAllSyncStats() async {
    final tables = ['orders', 'order_items', 'transactions'];
    final allStats = <String, Map<String, int>>{};

    for (final table in tables) {
      allStats[table] = await getSyncStats(table);
    }

    return allStats;
  }

  /// Reset failed transactions back to pending (for retry)
  Future<int> retryFailedTransactions(String tableName, {int? maxAttempts}) async {
    try {
      final db = await _db.database;

      final whereClause = maxAttempts != null
          ? 'sync_status = ? AND sync_attempt_count < ?'
          : 'sync_status = ?';

      final whereArgs = maxAttempts != null
          ? [statusFailed, maxAttempts]
          : [statusFailed];

      final count = await db.update(
        tableName,
        {
          'sync_status': statusPending,
          'sync_error': null,
        },
        where: whereClause,
        whereArgs: whereArgs,
      );

      debugPrint('🔄 Retried $count failed transactions in $tableName');
      return count;
    } catch (e) {
      debugPrint('❌ Failed to retry transactions: $e');
      return 0;
    }
  }

  /// Check if a specific transaction is pending sync
  Future<bool> isPendingSync({
    required String tableName,
    required String entityId,
  }) async {
    try {
      final db = await _db.database;

      final result = await db.query(
        tableName,
        columns: ['sync_status'],
        where: 'id = ? AND sync_status = ?',
        whereArgs: [entityId, statusPending],
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Failed to check pending sync status: $e');
      return false;
    }
  }

  /// Initialize sync columns for a new transaction
  /// Returns a map of sync column values to include when inserting
  Future<Map<String, dynamic>> getInitialSyncColumns() async {
    final deviceId = await _getDeviceId();
    
    return {
      'sync_status': statusPending,
      'sync_error': null,
      'last_sync_attempt_at': null,
      'sync_attempt_count': 0,
      'device_id': deviceId,
    };
  }

  /// Clean up old synced records (optional maintenance)
  /// Removes sync metadata from successfully synced transactions older than specified days
  Future<int> cleanupOldSyncedRecords({
    required String tableName,
    int daysOld = 30,
  }) async {
    try {
      final db = await _db.database;
      final cutoffTime = DateTime.now()
          .subtract(Duration(days: daysOld))
          .millisecondsSinceEpoch;

      final count = await db.update(
        tableName,
        {
          'sync_status': null,
          'sync_error': null,
          'last_sync_attempt_at': null,
          'sync_attempt_count': null,
          'device_id': null,
        },
        where: 'sync_status = ? AND last_sync_attempt_at < ?',
        whereArgs: [statusSynced, cutoffTime],
      );

      debugPrint('🧹 Cleaned up $count old synced records from $tableName');
      return count;
    } catch (e) {
      debugPrint('❌ Failed to cleanup synced records: $e');
      return 0;
    }
  }
}
