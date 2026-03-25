import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:uuid/uuid.dart';

/// Service for managing the local-only sync_queue table
/// Tracks offline changes for orders, order_items, and transactions
/// that need to be synced to Supabase when connection is restored
class SyncQueueService {
  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;
  SyncQueueService._internal();

  final AppDatabase _db = AppDatabase.instance;
  final Uuid _uuid = const Uuid();

  /// Queue operations
  static const String operationInsert = 'INSERT';
  static const String operationUpdate = 'UPDATE';
  static const String operationDelete = 'DELETE';

  /// Queue statuses
  static const String statusPending = 'pending';
  static const String statusProcessing = 'processing';
  static const String statusFailed = 'failed';
  static const String statusCompleted = 'completed';

  /// Enqueue a change for later sync
  /// DEDUPLICATION: If a pending/processing item already exists for this entity,
  /// update its payload with latest state instead of creating a duplicate
  /// SMART OPERATION SEMANTICS: Use 'upsert' for cleaner queue management
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    Map<String, dynamic>? payload,
    int priority = 0,
  }) async {
    try {
      final db = await _db.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      // IMPROVED DEDUPE: Check for ANY pending/processing item for this entity
      // regardless of operation type (INSERT/UPDATE/UPSERT are semantically similar)
      // This prevents queue noise from repeated lifecycle edits (create -> park -> resume -> complete)
      final existing = await db.query(
        'sync_queue',
        where: 'entity_type = ? AND entity_id = ? AND status IN (?, ?)',
        whereArgs: [entityType, entityId, statusPending, statusProcessing],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Reuse existing queue entry with latest payload
        final existingId = existing.first['id'] as int;
        final existingOp = existing.first['operation'] as String;
        
        // Normalize operation to 'upsert' for cleaner semantics
        // First-time create = INSERT, later edits = UPDATE, but cloud uses UPSERT for both
        final normalizedOp = operation == operationInsert || operation == operationUpdate ? 'upsert' : operation;
        
        await db.update(
          'sync_queue',
          {
            'operation': normalizedOp,
            'payload': payload != null ? jsonEncode(payload) : null,
            'updated_at': now,
            'priority': priority,
          },
          where: 'id = ?',
          whereArgs: [existingId],
        );
        
        debugPrint('[OUTBOX_SYNC] 🔄 Reusing existing queue entry #$existingId for $entityType/$entityId');
        debugPrint('[OUTBOX_SYNC]    Replaced payload with latest state');
        if (existingOp != normalizedOp) {
          debugPrint('[OUTBOX_SYNC]    Operation normalized: $existingOp -> $normalizedOp');
        }
        return;
      }

      // No existing item - create new queue entry
      // Normalize operation for consistency
      final normalizedOp = operation == operationInsert || operation == operationUpdate ? 'upsert' : operation;
      
      final queueItem = {
        'id': _uuid.v4(),
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': normalizedOp,
        'payload': payload != null ? jsonEncode(payload) : null,
        'status': statusPending,
        'created_at': now,
        'updated_at': now,
        'last_attempt_at': null,
        'attempt_count': 0,
        'error_message': null,
        'priority': priority,
      };

      await db.insert('sync_queue', queueItem);
      debugPrint('[OUTBOX_SYNC] 📤 Enqueued new: $normalizedOp $entityType/$entityId (priority: $priority)');
    } catch (e) {
      debugPrint('❌ Failed to enqueue sync item: $e');
      rethrow;
    }
  }

  /// Get pending items from the queue, ordered by priority and age
  Future<List<Map<String, dynamic>>> getPendingItems({int? limit}) async {
    try {
      final db = await _db.database;

      final query = '''
        SELECT * FROM sync_queue 
        WHERE status = ?
        ORDER BY priority DESC, created_at ASC
        ${limit != null ? 'LIMIT $limit' : ''}
      ''';

      final result = await db.rawQuery(query, [statusPending]);
      return result;
    } catch (e) {
      debugPrint('❌ Failed to fetch pending queue items: $e');
      return [];
    }
  }

  /// Mark item as processing
  Future<void> markAsProcessing(String queueId) async {
    try {
      final db = await _db.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.update(
        'sync_queue',
        {
          'status': statusProcessing,
          'updated_at': now,
          'last_attempt_at': now,
        },
        where: 'id = ?',
        whereArgs: [queueId],
      );
    } catch (e) {
      debugPrint('❌ Failed to mark queue item as processing: $e');
    }
  }

  /// Mark item as completed and remove from queue
  Future<void> markAsCompleted(String queueId) async {
    try {
      final db = await _db.database;

      // Delete completed items to keep queue clean
      await db.delete(
        'sync_queue',
        where: 'id = ?',
        whereArgs: [queueId],
      );

      debugPrint('✅ Queue item completed and removed: $queueId');
    } catch (e) {
      debugPrint('❌ Failed to mark queue item as completed: $e');
    }
  }

  /// Mark item as failed and increment attempt count
  Future<void> markAsFailed(String queueId, String errorMessage) async {
    try {
      final db = await _db.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Get current attempt count
      final result = await db.query(
        'sync_queue',
        columns: ['attempt_count'],
        where: 'id = ?',
        whereArgs: [queueId],
      );

      final currentAttempts = result.isNotEmpty 
          ? (result.first['attempt_count'] as int?) ?? 0
          : 0;

      await db.update(
        'sync_queue',
        {
          'status': statusFailed,
          'updated_at': now,
          'attempt_count': currentAttempts + 1,
          'error_message': errorMessage,
        },
        where: 'id = ?',
        whereArgs: [queueId],
      );

      debugPrint('❌ Queue item marked as failed: $queueId (attempts: ${currentAttempts + 1})');
    } catch (e) {
      debugPrint('❌ Failed to mark queue item as failed: $e');
    }
  }

  /// Retry failed items (reset status to pending)
  Future<void> retryFailedItems({int? maxAttempts}) async {
    try {
      final db = await _db.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final whereClause = maxAttempts != null
          ? 'status = ? AND attempt_count < ?'
          : 'status = ?';

      final whereArgs = maxAttempts != null
          ? [statusFailed, maxAttempts]
          : [statusFailed];

      final count = await db.update(
        'sync_queue',
        {
          'status': statusPending,
          'updated_at': now,
        },
        where: whereClause,
        whereArgs: whereArgs,
      );

      debugPrint('🔄 Retried $count failed queue items');
    } catch (e) {
      debugPrint('❌ Failed to retry queue items: $e');
    }
  }

  /// Get queue statistics
  Future<Map<String, int>> getQueueStats() async {
    try {
      final db = await _db.database;

      final result = await db.rawQuery('''
        SELECT status, COUNT(*) as count 
        FROM sync_queue 
        GROUP BY status
      ''');

      final stats = <String, int>{
        statusPending: 0,
        statusProcessing: 0,
        statusFailed: 0,
      };

      for (final row in result) {
        final status = row['status'] as String;
        final count = row['count'] as int;
        stats[status] = count;
      }

      return stats;
    } catch (e) {
      debugPrint('❌ Failed to get queue stats: $e');
      return {};
    }
  }
  
  /// Get count of pending local-created rows for upload validation
  /// This queries the entity tables directly using sync_status
  /// CRITICAL: Only returns rows with sync_status='pending' (local-created)
  /// Excludes rows with sync_status='synced' (cloud-origin/mirrored)
  Future<Map<String, int>> getPendingEntityCounts(String outletId) async {
    try {
      final db = await _db.database;
      final counts = <String, int>{};
      
      // Tables with sync_status tracking
      final tables = ['orders', 'order_items', 'transactions'];
      
      for (final table in tables) {
        // Check if table exists and has sync_status column
        final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
        final hasSyncStatus = tableInfo.any((col) => col['name'] == 'sync_status');
        
        if (!hasSyncStatus) {
          counts[table] = 0;
          continue;
        }
        
        // Count ONLY pending rows (local-created, not yet uploaded)
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $table WHERE outlet_id = ? AND sync_status = ?',
          [outletId, 'pending'],
        );
        
        final count = result.first['count'] as int;
        counts[table] = count;
        
        if (count > 0) {
          debugPrint('📊 SyncQueue: $table has $count pending local-created rows (uploadable)');
        }
      }
      
      final totalPending = counts.values.fold(0, (sum, count) => sum + count);
      debugPrint('📊 SyncQueue: Total pending local rows: $totalPending');
      debugPrint('   ℹ️ Mirrored rows (sync_status=synced) are excluded from upload');
      
      return counts;
    } catch (e) {
      debugPrint('❌ Failed to get pending entity counts: $e');
      return {};
    }
  }

  /// Clear all completed items from queue
  Future<int> clearCompletedItems() async {
    try {
      final db = await _db.database;
      final count = await db.delete(
        'sync_queue',
        where: 'status = ?',
        whereArgs: [statusCompleted],
      );

      debugPrint('🧹 Cleared $count completed items from queue');
      return count;
    } catch (e) {
      debugPrint('❌ Failed to clear completed items: $e');
      return 0;
    }
  }

  /// Clear entire queue (use with caution)
  Future<void> clearAllItems() async {
    try {
      final db = await _db.database;
      await db.delete('sync_queue');
      debugPrint('🧹 Cleared all items from sync queue');
    } catch (e) {
      debugPrint('❌ Failed to clear queue: $e');
    }
  }

  /// Get specific queue item by ID
  Future<Map<String, dynamic>?> getQueueItem(String queueId) async {
    try {
      final db = await _db.database;
      final result = await db.query(
        'sync_queue',
        where: 'id = ?',
        whereArgs: [queueId],
        limit: 1,
      );

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      debugPrint('❌ Failed to get queue item: $e');
      return null;
    }
  }

  /// Check if entity has pending sync operations
  Future<bool> hasPendingSync(String entityType, String entityId) async {
    try {
      final db = await _db.database;
      final result = await db.query(
        'sync_queue',
        columns: ['id'],
        where: 'entity_type = ? AND entity_id = ? AND status IN (?, ?)',
        whereArgs: [entityType, entityId, statusPending, statusProcessing],
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Failed to check pending sync: $e');
      return false;
    }
  }

  /// Delete queue items for a specific entity
  /// Useful when an entity is deleted or no longer needs sync
  Future<void> deleteQueueItemsForEntity(String entityType, String entityId) async {
    try {
      final db = await _db.database;
      await db.delete(
        'sync_queue',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [entityType, entityId],
      );

      debugPrint('🗑️ Deleted queue items for $entityType/$entityId');
    } catch (e) {
      debugPrint('❌ Failed to delete queue items: $e');
    }
  }
  
  /// Get count of pending outbox items for a specific entity
  /// Useful for debugging duplicate queue entries
  Future<int> getPendingCountForEntity(String entityType, String entityId) async {
    try {
      final db = await _db.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue WHERE entity_type = ? AND entity_id = ? AND status IN (?, ?)',
        [entityType, entityId, statusPending, statusProcessing],
      );
      
      final count = result.first['count'] as int? ?? 0;
      return count;
    } catch (e) {
      debugPrint('❌ Failed to get pending count: $e');
      return 0;
    }
  }
}
