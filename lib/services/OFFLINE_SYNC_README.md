# Offline Transaction Sync System

## Overview

The offline transaction sync system extends the existing local SQLite schema sync to support offline-first transaction handling for orders, order_items, and transactions.

## Important Sync Rules

### Mirrored vs Locally-Created Records

**CRITICAL**: The system must distinguish between:

1. **Mirrored Records** (downloaded from Supabase):
   - Must be marked with `sync_status = 'synced'`
   - Must NOT be added to the sync_queue
   - Already exist in the cloud, no upload needed

2. **Locally-Created Records** (created on device):
   - Must be marked with `sync_status = 'pending'`
   - Must be added to the sync_queue for upload
   - Need to be synced to Supabase

**Implementation**:
- `MirrorContentSyncService` explicitly sets `sync_status = 'synced'` when mirroring records
- `OrderRepositoryOffline` and other repositories use `sync_status = 'pending'` and call `SyncQueueService.enqueue()` for locally-created records

## Architecture

### 1. Local-Only Columns (Transactional Tables)

The following tables have additional **local-only** columns that do NOT exist in Supabase:
- `orders`
- `order_items`
- `transactions`

#### Local-Only Column Schema

```sql
-- These columns are automatically added by schema_sync_service.dart
sync_status TEXT DEFAULT 'pending'      -- 'pending', 'synced', 'failed'
sync_error TEXT                         -- Error message if sync fails
last_sync_attempt_at INTEGER            -- Timestamp of last sync attempt
sync_attempt_count INTEGER DEFAULT 0    -- Number of times sync was attempted
device_id TEXT                          -- Device that created the transaction
```

### 2. Local-Only sync_queue Table

A dedicated queue table for tracking offline changes across all entity types.

```sql
CREATE TABLE sync_queue (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,            -- 'order', 'order_item', 'transaction'
  entity_id TEXT NOT NULL,              -- ID of the entity
  operation TEXT NOT NULL,              -- 'INSERT', 'UPDATE', 'DELETE'
  payload TEXT,                         -- JSON payload (optional)
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'processing', 'failed', 'completed'
  created_at INTEGER NOT NULL,
  updated_at INTEGER,
  last_attempt_at INTEGER,
  attempt_count INTEGER DEFAULT 0,
  error_message TEXT,
  priority INTEGER DEFAULT 0            -- Higher priority processed first
)
```

## Services

### SchemaSyncService

**Location**: `lib/services/schema_sync_service.dart`

**Responsibilities**:
- Syncs Supabase mirror tables to local SQLite
- Automatically adds local-only columns to transactional tables
- Creates local-only `sync_queue` table
- Preserves local-only columns during table rebuilds

**Configuration**:
```dart
// Tables that receive local-only sync columns
static const Set<String> _tablesWithOfflineSupport = {
  'orders',
  'order_items',
  'transactions',
};

// Local-only column definitions
static const Map<String, String> _localOnlyColumns = {
  'sync_status': 'TEXT DEFAULT "pending"',
  'sync_error': 'TEXT',
  'last_sync_attempt_at': 'INTEGER',
  'sync_attempt_count': 'INTEGER DEFAULT 0',
  'device_id': 'TEXT',
};
```

**Usage**:
The schema sync runs automatically during app startup. No manual intervention needed.

### SyncQueueService

**Location**: `lib/services/sync_queue_service.dart`

**Responsibilities**:
- Enqueue offline changes for later sync
- Track sync status and retry failed items
- Provide queue statistics and management

**Usage Example**:

```dart
import 'package:flowtill/services/sync_queue_service.dart';

final syncQueue = SyncQueueService();

// Enqueue a new order for sync
await syncQueue.enqueue(
  entityType: 'order',
  entityId: order.id,
  operation: SyncQueueService.operationInsert,
  payload: order.toJson(),
  priority: 10, // Higher priority for orders
);

// Get pending items to sync
final pendingItems = await syncQueue.getPendingItems(limit: 50);

// Process each item
for (final item in pendingItems) {
  await syncQueue.markAsProcessing(item['id']);
  
  try {
    // Attempt to sync to Supabase
    await _syncToSupabase(item);
    await syncQueue.markAsCompleted(item['id']);
  } catch (e) {
    await syncQueue.markAsFailed(item['id'], e.toString());
  }
}

// Get queue statistics
final stats = await syncQueue.getQueueStats();
debugPrint('Pending: ${stats['pending']}, Failed: ${stats['failed']}');
```

### OfflineTransactionHelper

**Location**: `lib/services/offline_transaction_helper.dart`

**Responsibilities**:
- Manage local-only sync columns in transactional tables
- Mark transactions as pending/synced/failed
- Track sync attempts and errors
- Query sync status across tables

**Usage Example**:

```dart
import 'package:flowtill/services/offline_transaction_helper.dart';

final offlineHelper = OfflineTransactionHelper();

// When creating a new order locally
final orderId = 'order-123';
await db.insert('orders', orderData);

// Mark it as pending sync
await offlineHelper.markAsPending(
  tableName: 'orders',
  entityId: orderId,
);

// When sync succeeds
await offlineHelper.markAsSynced(
  tableName: 'orders',
  entityId: orderId,
);

// When sync fails
await offlineHelper.markAsFailed(
  tableName: 'orders',
  entityId: orderId,
  errorMessage: 'Network error',
);

// Get all pending orders
final pendingOrders = await offlineHelper.getPendingTransactions('orders');

// Get sync statistics
final stats = await offlineHelper.getAllSyncStats();
debugPrint('Orders pending: ${stats['orders']['pending']}');

// Retry failed transactions (max 3 attempts)
await offlineHelper.retryFailedTransactions('orders', maxAttempts: 3);
```

## Integration Guide

### 1. Creating Transactions Offline

When creating orders, order_items, or transactions locally:

```dart
import 'package:flowtill/services/offline_transaction_helper.dart';
import 'package:flowtill/services/sync_queue_service.dart';

// Get initial sync column values
final offlineHelper = OfflineTransactionHelper();
final syncColumns = await offlineHelper.getInitialSyncColumns();

// Insert with sync columns
final orderData = {
  'id': orderId,
  'outlet_id': outletId,
  'total': 100.0,
  ...syncColumns, // Includes sync_status, device_id, etc.
};

await db.insert('orders', orderData);

// Add to sync queue
await SyncQueueService().enqueue(
  entityType: 'order',
  entityId: orderId,
  operation: SyncQueueService.operationInsert,
  payload: orderData,
  priority: 10,
);
```

### 2. Syncing to Supabase

Create a sync worker that processes the queue:

```dart
import 'package:flowtill/services/sync_queue_service.dart';
import 'package:flowtill/services/offline_transaction_helper.dart';
import 'package:flowtill/supabase/supabase_config.dart';

Future<void> processSyncQueue() async {
  final syncQueue = SyncQueueService();
  final offlineHelper = OfflineTransactionHelper();
  final supabase = SupabaseConfig.client;

  // Get pending items
  final pendingItems = await syncQueue.getPendingItems(limit: 20);

  for (final queueItem in pendingItems) {
    final entityType = queueItem['entity_type'] as String;
    final entityId = queueItem['entity_id'] as String;
    final operation = queueItem['operation'] as String;
    final payload = queueItem['payload'] as String?;

    await syncQueue.markAsProcessing(queueItem['id']);

    try {
      // Parse payload
      final data = payload != null ? jsonDecode(payload) : {};
      
      // Remove local-only columns before sending to Supabase
      data.remove('sync_status');
      data.remove('sync_error');
      data.remove('last_sync_attempt_at');
      data.remove('sync_attempt_count');
      data.remove('device_id');

      // Determine table name (plural form)
      final tableName = '${entityType}s'; // e.g., 'order' -> 'orders'

      // Execute operation
      if (operation == SyncQueueService.operationInsert) {
        await supabase.from(tableName).insert(data);
      } else if (operation == SyncQueueService.operationUpdate) {
        await supabase.from(tableName).update(data).eq('id', entityId);
      } else if (operation == SyncQueueService.operationDelete) {
        await supabase.from(tableName).delete().eq('id', entityId);
      }

      // Mark as synced
      await syncQueue.markAsCompleted(queueItem['id']);
      await offlineHelper.markAsSynced(
        tableName: tableName,
        entityId: entityId,
      );

      debugPrint('✅ Synced $entityType/$entityId');
    } catch (e) {
      // Mark as failed
      await syncQueue.markAsFailed(queueItem['id'], e.toString());
      await offlineHelper.markAsFailed(
        tableName: '${entityType}s',
        entityId: entityId,
        errorMessage: e.toString(),
      );

      debugPrint('❌ Failed to sync $entityType/$entityId: $e');
    }
  }
}
```

### 3. Monitoring Sync Status

Create a UI widget to show sync status:

```dart
import 'package:flowtill/services/sync_queue_service.dart';
import 'package:flowtill/services/offline_transaction_helper.dart';

class SyncStatusWidget extends StatefulWidget {
  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  Map<String, int> _queueStats = {};
  Map<String, Map<String, int>> _tableStats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final queueStats = await SyncQueueService().getQueueStats();
    final tableStats = await OfflineTransactionHelper().getAllSyncStats();
    
    setState(() {
      _queueStats = queueStats;
      _tableStats = tableStats;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Sync Queue: ${_queueStats['pending']} pending'),
        Text('Orders: ${_tableStats['orders']?['pending']} pending'),
        Text('Order Items: ${_tableStats['order_items']?['pending']} pending'),
        Text('Transactions: ${_tableStats['transactions']?['pending']} pending'),
      ],
    );
  }
}
```

## Maintenance Tasks

### Retry Failed Items

```dart
// Retry failed queue items (max 3 attempts)
await SyncQueueService().retryFailedItems(maxAttempts: 3);

// Retry failed transactions in each table
await OfflineTransactionHelper().retryFailedTransactions('orders', maxAttempts: 3);
await OfflineTransactionHelper().retryFailedTransactions('order_items', maxAttempts: 3);
await OfflineTransactionHelper().retryFailedTransactions('transactions', maxAttempts: 3);
```

### Clean Up Old Records

```dart
// Clear completed items from sync queue
await SyncQueueService().clearCompletedItems();

// Clean up sync metadata from old synced records (30+ days)
await OfflineTransactionHelper().cleanupOldSyncedRecords(
  tableName: 'orders',
  daysOld: 30,
);
```

## Schema Sync Behavior

### On First Install
1. Schema sync creates all mirror tables from Supabase schema
2. Automatically adds local-only columns to transactional tables
3. Creates local-only `sync_queue` table

### On App Update
1. Schema sync detects Supabase schema changes
2. Rebuilds tables if schema changed
3. Automatically re-adds local-only columns after rebuild
4. Ensures `sync_queue` table exists

### On Outlet Switch
1. Mirror sync copies data from Supabase for new outlet
2. Local-only columns are preserved (they're part of local schema)
3. No special handling needed

## Important Notes

⚠️ **DO NOT** include local-only columns when syncing to Supabase:
- `sync_status`
- `sync_error`
- `last_sync_attempt_at`
- `sync_attempt_count`
- `device_id`

These columns should be **removed** from data before sending to Supabase.

⚠️ **sync_queue** table is LOCAL-ONLY:
- Never synced to Supabase
- Used only for tracking pending changes
- Can be cleared without losing Supabase data

## Troubleshooting

### Missing Local-Only Columns

If local-only columns are missing:
1. Schema sync automatically detects and adds them during `initialize()`
2. Alternatively, run: `await SchemaSyncService().initialize()`

### Sync Queue Growing Too Large

If sync queue has too many items:
1. Check network connectivity
2. Process queue more frequently
3. Review failed items: `await SyncQueueService().getQueueStats()`
4. Retry failed items: `await SyncQueueService().retryFailedItems()`

### Table Rebuilds Losing Data

- Schema sync only rebuilds **empty** mirror tables during startup sync
- During normal operation, schema changes trigger data-preserving migrations
- Local-only columns are automatically re-added after any rebuild

## Future Enhancements

- Automatic background sync worker
- Conflict resolution for concurrent edits
- Delta sync for large datasets
- Compression for queue payloads
- Batch sync operations
- Webhook notifications for sync completion
