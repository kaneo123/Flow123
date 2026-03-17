/// Configuration flags for synchronization behavior
/// 
/// This file controls when and how data syncing happens in the application.

/// Feature flag: Enable automatic content/data sync on app startup
/// 
/// When TRUE (future):
/// - Schema sync runs on startup (mirrors table structure)
/// - Content sync runs automatically when outlet is selected
/// - Critical data (products, categories, staff) downloads immediately
/// - Non-critical data (promotions, settings) downloads in background
/// 
/// When FALSE (current - Step 1):
/// - Schema sync runs on startup (mirrors table structure)
/// - Content sync does NOT run automatically
/// - All data sync must be triggered manually (e.g., from Dev Settings)
/// - This allows testing schema mirroring without downloading data
const bool kAutoContentSyncOnStartup = false;

/// Feature flag: Enable periodic background sync
/// 
/// When TRUE: Background sync timer runs every 2 minutes
/// When FALSE: No automatic periodic sync (manual sync only)
const bool kPeriodicBackgroundSync = false;

/// Feature flag: Enable sync on connection restore
/// 
/// When TRUE: Automatically sync when internet connection is restored
/// When FALSE: No automatic sync on connection changes
const bool kSyncOnConnectionRestore = false;

/// Feature flag: Use local mirror tables for reads (Step 3)
/// 
/// When TRUE:
/// - All services prefer reading from local SQLite mirror tables first
/// - Falls back to Supabase only if local is empty or unavailable
/// - Debug logs show data source: [LOCAL_MIRROR] or [SUPABASE_FALLBACK]
/// 
/// When FALSE:
/// - Services continue using original online-first logic
/// - Reads go directly to Supabase when online
const bool kUseLocalMirrorReads = true;
