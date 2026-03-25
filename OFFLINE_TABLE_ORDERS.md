# Offline-First Table Order Implementation

## Overview

This document describes the comprehensive offline-first implementation for table orders in FlowTill EPOS. The system ensures that table orders can be created, parked, edited, and completed entirely offline on device builds (Windows, Android, iOS), with automatic background synchronization to Supabase when online.

## Platform Behavior

### Device Builds (Windows, Android, iOS)
- **Local-First**: All table operations save to local SQLite immediately
- **Background Sync**: Changes sync to Supabase automatically when online
- **Offline Resilient**: Full functionality even when completely offline
- **Duplicate Protection**: Strong protections prevent duplicate orders in Supabase

### Web Builds
- **Direct Supabase**: All operations go directly to Supabase
- **No Offline Queue**: Web does not use the local-first queue system
- **Simpler Flow**: No sync complexity, immediate cloud persistence

## Architecture

### Core Components

1. **OrderProvider** (`lib/providers/order_provider.dart`)
   - Platform-aware order management
   - Separate code paths for web vs device
   - Handles table order create, park, resume, complete

2. **OrderRepositoryHybrid** (`lib/services/order_repository_hybrid.dart`)
   - Platform-aware repository layer
   - Device: Local-first with background sync
   - Web: Direct Supabase only

3. **OrderRepositoryOffline** (`lib/services/order_repository_offline.dart`)
   - Local SQLite operations
   - Sync metadata management (sync_status, sync_error, etc.)
   - Outbox queue management

4. **SyncService** (`lib/services/sync_service.dart`)
   - Outbox processing
   - Ordered sync (orders → order_items → transactions)
   - Retry logic and failure handling

5. **MirrorContentSyncService** (`lib/services/mirror_content_sync_service.dart`)
   - Downloads cloud-origin data
   - Marks mirrored rows as sync_status='synced'
   - Protects locally-created pending rows from being overwritten

## Table Order Lifecycle

### 1. Create Table Order

**User Action**: Taps a table in the till screen

**Device Build Flow**:
```
1. User taps table → TablesView._handleTableTap()
2. Check if table has existing order
3. If NO existing order:
   - Call _orderRepository.createOrderHeaderForTable()
   - Repository creates order header locally (sync_status='pending')
   - Order header saved to local 'orders' table
   - Order header queued in 'outbox_queue' for sync
   - OrderProvider.initializeTableOrder() loads order into memory
4. If online: Background sync uploads order header to Supabase
5. Table shows as occupied in UI
```

**Web Build Flow**:
```
1. User taps table
2. Order header created directly in Supabase
3. OrderProvider loads from Supabase
```

**Logging Tags**: `[TABLE_FLOW]`, `[ORDER_REPO]`

### 2. Add/Remove Items

**User Action**: Adds or removes products from order

**Flow** (Same for device and web):
```
1. User adds/removes item → OrderProvider.addProduct() / removeItem()
2. Items stored in-memory in _currentOrder.items
3. NOT saved to database yet (only saved on park or complete)
4. Promotions/deals recalculated automatically
```

**Important**: Item edits are in-memory only until park or complete.

**Logging Tags**: `[ORDER_PROVIDER]`

### 3. Park Order

**User Action**: User parks the table order (sends it away)

**Device Build Flow**:
```
1. User parks order → OrderProvider.parkCurrentOrderToSupabase()
2. Platform check: kIsWeb ? _parkOrderWeb() : _parkOrderOfflineFirst()
3. Convert in-memory order to EposOrder + EposOrderItems
4. Set status = 'parked', parkedAt = now
5. Save order locally:
   - OrderRepositoryOffline.upsertOrderWithItems()
   - Order saved to 'orders' table with sync_status='pending'
   - Order queued in 'outbox_queue' (entity_type='order')
6. Save order items locally:
   - OrderRepositoryOffline.saveOrderItemsLocally()
   - Items saved to 'order_items' table with sync_status='pending'
   - Each item queued in 'outbox_queue' (entity_type='order_item')
7. End table lock session
8. Clear current order from memory
9. If online: Trigger background sync
```

**Web Build Flow**:
```
1. User parks order
2. Save directly to Supabase (orders + order_items)
3. End table lock session
4. Clear current order
```

**Logging Tags**: `[PARK_ORDER]`, `[ORDER_REPO_OFFLINE]`

### 4. Resume/Reopen Parked Order

**User Action**: User reopens a parked table order

**Device Build Flow**:
```
1. User taps parked table → TablesView._handleTableTap()
2. Existing order detected
3. OrderProvider.resumeOrderFromSupabase(orderId)
4. Platform check: onlineOnly = kIsWeb
5. _orderRepository.getOrderById(orderId, onlineOnly: false)
   - Try Supabase first
   - If fails/offline: Load from local 'orders' table
6. _orderRepository.getOrderItems(orderId, onlineOnly: false)
   - Try Supabase first
   - If fails/offline: Load from local 'order_items' table
7. Convert to in-memory Order model
8. Start table lock session
9. Recalculate promotions
10. User can now edit the order
```

**Web Build Flow**:
```
1. User taps parked table
2. Load order + items from Supabase only
3. Convert to in-memory model
4. Start table lock session
```

**Logging Tags**: `[RESUME_ORDER]`, `[ORDER_REPO]`

### 5. Edit Parked Order

**User Action**: Adds/removes items or modifies quantities on a resumed order

**Flow** (Same as step 2):
```
1. User makes changes → OrderProvider methods
2. Changes stored in-memory in _currentOrder
3. NOT saved until park again or complete
```

### 6. Complete Table Order (Checkout)

**User Action**: User completes payment for table order

**Device Build Flow**:
```
1. User completes payment → OrderProvider.saveCompletedOrder()
2. Platform check: kIsWeb ? _saveCompletedOrderWeb() : _saveCompletedOrderOfflineFirst()
3. Set order status = 'completed', completedAt = now
4. Save order locally with sync_status='pending'
5. Save order items locally with sync_status='pending'
6. Save transaction(s) locally with sync_status='pending'
7. Process inventory deduction
8. If online: Trigger background sync
```

**Web Build Flow**:
```
1. User completes payment
2. Save directly to Supabase (orders + order_items + transactions)
3. Process inventory deduction
```

**Logging Tags**: `[PAYMENT_FLOW]`, `[TABLE_CHECKOUT]`

## Sync System

### Outbox Queue

Local pending changes are stored in the `outbox_queue` table:

```sql
CREATE TABLE outbox_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type TEXT NOT NULL,      -- 'order', 'order_item', 'transaction'
  entity_id TEXT NOT NULL,        -- UUID of the entity
  operation TEXT NOT NULL,        -- 'insert', 'update'
  payload TEXT NOT NULL,          -- JSON of the full entity
  created_at INTEGER NOT NULL,
  retry_count INTEGER DEFAULT 0,
  last_error TEXT,
  processed INTEGER DEFAULT 0
);
```

### Sync Order

**CRITICAL**: Entities must sync in this exact order to respect foreign key constraints:

1. **orders** (parent table)
2. **order_items** (references orders)
3. **transactions** (references orders)

### Sync Process

```
1. SyncService._processOutboxQueue() runs periodically or on connection restore
2. Load pending items (retry_count < 5, processed = 0)
3. Group by entity type
4. Process in order:
   - Process all 'order' items
   - Process all 'order_item' items
   - Process all 'transaction' items
5. For each item:
   - Clean payload (remove sync metadata, remove 'items' array from order)
   - Upload to Supabase
   - On success: Mark local row as sync_status='synced'
   - On success: Mark outbox item as processed
   - On failure: Increment retry_count, record error
6. Delete outbox items with retry_count > 5
```

**Logging Tags**: `[OUTBOX_SYNC]`

### Mirror Sync Protection

When downloading cloud-origin data during startup or outlet switch:

```
1. MirrorContentSyncService.importMirroredRow() downloads from Supabase
2. Check if local row exists
3. If local row has sync_status='pending' or 'failed':
   - SKIP UPDATE (protection)
   - This prevents overwriting locally-created unsynced data
4. Otherwise:
   - Update/insert row with sync_status='synced'
```

**Logging Tags**: `[MIRROR_SYNC]`

## Duplicate Prevention

### Protection Layer 1: Sync Status Checking

- Before saving locally, check if row exists with sync_status='synced'
- Refuse to downgrade synced rows to pending (prevents corruption)

### Protection Layer 2: Mirror Sync Protection

- Mirror sync skips rows with sync_status='pending'
- Prevents cloud-origin mirrored data from overwriting local pending changes

### Protection Layer 3: Outbox Deduplication

- Outbox items are removed after successful sync
- Retries use exponential backoff
- Failed items (>5 retries) are auto-deleted

### Protection Layer 4: Server-Side Constraints

- Supabase has unique constraints on order IDs
- Foreign key constraints prevent orphaned order items
- Transaction validation ensures data integrity

## Logging System

### Log Tags

All logs use consistent tags for easy filtering:

- `[TABLE_FLOW]` - Table order creation and initialization
- `[PARK_ORDER]` - Park order operations
- `[RESUME_ORDER]` - Resume order operations
- `[ORDER_REPO]` - Repository layer operations
- `[ORDER_REPO_OFFLINE]` - Offline repository operations
- `[PAYMENT_FLOW]` - Checkout and payment operations
- `[OUTBOX_SYNC]` - Outbox processing and sync
- `[MIRROR_SYNC]` - Mirror content sync

### Log Level Guidelines

- `✅` - Success operations
- `❌` - Error operations
- `⚠️` - Warnings (non-fatal issues)
- `🔄` - Loading/syncing operations
- `💾` - Database save operations
- `📤` - Upload operations
- `📥` - Download operations
- `🍽️` - Table-specific operations

### Example Log Output

```
[TABLE_FLOW] Creating table order header (platform: device)
[ORDER_REPO] 💾 Saving LOCAL order with sync_status=pending: abc-123
[ORDER_REPO] ✅ Inserted new local order: abc-123
[ORDER_REPO] ✅ Queued for upload via outbox
[TABLE_FLOW] ✅ Table order initialized
[TABLE_FLOW]    Service charge: true (rate: 12.50%)
[OUTBOX_SYNC] Processing 3 pending items
[OUTBOX_SYNC] Grouped items: 1 orders, 2 order_items, 0 transactions
[OUTBOX_SYNC] Uploading order abc-123 with payload keys: [id, outlet_id, ...]
[OUTBOX_SYNC] ✅ Order sync success: abc-123
[OUTBOX_SYNC] Marked local row synced: table=orders, id=abc-123
```

## Testing Checklist

### Manual Test Plan

#### Test 1: Create Table Order Offline
1. ✅ Turn off internet connection
2. ✅ Tap a table in the till screen
3. ✅ Verify table shows as occupied
4. ✅ Add 3 items to the order
5. ✅ Verify items show in order panel
6. ✅ Park the order
7. ✅ Verify order clears from memory
8. ✅ Check logs: [PARK_ORDER] should show local save

**Expected Result**:
- Order created locally
- sync_status='pending' in local database
- Outbox entry created for order

#### Test 2: Reopen Parked Order Offline
1. ✅ With internet still off
2. ✅ Navigate to Tables view
3. ✅ Verify parked table shows as occupied
4. ✅ Tap the parked table
5. ✅ Verify order loads with 3 items
6. ✅ Check logs: [RESUME_ORDER] should show "loaded from local/cloud"

**Expected Result**:
- Order loads from local database
- All 3 items present with correct quantities

#### Test 3: Edit Parked Order Offline
1. ✅ With order open (from test 2)
2. ✅ Add 2 more items (total 5)
3. ✅ Remove 1 item (total 4)
4. ✅ Change quantity of 1 item
5. ✅ Add notes to 1 item
6. ✅ Park the order again
7. ✅ Check logs: [PARK_ORDER] should show 4 items saved

**Expected Result**:
- Order items updated locally
- All 4 items queued in outbox with sync_status='pending'

#### Test 4: Complete Table Order Offline
1. ✅ With internet still off
2. ✅ Reopen the parked table
3. ✅ Go to payment screen
4. ✅ Complete payment (e.g., Cash £50)
5. ✅ Verify receipt preview shows correct items and total
6. ✅ Confirm payment
7. ✅ Check logs: [PAYMENT_FLOW] should show offline-first path

**Expected Result**:
- Order marked as status='completed' locally
- Transaction created locally with sync_status='pending'
- Outbox entries for order, items, transaction

#### Test 5: Reconnect and Sync
1. ✅ Turn internet connection back on
2. ✅ Wait for automatic sync (~2-5 seconds)
3. ✅ Check logs: [OUTBOX_SYNC] should show processing
4. ✅ Verify logs show sync success for all entities
5. ✅ Check Supabase dashboard - verify order exists
6. ✅ Verify order items exist in Supabase
7. ✅ Verify transaction exists in Supabase

**Expected Result**:
- All pending entities sync to Supabase
- Local rows updated to sync_status='synced'
- Outbox entries marked as processed
- No errors in logs

#### Test 6: No Duplicate Orders
1. ✅ After sync completes
2. ✅ Query Supabase orders table for the order ID
3. ✅ Verify exactly ONE order with that ID exists
4. ✅ Query order_items for that order_id
5. ✅ Verify correct count of items (4 from test 3)
6. ✅ Query transactions for that order_id
7. ✅ Verify exactly ONE transaction exists

**Expected Result**:
- No duplicate orders in Supabase
- No duplicate order items
- No duplicate transactions

#### Test 7: Outlet Switch with Pending Orders
1. ✅ Create a table order offline
2. ✅ Add items and park it (do not sync yet)
3. ✅ Switch to a different outlet
4. ✅ Wait for mirror sync to complete
5. ✅ Switch back to original outlet
6. ✅ Verify pending table order still shows as occupied
7. ✅ Verify sync_status='pending' (not overwritten by mirror)

**Expected Result**:
- Mirror sync does not overwrite pending orders
- Locally-created order protected from being marked as synced

#### Test 8: Mixed Cloud and Local Orders
1. ✅ With internet on, create table order A (syncs immediately)
2. ✅ Turn internet off
3. ✅ Create table order B offline (stays pending)
4. ✅ Navigate to Tables view
5. ✅ Verify both tables show as occupied
6. ✅ Open table A - verify it loads
7. ✅ Open table B - verify it loads
8. ✅ Turn internet on and verify B syncs

**Expected Result**:
- Both synced and pending orders visible
- Can open and edit both types
- Pending orders sync when connection restores

## Schema Requirements

### orders Table

Required columns for offline sync:
```sql
CREATE TABLE orders (
  id TEXT PRIMARY KEY,
  outlet_id TEXT NOT NULL,
  table_id TEXT,
  table_number TEXT,
  staff_id TEXT,
  status TEXT NOT NULL,           -- 'open', 'parked', 'completed'
  order_type TEXT NOT NULL,       -- 'table', 'tab', 'quick_service'
  subtotal REAL,
  tax_amount REAL,
  total_due REAL,
  service_charge REAL,
  payment_method TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  completed_at INTEGER,
  parked_at INTEGER,
  -- Offline sync metadata:
  sync_status TEXT DEFAULT 'synced',       -- 'pending', 'synced', 'failed'
  sync_error TEXT,
  last_sync_attempt_at INTEGER,
  sync_attempt_count INTEGER DEFAULT 0,
  device_id TEXT
);
```

### order_items Table

Required columns for offline sync:
```sql
CREATE TABLE order_items (
  id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  product_name TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price REAL NOT NULL,
  gross_line_total REAL NOT NULL,
  tax_rate REAL NOT NULL,
  tax_amount REAL NOT NULL,
  notes TEXT,
  modifiers TEXT,              -- JSON array
  created_at INTEGER NOT NULL,
  -- Offline sync metadata:
  sync_status TEXT DEFAULT 'synced',
  sync_error TEXT,
  last_sync_attempt_at INTEGER,
  sync_attempt_count INTEGER DEFAULT 0,
  device_id TEXT,
  FOREIGN KEY (order_id) REFERENCES orders(id)
);
```

### transactions Table

Required columns for offline sync:
```sql
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL,
  outlet_id TEXT NOT NULL,
  staff_id TEXT,
  amount REAL NOT NULL,
  payment_method TEXT NOT NULL,
  change_given REAL,
  transaction_type TEXT NOT NULL,  -- 'sale', 'refund'
  created_at INTEGER NOT NULL,
  -- Offline sync metadata:
  sync_status TEXT DEFAULT 'synced',
  sync_error TEXT,
  last_sync_attempt_at INTEGER,
  sync_attempt_count INTEGER DEFAULT 0,
  device_id TEXT,
  FOREIGN KEY (order_id) REFERENCES orders(id)
);
```

## Configuration

### Sync Settings

Located in `lib/config/sync_config.dart`:

```dart
// Enable periodic background sync (every 2 minutes)
const bool kPeriodicBackgroundSync = true;

// Enable sync on connection restore
const bool kSyncOnConnectionRestore = true;

// Maximum retry attempts before auto-delete
const int kMaxRetryAttempts = 5;
```

### Platform Detection

```dart
import 'package:flutter/foundation.dart';

if (kIsWeb) {
  // Web-specific logic (direct Supabase)
} else {
  // Device-specific logic (local-first)
}
```

## Troubleshooting

### Issue: Table order not syncing

**Check**:
1. Is device online? Check ConnectionService.isOnline
2. Check outbox_queue table for pending items
3. Check local row sync_status (should be 'pending')
4. Check logs for [OUTBOX_SYNC] errors
5. Verify retry_count < 5 (items with >5 retries are auto-deleted)

**Solution**:
- Manually trigger sync: SyncService().syncAll()
- Check sync_error column for specific error message

### Issue: Duplicate orders in Supabase

**Check**:
1. Search logs for "PROTECTION" messages
2. Check if same order ID uploaded multiple times
3. Verify outbox items were marked as processed after sync

**Solution**:
- Should not happen due to protections
- If it does, report as bug with full logs

### Issue: Local pending order overwritten by mirror sync

**Check**:
1. Search logs for "PROTECTION: Skipping mirror update"
2. Check if row had sync_status='pending' before mirror sync
3. Verify _safeUpsert protection is working

**Solution**:
- Should not happen due to protections
- If it does, report as bug with full logs

### Issue: Order items missing after park/resume

**Check**:
1. Check logs for [PARK_ORDER] - verify items were saved
2. Check local order_items table for the order_id
3. Verify saveOrderItemsLocally() succeeded

**Solution**:
- Verify order_items schema has all required columns
- Check for saveOrderItemsLocally() errors in logs

## Performance Considerations

### Database Queries

- Use indexes on frequently queried columns:
  - `orders.outlet_id`
  - `orders.table_id`
  - `orders.status`
  - `order_items.order_id`
  - `transactions.order_id`

### Sync Batching

- Outbox processes max 100 items per sync cycle
- Large orders (>50 items) may take multiple sync cycles
- Normal orders (<10 items) sync in <1 second

### Memory Usage

- In-memory order holds all items
- Large orders (>100 items) may impact memory
- Park order frequently to persist changes

## Future Enhancements

### Potential Improvements

1. **Auto-save on Edit** - Periodically save in-memory changes to local DB
2. **Conflict Resolution** - Handle cases where same order modified on multiple devices
3. **Real-time Sync** - Use websockets for instant sync instead of polling
4. **Optimistic UI** - Show synced state before actual sync completes
5. **Offline Queue Size Limit** - Set max size for outbox_queue to prevent unlimited growth

## Summary

The offline-first table order system provides a robust, production-ready solution for handling table orders in FlowTill EPOS. It works seamlessly across all platforms while maintaining platform-appropriate behavior (local-first for device builds, direct-Supabase for web). Strong duplicate protections and comprehensive logging ensure data integrity and easy troubleshooting.
