# Offline Sync Metadata Corruption Fix

## Problem Summary

Mirrored cloud-origin records in local SQLite were being marked with `sync_status='pending'` when they should always remain `sync_status='synced'`. This caused the app to treat mirrored records as locally-created unsynced records, creating risk of:

- Duplicate order uploads
- Incorrect sync queue counts
- Failed upload attempts for already-synced records
- Corrupted sync metadata after outlet switching

## Root Causes Identified

### 1. Dangerous REPLACE Operations
- **MirrorContentSyncService** used `ConflictAlgorithm.replace` when inserting mirrored rows
- SQLite REPLACE effectively deletes and recreates rows, wiping local-only metadata
- This caused `sync_status` and other local columns to reset to DEFAULT values

### 2. Bucket C Import Path
- Startup/outlet switch imported live operational orders (Bucket C) without explicitly setting `sync_status='synced'`
- These cloud-origin rows were being inserted with default metadata
- No validation was run after Bucket C import

### 3. Local Order Save Path Issues
- **OrderRepositoryOffline** also used `ConflictAlgorithm.replace`
- Column name mismatches (using `tax_total` instead of `tax_amount`, etc.)
- No schema introspection to ensure fields match actual table structure
- No protection against downgrading synced rows to pending

### 4. No Hard Separation
- Mirrored cloud rows and local draft rows used the same code paths
- No clear distinction between import operations and local saves
- Risk of mirrored rows flowing through local save methods

## Solution Implemented

### 1. Safe Upsert Pattern (CRITICAL FIX)

**Before (DANGEROUS):**
```dart
await db.insert(
  tableName,
  filteredData,
  conflictAlgorithm: ConflictAlgorithm.replace, // DELETES AND RECREATES ROW!
);
```

**After (SAFE):**
```dart
// Try update first
final updateCount = await db.update(
  tableName,
  filteredData,
  where: 'id = ?',
  whereArgs: [rowId],
);

if (updateCount == 0) {
  // Row doesn't exist, insert it
  await db.insert(tableName, filteredData);
}
```

**Applied to:**
- `MirrorContentSyncService.syncSingleTable()` - Added `_safeUpsert()` helper
- `MirrorContentSyncService.importMirroredRow()` - New public method for cloud-origin imports
- `OrderRepositoryOffline.upsertOrderWithItems()` - Now uses safe upsert pattern

### 2. Separate Mirror Import Path

Created dedicated `importMirroredRow()` method in MirrorContentSyncService:

```dart
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
  // ... sanitize and filter data ...
  
  // CRITICAL: Mark as synced for cloud-origin rows
  if (localColumns.contains('sync_status')) {
    filtered['sync_status'] = 'synced';
    filtered['sync_error'] = null;
    filtered['last_sync_attempt_at'] = null;
    filtered['sync_attempt_count'] = 0;
    filtered['device_id'] = null;
  }
  
  // Safe upsert
  await _safeUpsert(db, tableName, filtered, rowId);
}
```

### 3. Fixed Bucket C Import

**startup_content_sync_orchestrator.dart:**

```dart
// OLD: Direct insert without sync metadata
await db.insert('orders', filtered);

// NEW: Use dedicated mirror import path
await _mirrorSync.importMirroredRow('orders', orderData, context: context);
```

Added validation after Bucket C import:
```dart
if (hasOfflineSupport && importedCount > 0) {
  await _validateBucketCSyncStatus(db, 'orders', context: context);
}
```

### 4. Protected Synced Rows from Downgrade

**OrderRepositoryOffline.upsertOrderWithItems():**

```dart
// PROTECTION: Check if row already exists with sync_status='synced'
if (hasSyncStatus) {
  final existing = await db.query('orders', where: 'id = ?', whereArgs: [order.id]);
  
  if (existing.isNotEmpty) {
    final existingSyncStatus = existing.first['sync_status'] as String?;
    if (existingSyncStatus == 'synced') {
      debugPrint('[ORDER_REPO] ⚠️ PROTECTION: Refusing to overwrite synced order');
      return false; // Refuse to downgrade
    }
  }
}
```

### 5. Fixed Column Name Mapping

**OrderRepositoryOffline:**

- Now performs schema introspection before saving
- Uses actual Supabase column names (`tax_amount`, `discount_amount`, `total_due`)
- Only writes to columns that actually exist in the schema
- Handles both old and new column name variants for compatibility

```dart
// Get actual local table columns
final tableInfo = await db.rawQuery('PRAGMA table_info(orders)');
final columnNames = tableInfo.map((col) => col['name'] as String).toSet();

// Map fields only if they exist
if (columnNames.contains('tax_amount')) localOrder['tax_amount'] = order.taxAmount;
if (columnNames.contains('discount_amount')) localOrder['discount_amount'] = order.discountAmount;
if (columnNames.contains('total_due')) localOrder['total_due'] = order.totalDue;
```

### 6. Comprehensive Validation

Added validation at multiple levels:

**Per-table validation after mirror sync:**
```dart
debugPrint('[MIRROR_SYNC]   📊 Sync status validation for $tableName:');
debugPrint('[MIRROR_SYNC]      - Synced (cloud-origin): $syncedCount');
debugPrint('[MIRROR_SYNC]      - Pending (local-created): $pendingCount');
```

**Overall validation after full sync:**
```dart
debugPrint('[MIRROR_SYNC]   📊 SUMMARY:');
debugPrint('[MIRROR_SYNC]      Total cloud-origin (synced): $totalSynced');
debugPrint('[MIRROR_SYNC]      Total local-created (pending): $totalPending');
```

**Bucket C validation:**
```dart
debugPrint('[$context]   📊 Bucket C validation for $tableName:');
debugPrint('[$context]      - Synced (cloud-origin): $synced');
debugPrint('[$context]      - Pending (should be 0): $pending');
```

### 7. Enhanced Debug Logging

Added comprehensive logging throughout:

**Mirror import:**
```dart
debugPrint('[MIRROR_SYNC]   📥 INSERTED row: id=$rowId, sync_status=$syncStatus, uploadable=false (cloud-origin)');
```

**Local order save:**
```dart
debugPrint('[ORDER_REPO] 💾 Saving LOCAL order with sync_status=pending: ${order.id}');
debugPrint('[ORDER_REPO]    This order will be queued for upload to Supabase');
```

**Protection triggers:**
```dart
debugPrint('[ORDER_REPO] ⚠️ PROTECTION: Refusing to overwrite synced order ${order.id} with local save');
debugPrint('[ORDER_REPO]    This order came from cloud and should not be downgraded to pending');
```

## Files Changed

### Core Services
1. **lib/services/mirror_content_sync_service.dart**
   - Replaced `ConflictAlgorithm.replace` with safe upsert pattern
   - Added `_safeUpsert()` helper method
   - Added `importMirroredRow()` public method for cloud-origin imports
   - Enhanced validation and logging

2. **lib/services/startup_content_sync_orchestrator.dart**
   - Updated `_writeOrdersToLocalMirror()` to use `importMirroredRow()`
   - Updated `_writeOrderItemsToLocalMirror()` to use `importMirroredRow()`
   - Added `_validateBucketCSyncStatus()` validation method

3. **lib/services/order_repository_offline.dart**
   - Replaced `ConflictAlgorithm.replace` with safe upsert pattern
   - Added schema introspection before saving
   - Fixed column name mapping to use actual Supabase fields
   - Added protection against downgrading synced rows
   - Enhanced `_localOrderToEposOrder()` to handle both old and new column names

## Metadata Rules Enforced

### For Mirrored Cloud-Origin Rows:
```dart
sync_status = 'synced'
sync_error = null
last_sync_attempt_at = null
sync_attempt_count = 0
device_id = null
uploadable = false (conceptually)
```

### For Local/Offline-Created Rows:
```dart
sync_status = 'pending'
sync_error = null
last_sync_attempt_at = null
sync_attempt_count = 0
device_id = <actual device id if available>
uploadable = true (conceptually)
```

## Outlet Resync Idempotency

Switching back to an already-synced outlet now:
- ✅ Safely refreshes/updates existing mirrored rows
- ✅ Does NOT duplicate orders
- ✅ Does NOT duplicate order_items
- ✅ Does NOT change synced rows into pending
- ✅ Preserves local-only metadata correctly

## Testing Instructions

### Test 1: App Startup Sync
**What to check:**
1. Start the app fresh or clear local DB
2. Watch logs during startup sync
3. Look for validation output after sync completes

**Expected logs:**
```
[MIRROR_SYNC] ✅ Table has offline sync columns - mirrored records will be marked as "synced"
[MIRROR_SYNC]   📥 INSERTED row: id=xxx, sync_status=synced, uploadable=false (cloud-origin)
[MIRROR_SYNC]   ✅ VALIDATION PASSED: No mirrored rows marked as pending
[MIRROR_SYNC]   ✅ VALIDATION PASSED: All mirrored rows marked as synced
```

**Expected outcome:**
- All mirrored orders have `sync_status='synced'`
- Pending count should be 0 after fresh sync
- No warnings about pending mirrored rows

### Test 2: Manual Outlet Switching
**What to check:**
1. Switch to Outlet A (e.g., Main Outlet)
2. Wait for sync to complete
3. Check validation logs
4. Switch to Outlet B (e.g., Bar)
5. Wait for sync to complete
6. Switch back to Outlet A
7. Check that rows are not duplicated
8. Verify sync metadata is still correct

**Expected logs:**
```
[OUTLET_SWITCH] === Bucket C: Live Operational Data ===
[OUTLET_SWITCH]   ✅ orders table has offline sync columns
[OUTLET_SWITCH]   📥 UPDATED mirrored row to orders: id=xxx, sync_status=synced
[OUTLET_SWITCH]   ✅ VALIDATION PASSED: All Bucket C rows marked as synced
```

**Expected outcome:**
- Switching outlets does not duplicate orders
- Synced rows remain synced after re-sync
- Row counts match Supabase source counts
- No pending rows after mirror sync completes

### Test 3: Creating New Local Order
**What to check:**
1. After outlet sync completes, create a new local order
2. Add items and save
3. Check logs for proper metadata

**Expected logs:**
```
[ORDER_REPO] 💾 Saving LOCAL order with sync_status=pending: <order-id>
[ORDER_REPO]    This order will be queued for upload to Supabase
[ORDER_REPO]    ✅ Inserted new local order: <order-id>
[ORDER_REPO]    ✅ Queued for upload via outbox
```

**Expected outcome:**
- New local order has `sync_status='pending'`
- Order is added to outbox queue
- Mirrored orders are NOT affected
- Pending count increases by 1

### Test 4: Protection Against Downgrade
**What to check:**
1. After mirror sync, find a mirrored order ID
2. Try to save that order through OrderRepositoryOffline
3. Verify protection triggers

**Expected logs:**
```
[ORDER_REPO] ⚠️ PROTECTION: Refusing to overwrite synced order <order-id> with local save
[ORDER_REPO]    This order came from cloud and should not be downgraded to pending
```

**Expected outcome:**
- Save operation returns false
- Synced order remains synced
- No change to sync metadata
- Warning logged clearly

### Test 5: Offline Outlet Switching
**What to check:**
1. Disconnect from network
2. Attempt to switch outlets
3. Reconnect and check sync
4. Verify no corruption occurred

**Expected outcome:**
- Offline switch should use cached data or fail gracefully
- When reconnected, sync should recover correctly
- No duplicate rows or corrupted metadata

## Validation Queries (For Manual Testing)

### Check sync status distribution:
```sql
SELECT sync_status, COUNT(*) as count 
FROM orders 
WHERE outlet_id = '<your-outlet-id>'
GROUP BY sync_status;
```

**Expected after mirror sync:**
- `synced`: <count of mirrored orders>
- `pending`: 0 (unless you created local orders)

### Find incorrectly marked rows:
```sql
SELECT id, status, sync_status, created_at 
FROM orders 
WHERE outlet_id = '<your-outlet-id>' 
  AND sync_status = 'pending' 
  AND status IN ('open', 'parked')
LIMIT 10;
```

**Expected:** Empty result set after mirror sync (no pending mirrored rows)

### Check for duplicates:
```sql
SELECT id, COUNT(*) as count 
FROM orders 
WHERE outlet_id = '<your-outlet-id>'
GROUP BY id 
HAVING count > 1;
```

**Expected:** Empty result set (no duplicate IDs)

## Migration Notes

### No Database Migration Required
This fix works with the existing schema. The offline sync columns (`sync_status`, `sync_error`, etc.) were already added by `SchemaSyncService` in a previous update.

### Automatic Repair
The next time the app runs a full mirror sync, all mirrored rows will be correctly marked as `sync_status='synced'`. No manual intervention is needed.

### Backward Compatibility
The code handles both old and new column names:
- `tax_amount` (new) and `tax_total` (old)
- `discount_amount` (new) and `discount_total` (old)
- `total_due` (new) and `total` (old)

This ensures compatibility with different schema versions.

## Production Safety

### Safe to Deploy
- ✅ No breaking changes
- ✅ No schema migrations required
- ✅ Backward compatible column name handling
- ✅ Existing local-only orders not affected
- ✅ Protection prevents accidental data corruption

### Rollback Plan
If issues are discovered:
1. The old code can be restored
2. Run a full mirror sync to reset local data
3. Clear local database if needed (`AppDatabase.instance.database.delete()`)

### Performance Impact
- Minimal: Safe upsert pattern adds one extra query per row (update attempt before insert)
- Only affects mirror sync operations, not normal app operation
- Benefit: Prevents costly duplicate upload attempts and sync queue corruption

## Known Limitations

### Device ID Not Yet Implemented
The `device_id` field is set to `null` for locally-created orders. Future enhancement could:
- Use `device_info_plus` package to get unique device ID
- Store device ID in shared preferences
- Include device ID in local order metadata

### Order Items Separation
Current implementation assumes order items are stored in a separate `order_items` table. If your schema stores items as JSON in the `orders.items` column, the code handles this but may not be optimal.

## Future Enhancements

1. **Device Identification**
   - Implement proper device ID tracking
   - Include device metadata in sync logs

2. **Conflict Resolution**
   - Handle cases where local modifications conflict with cloud updates
   - Implement last-write-wins or merge strategies

3. **Partial Sync**
   - Allow syncing only changed rows instead of full table replacement
   - Use timestamps or version numbers for incremental sync

4. **Sync Queue Dashboard**
   - UI to view pending uploads
   - Manual retry for failed uploads
   - Clear visibility of sync status

## Conclusion

This fix addresses the root causes of offline sync metadata corruption by:
- Eliminating dangerous REPLACE operations
- Separating mirror import from local save paths
- Protecting synced rows from being downgraded
- Enforcing correct metadata rules consistently
- Providing comprehensive validation and logging

The solution is production-safe, backward-compatible, and requires no manual intervention or database migrations.
