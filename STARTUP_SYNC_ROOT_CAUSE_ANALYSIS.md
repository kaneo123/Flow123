# FlowTill Startup Sync Root Cause Analysis

## Problem Statement
Manual "Sync All Tables" successfully hydrates local mirror for Main Outlet, and offline works correctly after manual sync. However, startup auto-sync does NOT populate all required tables before login/till flows depend on them.

## Root Causes Identified

### 1. **CRITICAL: Missing Table in Startup Sync**

**trading_days** is completely absent from startup sync buckets:

**Manual Sync** (`mirror_content_sync_service.dart` line 38):
```dart
static const List<String> availableTables = [
  'outlets', 'outlet_settings', 'categories', 'products', 'staff', 
  'staff_outlets', 'printers', 'tax_rates', 'promotions', 'outlet_tables',
  'modifier_groups', 'modifier_options', 'product_modifier_groups',
  'packaged_deals', 'packaged_deal_components', 'inventory_items',
  'stock_movements', 'orders', 'order_items', 'transactions',
  'trading_days',  // ← PRESENT
];
```

**Startup Sync** (`startup_content_sync_orchestrator.dart` lines 28-48):
```dart
static const List<String> _bucketACoreRequired = [
  'outlets', 'outlet_settings', 'categories', 'products', 'tax_rates',
  'staff', 'staff_outlets', 'printers', 'outlet_tables',
  'modifier_groups', 'modifier_options', 'product_modifier_groups',
  // trading_days MISSING! ← CRITICAL OMISSION
];

static const List<String> _bucketBSecondary = [
  'promotions', 'packaged_deals', 'packaged_deal_components', 'inventory_items',
  // trading_days MISSING! ← CRITICAL OMISSION
];
```

**Impact**: Trading day queries fail offline until manual sync is performed.

---

### 2. **Schema Mismatch Handling**

#### Issue A: Staff Cache Insert
Location: `staff_service.dart` lines 88-97

Code tries to insert columns that SHOULD exist in local staff table:
- `associated_outlets`
- `role_id`
- `permission_level`
- `updated_at`

**Analysis**: These columns ARE defined in `app_database.dart` lines 103-106:
```dart
CREATE TABLE staff (
  id TEXT PRIMARY KEY,
  outlet_id TEXT,
  full_name TEXT NOT NULL,
  pin_code TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 1,
  associated_outlets TEXT,        // ← EXISTS
  role_id TEXT,                   // ← EXISTS
  permission_level INTEGER,       // ← EXISTS
  updated_at INTEGER NOT NULL     // ← EXISTS
)
```

**Root Cause**: Database version mismatch or schema sync not completing before staff service attempts insert.

#### Issue B: Orders synced_at Column
Location: Multiple services query `orders.synced_at`

**Analysis**: Column IS defined in `app_database.dart` line 226:
```dart
CREATE TABLE orders (
  id TEXT PRIMARY KEY,
  outlet_id TEXT NOT NULL,
  ...
  synced_at INTEGER  // ← EXISTS
)
```

**Root Cause**: Same as Issue A - schema sync timing issue.

---

### 3. **Startup Flow Timing Issues**

Current flow in `splash_screen.dart`:
1. Line 366: Calls `_startupSyncOrchestrator.runStartupSync(outletId)`
2. No explicit wait for schema sync completion first
3. Services start reading from local tables before startup sync finishes

**Issue**: Services like `StaffService`, `TradingDayService` may attempt local reads before startup sync populates required tables.

---

### 4. **Insufficient Diagnostics**

Current startup sync logging doesn't clearly show:
- Which tables were scheduled for sync
- Which tables completed successfully vs failed
- Local row counts after each table sync
- Total sync completion status per bucket

**Impact**: Hard to debug why startup sync produces different results than manual sync.

---

## Solution Requirements

1. **Add trading_days to startup sync Bucket A** (critical data needed before login)
2. **Enhance startup diagnostics** with:
   - Table-by-table completion logs
   - Row counts after each sync
   - Bucket completion summaries
   - Final startup sync report
3. **Schema sync safeguards**:
   - Ensure column filtering handles missing columns gracefully (already implemented but needs verification)
   - Add try/catch around staff cache inserts with column existence checks
4. **Timing fixes**:
   - Ensure schema sync completes before content sync
   - Add explicit validation that required tables exist before login
5. **Preserve web behavior**: Skip all mirror sync on `kIsWeb`

---

## Files to Modify

### High Priority
1. `lib/services/startup_content_sync_orchestrator.dart` - Add trading_days, enhance logging
2. `lib/services/staff_service.dart` - Add safer column handling for cache inserts
3. `lib/screens/splash_screen.dart` - Add validation before login

### Medium Priority  
4. `lib/services/mirror_content_sync_service.dart` - Ensure consistent behavior with startup sync

---

## Expected Outcome

After fixes:
- Startup sync populates same tables as manual sync
- Trading day works offline immediately after startup
- Schema mismatches handled gracefully
- Clear diagnostic logs show exactly what was synced
- Services don't attempt local reads until sync completes
- Web platform bypasses all mirror sync correctly
