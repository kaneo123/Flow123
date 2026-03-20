# Outlet Switching Refactor Summary

## Overview
Refactored manual outlet switching to mirror the startup sync preparation flow, ensuring consistent behavior and preventing premature outlet commitment.

## Key Changes

### 1. **Universal Outlet Preparation Method**
**File:** `lib/services/startup_content_sync_orchestrator.dart`

- Renamed `runStartupSync()` → `prepareOutletForUse()` (with backward compatibility wrapper)
- Added `context` parameter to distinguish between 'STARTUP_SYNC' and 'OUTLET_SWITCH' flows
- This single method is now used for BOTH:
  - Startup sync (called from splash screen)
  - Manual outlet switching (called from outlet provider)

**Benefits:**
- Single source of truth for outlet preparation
- Consistent sync behavior across all entry points
- Comprehensive sync includes Buckets A, B, C (core, secondary, live data)

### 2. **Unified Outlet Provider Flow**
**File:** `lib/providers/outlet_provider.dart`

**Before:**
- Used separate `OutletSwitchSyncService.syncRequiredOutletData()`
- Only synced minimum required tables
- Different sync logic than startup

**After:**
- Uses `StartupContentSyncOrchestrator.prepareOutletForUse()` 
- Syncs ALL tables (same as startup)
- Identical validation flow
- **Critical:** Outlet is NOT committed until sync + validation completes

**Flow:**
```
User selects outlet
  ↓
Validate switch (online/offline check)
  ↓
If online & requires sync:
  → prepareOutletForUse() [FULL SYNC]
  ↓
Only after successful sync:
  → commitOutletSwitch()
  ↓
Post-switch setup (catalog, promotions, etc.)
```

### 3. **Shared Progress Dialog**
**File:** `lib/widgets/shared/outlet_sync_progress_dialog.dart`

- New reusable widget for showing sync progress
- **Passive observer** - subscribes to sync orchestrator's progress stream
- Shows rich UI with:
  - Progress percentage
  - Current step label
  - Animated progress indicator
  - Success/error states
- Auto-closes when sync completes
- Mirrors the startup splash screen experience

### 4. **Enhanced Outlet Selector**
**File:** `lib/widgets/till/outlet_selector.dart`

**Before:**
- Simple "Switching outlet..." text dialog
- No progress visibility
- Generic error messages

**After:**
- Shows `OutletSyncProgressDialog` with detailed progress
- Users see exactly what's being synced (like startup)
- Clear error messages if sync fails
- Smooth completion feedback

**Flow:**
```
User selects outlet
  ↓
Show progress dialog (subscribes to sync stream)
  ↓
Call setCurrentOutletWithValidation()
  ↓
Dialog shows real-time progress (0-100%)
  ↓
Dialog auto-closes on completion
  ↓
Load catalog, promotions, staff (post-switch)
  ↓
Show success snackbar
```

### 5. **Splash Screen Update**
**File:** `lib/screens/splash_screen.dart`

- Now calls `prepareOutletForUse(outletId, context: 'STARTUP_SYNC')`
- Maintains existing progress UI and behavior
- No functional changes, just uses renamed method

## Tables Synced

### Bucket A - Core Required (60% of progress)
- outlets
- outlet_settings
- categories
- products
- tax_rates
- staff
- staff_outlets
- printers
- outlet_tables
- modifier_groups
- modifier_options
- product_modifier_groups
- trading_days

### Bucket B - Secondary (20% of progress)
- promotions
- packaged_deals
- packaged_deal_components
- inventory_items

### Bucket C - Live Operational (20% of progress)
- Active orders (open/parked)
- Order items for active orders

## Offline Behavior

**Before switching:**
1. Check if user is online
2. If offline:
   - Validate outlet is available locally (all required tables populated)
   - If not available → BLOCK switch with clear message
   - If available → Allow switch (no sync needed)
3. If online:
   - Always sync before switching
   - Validate after sync
   - Only commit if validation passes

**Benefits:**
- No Supabase fallback leakage
- Predictable offline behavior
- Clear user feedback when outlet not ready

## Logging

All flows now use context-aware logging:

**Startup:**
```
[STARTUP_SYNC] PREPARING OUTLET FOR USE - BEGIN
[STARTUP_SYNC] Outlet ID: abc-123
[STARTUP_SYNC] Syncing core table: products
[STARTUP_SYNC]   ✅ products: 304 rows synced
```

**Manual Switch:**
```
[OUTLET_SWITCH] PREPARING OUTLET FOR USE - BEGIN
[OUTLET_SWITCH] Outlet ID: xyz-789
[OUTLET_SWITCH] Syncing core table: products
[OUTLET_SWITCH]   ✅ products: 156 rows synced
```

## Implementation Safeguards

1. **No early outlet commitment:**
   - Outlet is committed ONLY after prepareOutletForUse() succeeds
   - Services cannot read from incomplete local tables

2. **Progress visibility:**
   - Users see exactly what's happening during switches
   - No mysterious delays or loading states

3. **Error handling:**
   - Clear error messages if sync fails
   - Option to retry or return to previous outlet

4. **Reusability:**
   - Single method (`prepareOutletForUse`) used everywhere
   - Easy to maintain and debug

## Files Modified

1. `lib/services/startup_content_sync_orchestrator.dart` - Universal preparation method
2. `lib/providers/outlet_provider.dart` - Uses unified sync flow
3. `lib/widgets/shared/outlet_sync_progress_dialog.dart` - NEW: Shared progress UI
4. `lib/widgets/till/outlet_selector.dart` - Rich progress dialog
5. `lib/screens/splash_screen.dart` - Updated method call

## Testing Checklist

- [x] Startup sync still works (splash screen)
- [ ] Manual outlet switching shows progress dialog
- [ ] Progress updates in real-time (0-100%)
- [ ] Dialog auto-closes on completion
- [ ] Success message shows after switch
- [ ] Offline switches are blocked if outlet not ready
- [ ] Online switches always sync before committing
- [ ] Error handling works (network failure, etc.)
- [ ] Logs show correct context (STARTUP_SYNC vs OUTLET_SWITCH)

## Benefits Summary

1. ✅ **Consistency:** Same sync flow everywhere
2. ✅ **Reliability:** Outlet only committed after full validation
3. ✅ **Visibility:** Users see progress during switches
4. ✅ **Offline-first:** Proper validation before allowing switches
5. ✅ **Maintainability:** Single source of truth for outlet preparation
6. ✅ **User Experience:** Mirrors familiar startup sync UI
