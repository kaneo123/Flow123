import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:flowtill/models/product.dart' as models;
import 'package:flowtill/models/category.dart' as models;
import 'package:flowtill/models/staff.dart' as models;
import 'package:flowtill/models/printer.dart' as models;
import 'package:flowtill/models/outlet_settings.dart' as models;
import 'package:flowtill/models/tax_rate.dart' as models;
import 'package:flowtill/models/promotion.dart' as models;
import 'package:flowtill/services/loyalty_service.dart';
import 'package:flowtill/config/sync_config.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

/// Synchronization service for offline/online data sync
/// 
/// DATA LIFECYCLE STRATEGY:
/// 
/// 1. MASTER/CATALOG DATA (Always fresh from Supabase when online):
///    - Products, Categories, Outlets, Staff, Printers, Tax Rates, Promotions, Settings
///    - Strategy: Always fetch full dataset from Supabase when online
///    - Local cache: Used only for offline access (mobile/desktop)
///    - No incremental sync - always get latest data
/// 
/// 2. TRANSACTIONAL DATA (Bidirectional sync with auto-cleanup):
///    - Orders, Transactions, Stock Updates
///    - Strategy: 
///      - Create locally and queue in outbox for upload
///      - Sync to Supabase when online
///      - Keep 30 days of synced data locally, then auto-delete
///      - Failed outbox items (>5 retries) are auto-deleted
/// 
/// 3. SYNC FLOW:
///    - Critical data (products, categories, staff, printers) loads first (parallel)
///    - Non-critical data (promotions, tax rates, settings) loads in background
///    - Outbox queue processes pending uploads after data sync
///    - Old data cleanup runs automatically during full sync
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final AppDatabase _db = AppDatabase.instance;
  final ConnectionService _connectionService = ConnectionService();
  
  Timer? _syncTimer;
  bool _isSyncing = false;
  DateTime? _lastFullSync;
  DateTime? _lastOutboxSync;

  final StreamController<SyncStatus> _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get currentStatus => _currentStatus;

  /// Initialize sync service and start periodic sync
  Future<void> initialize() async {
    await _connectionService.initialize();
    
    // Listen to connection changes (only if auto-sync is enabled)
    if (kSyncOnConnectionRestore) {
      _connectionService.connectionStream.listen((isOnline) {
        if (isOnline) {
          debugPrint('🔄 Connection restored - triggering sync');
          syncAll();
        } else {
          debugPrint('📴 Connection lost - sync paused');
        }
      });
    } else {
      debugPrint('🔄 SyncService: Automatic sync on connection restore is DISABLED');
    }

    // Start periodic sync timer (only if enabled)
    if (kPeriodicBackgroundSync) {
      _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
        if (_connectionService.isOnline && !_isSyncing) {
          syncAll();
        }
      });
      debugPrint('🔄 SyncService: Periodic background sync is ENABLED (every 2 minutes)');
    } else {
      debugPrint('🔄 SyncService: Periodic background sync is DISABLED');
    }

    // Note: Content sync is controlled by kAutoContentSyncOnStartup flag
    debugPrint('🔄 SyncService initialized');
    debugPrint('   Auto content sync on startup: $kAutoContentSyncOnStartup');
    debugPrint('   Periodic background sync: $kPeriodicBackgroundSync');
    debugPrint('   Sync on connection restore: $kSyncOnConnectionRestore');
  }

  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
  }

  /// Sync critical data only (products, categories, staff, printers)
  /// This is the minimum needed for the till to function
  /// Always fetches fresh data when online (no incremental sync)
  Future<void> syncCriticalData([String? outletId]) async {
    if (!_connectionService.isOnline) {
      debugPrint('📴 Offline - critical sync skipped');
      return;
    }

    _updateStatus(SyncStatus.syncing);

    try {
      debugPrint('⚡ Starting CRITICAL data sync (full refresh)...');
      final startTime = DateTime.now();

      final supabase = SupabaseConfig.client;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Load only critical data in parallel (always full refresh)
      await Future.wait([
        _fetchOutlets(supabase, now),
        _fetchProducts(supabase, outletId ?? '', now),
        _fetchCategories(supabase, outletId ?? '', now),
        _fetchStaff(supabase, outletId ?? '', now),
        _fetchPrinters(supabase, outletId ?? '', now),
      ], eagerError: false);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('✅ Critical data sync completed in ${duration}ms');
      
      // Trigger background sync for non-critical data
      _syncNonCriticalDataInBackground(outletId);
    } catch (e, stackTrace) {
      debugPrint('❌ Critical sync failed: $e');
      debugPrint('Stack: $stackTrace');
    }
  }

  /// Sync non-critical data in background (promotions, tax rates, outlet settings)
  /// This runs after critical data and doesn't block the UI
  /// Always fetches fresh data when online (no incremental sync)
  void _syncNonCriticalDataInBackground([String? outletId]) {
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        debugPrint('🔄 Starting NON-CRITICAL data sync in background (full refresh)...');
        final startTime = DateTime.now();

        final supabase = SupabaseConfig.client;
        final now = DateTime.now().millisecondsSinceEpoch;

        await Future.wait([
          _fetchOutletSettings(supabase, outletId ?? '', now),
          _fetchTaxRates(supabase, now),
          _fetchPromotions(supabase, outletId ?? '', now),
        ], eagerError: false);

        final duration = DateTime.now().difference(startTime).inMilliseconds;
        debugPrint('✅ Non-critical data sync completed in ${duration}ms');

        // Process outbox queue after all data is synced
        await _processOutboxQueue();
      } catch (e) {
        debugPrint('⚠️ Non-critical sync failed (non-fatal): $e');
      }
    });
  }

  /// Sync all data: Download catalog from Supabase, then upload pending changes
  Future<void> syncAll([String? outletId]) async {
    if (_isSyncing) {
      debugPrint('⏳ Sync already in progress, skipping');
      return;
    }

    if (!_connectionService.isOnline) {
      debugPrint('📴 Offline - sync skipped');
      return;
    }

    _isSyncing = true;
    _updateStatus(SyncStatus.syncing);

    try {
      debugPrint('🔄 Starting full sync...');

      // Step 1: Download catalog data from Supabase (if needed)
      final shouldFullSync = _lastFullSync == null || 
          DateTime.now().difference(_lastFullSync!) > const Duration(minutes: 10);
      
      if (shouldFullSync && outletId != null) {
        await _downloadCatalogData(outletId);
        _lastFullSync = DateTime.now();
      }

      // Step 2: Upload pending changes from outbox queue
      await _processOutboxQueue();
      _lastOutboxSync = DateTime.now();

      // Step 3: Cleanup old transactional data
      await _cleanupOldData();

      _updateStatus(SyncStatus.success);
      debugPrint('✅ Sync completed successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Sync failed: $e');
      debugPrint('Stack: $stackTrace');
      _updateStatus(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  /// Download catalog data from Supabase and store in local DB
  /// Always fetches fresh data (no incremental sync for catalog)
  Future<void> _downloadCatalogData(String outletId) async {
    debugPrint('⬇️ Downloading catalog data from Supabase (full refresh)...');

    final supabase = SupabaseConfig.client;
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // 🚀 PARALLEL LOADING: Fetch all data concurrently
      final startTime = DateTime.now();
      
      final results = await Future.wait([
        _fetchOutlets(supabase, now),
        _fetchProducts(supabase, outletId, now),
        _fetchCategories(supabase, outletId, now),
        _fetchStaff(supabase, outletId, now),
        _fetchPrinters(supabase, outletId, now),
        _fetchOutletSettings(supabase, outletId, now),
        _fetchTaxRates(supabase, now),
        _fetchPromotions(supabase, outletId, now),
      ], eagerError: false);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('⚡ Parallel download completed in ${duration}ms');

    } catch (e, stackTrace) {
      debugPrint('❌ Failed to download catalog data: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
    }
  }

  Future<void> _fetchOutlets(dynamic supabase, int now) async {
    debugPrint('  🔄 Fetching all outlets (full refresh)');
    final response = await supabase.from('outlets').select().eq('active', true);
    final outletsList = response as List;
    
    final outletMaps = outletsList.map((json) => {
      'id': json['id'],
      'name': json['name'],
      'code': json['code'],
      'active': 1,
      'settings': jsonEncode(json['settings'] ?? {}),
      'enable_service_charge': (json['enable_service_charge'] ?? false) ? 1 : 0,
      'service_charge_percent': (json['service_charge_percent'] ?? 0).toDouble(),
      'updated_at': now,
    }).toList();
    
    await _db.insertOutlets(outletMaps);
    debugPrint('  ✅ Synced ${outletMaps.length} outlets');
  }

  Future<void> _fetchProducts(dynamic supabase, String outletId, int now) async {
    debugPrint('  🔄 Fetching all products (full refresh)');
    final response = await supabase.from('products').select().eq('outlet_id', outletId).eq('active', true);
    final productsList = (response as List).map((json) => models.Product.fromJson(json)).toList();
    
    final productMaps = productsList.map((p) => {
      'id': p.id,
      'name': p.name,
      'category_id': p.categoryId,
      'price': p.price,
      'is_active': p.active ? 1 : 0,
      'sort_order': p.sortOrder,
      'has_stock': p.trackStock ? 1 : 0,
      'stock_quantity': 0.0,
      'tax_rate_id': p.taxRateId,
      'image_url': null,
      'color': null,
      'updated_at': now,
    }).toList();
    
    await _db.insertProducts(productMaps);
    debugPrint('  ✅ Synced ${productMaps.length} products');
  }

  Future<void> _fetchCategories(dynamic supabase, String outletId, int now) async {
    debugPrint('  🔄 Fetching all categories (full refresh)');
    final response = await supabase.from('categories').select().eq('outlet_id', outletId).order('sort_order');
    final categoriesList = (response as List).map((json) => models.Category.fromJson(json)).toList();
    
    final categoryMaps = categoriesList.map((c) => {
      'id': c.id,
      'name': c.name,
      'sort_order': c.sortOrder,
      'color': null,
      'updated_at': now,
    }).toList();
    
    await _db.insertCategories(categoryMaps);
    debugPrint('  ✅ Synced ${categoryMaps.length} categories');
  }

  Future<void> _fetchStaff(dynamic supabase, String outletId, int now) async {
    debugPrint('  🔄 Fetching all staff (full refresh)');
    final response = await supabase.from('staff').select().eq('outlet_id', outletId).eq('active', true);
    final staffList = (response as List).map((json) => models.Staff.fromJson(json)).toList();
    
    final staffMaps = staffList.map((s) => {
      'id': s.id,
      'name': s.fullName,
      'pin': s.pinCode,
      'active': s.active ? 1 : 0,
      'updated_at': now,
    }).toList();
    
    await _db.insertStaffList(staffMaps);
    debugPrint('  ✅ Synced ${staffMaps.length} staff members');
  }

  Future<void> _fetchPrinters(dynamic supabase, String outletId, int now) async {
    debugPrint('  🔄 Fetching all printers (full refresh)');
    final response = await supabase.from('printers').select().eq('outlet_id', outletId);
    final printersList = (response as List).map((json) => models.Printer.fromJson(json)).toList();
    
    final printerMaps = printersList.map((p) => {
      'id': p.id,
      'name': p.name,
      'ip_address': p.ipAddress ?? '',
      'port': p.port ?? 9100,
      'printer_type': p.type,
      'is_active': p.active ? 1 : 0,
      'print_receipt': p.isDefaultReceipt ? 1 : 0,
      'print_kitchen': 0,
      'assigned_categories': null,
      'code_page': p.paperSize ?? 'CP437',
      'updated_at': now,
    }).toList();
    
    await _db.insertPrinters(printerMaps);
    debugPrint('  ✅ Synced ${printerMaps.length} printers');
  }

  Future<void> _fetchOutletSettings(dynamic supabase, String outletId, int now) async {
    debugPrint('  🔄 Fetching outlet settings (full refresh)');
    final response = await supabase.from('outlets').select().eq('id', outletId).single();
    
    if (response != null) {
      final settingsMap = {
        'outlet_id': outletId,
        'currency': response['currency'] ?? 'GBP',
        'tax_inclusive': 1,
        'receipt_footer': response['receipt_footer'],
        'receipt_codepage': response['receipt_codepage'] ?? 'CP437',
        'updated_at': now,
      };
      
      await _db.insertOutletSettings(settingsMap);
      debugPrint('  ✅ Synced outlet settings');
    }
  }

  Future<void> _fetchTaxRates(dynamic supabase, int now) async {
    debugPrint('  🔄 Fetching all tax rates (full refresh)');
    final response = await supabase.from('tax_rates').select();
    final taxRatesList = (response as List).map((json) => models.TaxRate.fromJson(json)).toList();
    
    final taxRateMaps = taxRatesList.map((t) => {
      'id': t.id,
      'name': t.name,
      'rate': t.rate,
      'updated_at': now,
    }).toList();
    
    await _db.insertTaxRates(taxRateMaps);
    debugPrint('  ✅ Synced ${taxRateMaps.length} tax rates');
  }

  Future<void> _fetchPromotions(dynamic supabase, String outletId, int now) async {
    debugPrint('  🔄 Fetching all promotions (full refresh)');
    final response = await supabase.from('promotions').select().eq('outlet_id', outletId).eq('active', true);
    final promotionsList = (response as List).map((json) => models.Promotion.fromJson(json)).toList();
    
    final promotionMaps = promotionsList.map((p) => {
      'id': p.id,
      'name': p.name,
      'promotion_type': p.discountType.toString(),
      'discount_value': p.discountValue ?? 0.0,
      'discount_type': p.discountType.toString(),
      'is_active': p.active ? 1 : 0,
      'start_date': p.startDateTime?.millisecondsSinceEpoch,
      'end_date': p.endDateTime?.millisecondsSinceEpoch,
      'updated_at': now,
    }).toList();
    
    await _db.insertPromotions(promotionMaps);
    debugPrint('  ✅ Synced ${promotionMaps.length} promotions');
  }

  /// Process outbox queue - upload pending changes to Supabase
  Future<void> _processOutboxQueue() async {
    debugPrint('⬆️ Processing outbox queue...');

    final pendingItems = await _db.getPendingOutboxItems(limit: 100);
    if (pendingItems.isEmpty) {
      debugPrint('  ℹ️ No pending items in outbox');
      return;
    }

    debugPrint('  📤 Processing ${pendingItems.length} pending items');
    
    int successCount = 0;
    int failCount = 0;
    
    for (final item in pendingItems) {
      try {
        final itemId = item['id'] as int;
        final entityType = item['entity_type'] as String;
        final entityId = item['entity_id'] as String;
        final retryCount = item['retry_count'] as int? ?? 0;
        
        debugPrint('  📦 Processing item #$itemId: $entityType ($entityId) - Retry: $retryCount');
        
        await _processOutboxItem(item);
        await _db.markOutboxItemProcessed(itemId);
        
        successCount++;
        debugPrint('  ✅ Item #$itemId synced successfully');
      } catch (e, stackTrace) {
        failCount++;
        final itemId = item['id'] as int;
        final entityType = item['entity_type'] as String;
        debugPrint('  ❌ Failed to process outbox item #$itemId ($entityType): $e');
        debugPrint('  Stack: ${stackTrace.toString().substring(0, 200)}...');
        await _db.incrementOutboxRetry(itemId, e.toString());
      }
    }

    // Delete items that have failed too many times (more than 5 retries)
    final deletedCount = await _db.deleteFailedOutboxItems(5);
    if (deletedCount > 0) {
      debugPrint('  🗑️ Deleted $deletedCount failed items (exceeded retry limit)');
    }

    debugPrint('  ✅ Outbox queue processed: $successCount succeeded, $failCount failed');
  }

  /// Process a single outbox item
  Future<void> _processOutboxItem(Map<String, dynamic> item) async {
    final supabase = SupabaseConfig.client;
    final payload = jsonDecode(item['payload'] as String) as Map<String, dynamic>;
    final operation = item['operation'] as String;
    final entityType = item['entity_type'] as String;
    final entityId = item['entity_id'] as String;

    switch (entityType) {
      case 'order':
        if (operation == 'insert') {
          // Insert order into Supabase
          await supabase.from('orders').insert(payload);
          debugPrint('    ✅ Uploaded order $entityId');
        } else if (operation == 'update') {
          // Update order in Supabase
          await supabase.from('orders').update(payload).eq('id', entityId);
          debugPrint('    ✅ Updated order $entityId');
        }
        break;

      case 'transaction':
        if (operation == 'insert') {
          await supabase.from('transactions').insert(payload);
          debugPrint('    ✅ Uploaded transaction $entityId');
        }
        break;

      case 'loyalty':
        await LoyaltyService.processOutboxPayload(payload);
        debugPrint('    ✅ Processed loyalty payload $entityId');
        break;

      case 'stock_update':
        if (operation == 'update') {
          await supabase.from('inventory_items').update(payload).eq('id', entityId);
          debugPrint('    ✅ Updated stock $entityId');
        }
        break;

      default:
        debugPrint('    ⚠️ Unknown entity type: $entityType');
    }
  }

  /// Force an immediate sync
  Future<void> forceSyncNow([String? outletId]) async {
    debugPrint('🔄 Force sync requested (full refresh)');
    _lastFullSync = null; // Force full sync
    await syncAll(outletId);
  }

  /// Manual sync for testing
  Future<void> manualSync([String? outletId]) async {
    await syncAll(outletId);
  }

  /// Cleanup old transactional data (orders and outbox items)
  /// Keep 30 days of synced orders, clean up failed outbox items
  Future<void> _cleanupOldData() async {
    debugPrint('🧹 SyncService: Cleaning up old transactional data...');
    
    try {
      // Clean up orders older than 30 days that have been synced
      await _db.cleanupOldOrders(30);
      
      // Delete failed outbox items (more than 5 retries)
      await _db.deleteFailedOutboxItems(5);
      
      debugPrint('✅ Old data cleanup completed');
    } catch (e) {
      debugPrint('⚠️ Error during cleanup: $e');
    }
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncStatusController.close();
  }
}
