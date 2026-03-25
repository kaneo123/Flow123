import 'package:flutter/foundation.dart';
import 'package:flowtill/models/epos_order.dart';
import 'package:flowtill/models/epos_order_item.dart';
import 'package:flowtill/models/order.dart' as models;
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/services/order_repository.dart';
import 'package:flowtill/services/order_repository_offline.dart';

/// Cloud-first repository with offline failover + outbox queue
class OrderRepositoryHybrid {
  final _cloudRepo = OrderRepository();
  final _offlineRepo = OrderRepositoryOffline();
  final ConnectionService _connectionService = ConnectionService();

  /// Convert in-memory order to Supabase models (delegates to cloud repo)
  (EposOrder, List<EposOrderItem>) convertToEposModels(models.Order order) {
    return _cloudRepo.convertToEposModels(order);
  }

  /// Try Supabase first, fall back to local DB + outbox
  Future<EposOrder?> createOrderHeader({
    required String outletId,
    String? staffId,
    String orderType = 'quick_service',
    String? tableId,
    String? tableNumber,
    String? tabName,
    String? customerName,
    int? covers,
    bool onlineOnly = false,
  }) async {
    try {
      final created = await _cloudRepo.createOrderHeader(
        outletId: outletId,
        staffId: staffId,
        orderType: orderType,
        tableId: tableId,
        tableNumber: tableNumber,
        tabName: tabName,
        customerName: customerName,
        covers: covers,
      );

      if (created != null) {
        return created;
      }
    } catch (e, stack) {
      debugPrint('⚠️ Hybrid createOrderHeader failed online: $e');
      debugPrint('Stack: $stack');
      if (onlineOnly) {
        debugPrint('🚫 Offline fallback disabled for this request');
        return null;
      }
    }

    if (onlineOnly) {
      debugPrint('🚫 Skipping offline order creation (online-only mode)');
      return null;
    }

    // Offline fallback: create locally and queue immediately so tables show occupied
    final localOrder = await _offlineRepo.createOrderHeader(
      outletId: outletId,
      staffId: staffId,
      orderType: orderType,
      tableId: tableId,
      tableNumber: tableNumber,
      tabName: tabName,
      customerName: customerName,
      covers: covers,
    );

    if (localOrder != null) {
      await _offlineRepo.upsertOrderWithItems(localOrder, const [], queueForSync: false);
    }

    return localOrder;
  }

  /// Upsert order + items
  /// Platform-aware: Device builds use offline-first, web tries cloud first
  Future<bool> upsertOrderWithItems(EposOrder order, List<EposOrderItem> items) async {
    debugPrint('[ORDER_REPO] upsertOrderWithItems: ${order.id} (platform: ${kIsWeb ? "web" : "device"})');
    
    if (kIsWeb) {
      // Web: Try cloud first, fallback to local if fails
      final isOnline = _connectionService.isOnline;
      if (isOnline) {
        try {
          final saved = await _cloudRepo.upsertOrderWithItems(order, items);
          if (saved) {
            debugPrint('[ORDER_REPO] ✅ Web: Saved to Supabase directly');
            return true;
          }
        } catch (e, stack) {
          debugPrint('[ORDER_REPO] ⚠️ Web: Supabase upsert failed, will fallback: $e');
          debugPrint('Stack: $stack');
        }
      }

      debugPrint('[ORDER_REPO] 📥 Web: Falling back to local queue');
      return _offlineRepo.upsertOrderWithItems(order, items);
    } else {
      // Device: LOCAL-ONLY (no Supabase upsert, only local save + queue)
      debugPrint('[ORDER_REPO] Device: Saving locally with sync_status=pending');
      return _offlineRepo.upsertOrderWithItems(order, items, queueForSync: true);
    }
  }

  Future<bool> completeOrder(String orderId, {
    required String paymentMethod,
    required double amountPaid,
    double changeDue = 0.0,
  }) async {
    debugPrint('[ORDER_REPO] completeOrder: $orderId (platform: ${kIsWeb ? "web" : "device"})');
    
    if (kIsWeb) {
      // Web: Try cloud first, fallback to local if fails
      final isOnline = _connectionService.isOnline;
      if (isOnline) {
        try {
          final success = await _cloudRepo.completeOrder(
            orderId,
            paymentMethod: paymentMethod,
            amountPaid: amountPaid,
            changeDue: changeDue,
          );
          if (success) {
            debugPrint('[ORDER_REPO] ✅ Web: Completed order on Supabase');
            return true;
          }
        } catch (e, stack) {
          debugPrint('[ORDER_REPO] ⚠️ Web: Supabase complete failed, will fallback: $e');
          debugPrint('Stack: $stack');
        }
      }

      debugPrint('[ORDER_REPO] 📥 Web: Falling back to local completion');
      return _offlineRepo.completeOrder(
        orderId,
        paymentMethod: paymentMethod,
        amountPaid: amountPaid,
        changeDue: changeDue,
      );
    } else {
      // Device: LOCAL-ONLY (no Supabase update, only local + queue)
      debugPrint('[ORDER_REPO] Device: Completing order locally with sync_status=pending');
      return _offlineRepo.completeOrder(
        orderId,
        paymentMethod: paymentMethod,
        amountPaid: amountPaid,
        changeDue: changeDue,
      );
    }
  }

  Future<bool> parkOrder(String orderId) async {
    debugPrint('[PARK_ORDER] parkOrder: $orderId (platform: ${kIsWeb ? "web" : "device"})');
    
    if (kIsWeb) {
      // Web: Try cloud first, fallback to local if fails
      final isOnline = _connectionService.isOnline;
      if (isOnline) {
        try {
          final success = await _cloudRepo.parkOrder(orderId);
          if (success) {
            debugPrint('[PARK_ORDER] ✅ Web: Parked order on Supabase');
            return true;
          }
        } catch (e, stack) {
          debugPrint('[PARK_ORDER] ⚠️ Web: Supabase park failed, will fallback: $e');
          debugPrint('Stack: $stack');
        }
      }

      debugPrint('[PARK_ORDER] 📥 Web: Falling back to local park');
      return _offlineRepo.parkOrder(orderId);
    } else {
      // Device: LOCAL-ONLY (no Supabase update, only local + queue)
      debugPrint('[PARK_ORDER] Device: Parking order locally (will update existing outbox entry if present)');
      return _offlineRepo.parkOrder(orderId);
    }
  }

  Future<bool> voidOrder(String orderId) async {
    debugPrint('[ORDER_REPO] voidOrder: $orderId (platform: ${kIsWeb ? "web" : "device"})');
    
    if (kIsWeb) {
      // Web: Try cloud first, fallback to local if fails
      final isOnline = _connectionService.isOnline;
      if (isOnline) {
        try {
          final success = await _cloudRepo.voidOrder(orderId);
          if (success) {
            debugPrint('[ORDER_REPO] ✅ Web: Voided order on Supabase');
            return true;
          }
        } catch (e, stack) {
          debugPrint('[ORDER_REPO] ⚠️ Web: Supabase void failed, will fallback: $e');
          debugPrint('Stack: $stack');
        }
      }

      debugPrint('[ORDER_REPO] 📥 Web: Falling back to local void');
      return _offlineRepo.voidOrder(orderId);
    } else {
      // Device: LOCAL-ONLY (no Supabase update, only local + queue)
      debugPrint('[ORDER_REPO] Device: Voiding order locally with sync_status=pending');
      return _offlineRepo.voidOrder(orderId);
    }
  }

  /// Combine cloud + offline orders (offline entries override only if cloud missing)
  Future<List<EposOrder>> getOpenOrdersForOutlet(
    String outletId, {
    bool includeOffline = true,
  }) async {
    final Map<String, EposOrder> combined = {};

    try {
      final cloudOrders = await _cloudRepo.getOpenOrdersForOutlet(outletId);
      for (final order in cloudOrders) {
        combined[order.id] = order;
      }
    } catch (e, stack) {
      debugPrint('⚠️ Failed cloud getOpenOrders, using offline only: $e');
      debugPrint('Stack: $stack');
    }

    if (includeOffline) {
      try {
        final localOrders = await _offlineRepo
            .getOpenOrdersForOutlet(outletId)
            .timeout(const Duration(seconds: 2), onTimeout: () {
          debugPrint('⌛ Offline open orders fetch timed out, returning cloud results only');
          return <EposOrder>[];
        });

        for (final order in localOrders) {
          combined.putIfAbsent(order.id, () => order);
        }
      } catch (e, stack) {
        debugPrint('⚠️ Failed offline getOpenOrders, returning cloud results only: $e');
        debugPrint('Stack: $stack');
      }
    }

    final ordered = combined.values.toList()
      ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return ordered;
  }

  Future<List<EposOrder>> getOpenTables(String outletId, {bool includeOffline = false}) async {
    final Map<String, EposOrder> combined = {};

    try {
      final cloudOrders = await _cloudRepo.getOpenTables(outletId);
      for (final order in cloudOrders) {
        combined[order.id] = order;
      }
    } catch (e, stack) {
      debugPrint('⚠️ Failed cloud getOpenTables: $e');
      debugPrint('Stack: $stack');
    }

    if (includeOffline) {
      try {
        final localOrders = await _offlineRepo.getOpenTables(outletId).timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('⌛ Offline open tables fetch timed out, returning cloud results only');
            return <EposOrder>[];
          },
        );
        for (final order in localOrders) {
          combined.putIfAbsent(order.id, () => order);
        }
      } catch (e, stack) {
        debugPrint('⚠️ Failed offline getOpenTables, returning cloud results only: $e');
        debugPrint('Stack: $stack');
      }
    }

    return combined.values.toList();
  }

  Future<List<EposOrder>> getOpenTabs(String outletId, {bool includeOffline = false}) async {
    final Map<String, EposOrder> combined = {};

    try {
      final cloudOrders = await _cloudRepo.getOpenTabs(outletId);
      for (final order in cloudOrders) {
        combined[order.id] = order;
      }
    } catch (e, stack) {
      debugPrint('⚠️ Failed cloud getOpenTabs: $e');
      debugPrint('Stack: $stack');
    }

    if (includeOffline) {
      try {
        final localOrders = await _offlineRepo.getOpenTabs(outletId).timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('⌛ Offline open tabs fetch timed out, returning cloud results only');
            return <EposOrder>[];
          },
        );
        for (final order in localOrders) {
          combined.putIfAbsent(order.id, () => order);
        }
      } catch (e, stack) {
        debugPrint('⚠️ Failed offline getOpenTabs, returning cloud results only: $e');
        debugPrint('Stack: $stack');
      }
    }

    return combined.values.toList();
  }

  Future<EposOrder?> getOrderById(String orderId, {bool onlineOnly = false}) async {
    debugPrint('[RESUME_ORDER] getOrderById: $orderId (platform: ${kIsWeb ? "web" : "device"}, onlineOnly: $onlineOnly)');
    
    if (kIsWeb || onlineOnly) {
      // Web or forced online: Try cloud first
      try {
        final cloud = await _cloudRepo.getOrderById(orderId);
        if (cloud != null) {
          debugPrint('[RESUME_ORDER] ✅ Found in cloud');
          return cloud;
        }
      } catch (e, stack) {
        debugPrint('[RESUME_ORDER] ⚠️ Failed cloud getOrderById: $e');
        debugPrint('Stack: $stack');
        if (onlineOnly) {
          return null;
        }
      }

      if (onlineOnly) {
        return null;
      }

      // Fallback to local
      debugPrint('[RESUME_ORDER] Falling back to local');
      return _offlineRepo.getOrderById(orderId);
    } else {
      // Device: LOCAL-FIRST (prefer local pending orders)
      debugPrint('[RESUME_ORDER] Device: Checking local first');
      final local = await _offlineRepo.getOrderById(orderId);
      if (local != null) {
        debugPrint('[RESUME_ORDER] ✅ Found locally');
        return local;
      }
      
      // If not found locally, try cloud as fallback
      debugPrint('[RESUME_ORDER] Not found locally, checking cloud');
      try {
        final cloud = await _cloudRepo.getOrderById(orderId);
        if (cloud != null) {
          debugPrint('[RESUME_ORDER] ✅ Found in cloud');
        }
        return cloud;
      } catch (e, stack) {
        debugPrint('[RESUME_ORDER] ⚠️ Failed cloud getOrderById: $e');
        debugPrint('Stack: $stack');
        return null;
      }
    }
  }

  Future<EposOrder?> findOpenOrderByTable(String tableId, {bool onlineOnly = false}) async {
    try {
      final cloud = await _cloudRepo.findOpenOrderByTable(tableId);
      if (cloud != null) return cloud;
    } catch (e, stack) {
      debugPrint('⚠️ Failed cloud findOpenOrderByTable: $e');
      debugPrint('Stack: $stack');
      if (onlineOnly) {
        return null;
      }
    }

    if (onlineOnly) {
      return null;
    }

    return _offlineRepo.findOpenOrderByTable(tableId);
  }

  Future<EposOrder?> getActiveOrderForTable({
    required String outletId,
    required String tableId,
    bool onlineOnly = false,
  }) async {
    final startedAt = DateTime.now();
    try {
      final cloud = await _cloudRepo
          .getActiveOrderForTable(outletId: outletId, tableId: tableId)
          .timeout(const Duration(seconds: 6), onTimeout: () {
        debugPrint('⌛ Cloud getActiveOrderForTable timed out for table $tableId');
        return null;
      });
      if (cloud != null) {
        debugPrint('🌐 Cloud active order hit for $tableId in ${DateTime.now().difference(startedAt).inMilliseconds}ms');
        return cloud;
      }
    } catch (e, stack) {
      debugPrint('⚠️ Failed cloud getActiveOrderForTable: $e');
      debugPrint('Stack: $stack');
      if (onlineOnly) {
        return null;
      }
    }

    if (onlineOnly) {
      return null;
    }

    try {
      final local = await _offlineRepo
          .getActiveOrderForTable(outletId: outletId, tableId: tableId)
          .timeout(const Duration(seconds: 3), onTimeout: () {
        debugPrint('⌛ Offline getActiveOrderForTable timed out for table $tableId');
        return null;
      });
      if (local != null) {
        debugPrint('💾 Offline active order hit for $tableId in ${DateTime.now().difference(startedAt).inMilliseconds}ms');
      }
      return local;
    } catch (e, stack) {
      debugPrint('⚠️ Failed offline getActiveOrderForTable: $e');
      debugPrint('Stack: $stack');
      return null;
    }
  }

  Future<List<EposOrderItem>> getOrderItems(String orderId, {bool onlineOnly = false}) async {
    debugPrint('[RESUME_ORDER] getOrderItems: $orderId (platform: ${kIsWeb ? "web" : "device"}, onlineOnly: $onlineOnly)');
    
    if (kIsWeb || onlineOnly) {
      // Web or forced online: Try cloud first
      try {
        final cloud = await _cloudRepo.getOrderItems(orderId);
        if (cloud.isNotEmpty) {
          debugPrint('[RESUME_ORDER] ✅ Found ${cloud.length} items in cloud');
          return cloud;
        }
      } catch (e, stack) {
        debugPrint('[RESUME_ORDER] ⚠️ Failed cloud getOrderItems: $e');
        debugPrint('Stack: $stack');
        if (onlineOnly) {
          return [];
        }
      }

      if (onlineOnly) {
        return [];
      }

      // Fallback to local
      debugPrint('[RESUME_ORDER] Falling back to local items');
      return _offlineRepo.getOrderItems(orderId);
    } else {
      // Device: LOCAL-FIRST with cloud reconciliation
      // CROSS-TILL SUPPORT: Check both local and cloud, merge if cloud has newer data
      debugPrint('[RESUME_ORDER] Device: Checking local items first');
      final local = await _offlineRepo.getOrderItems(orderId);
      debugPrint('[RESUME_ORDER] Local items count: ${local.length}');
      
      // If online, also check cloud for newer items (cross-till edits)
      if (_connectionService.isOnline) {
        try {
          final cloud = await _cloudRepo.getOrderItems(orderId);
          debugPrint('[RESUME_ORDER] Cloud items count: ${cloud.length}');
          
          // If cloud has more items or different count, prefer cloud (cross-till edit detected)
          if (cloud.length != local.length) {
            debugPrint('[RESUME_ORDER] ⚠️ Item count mismatch detected (local: ${local.length}, cloud: ${cloud.length})');
            
            if (cloud.length > local.length) {
              debugPrint('[RESUME_ORDER] ✅ Cloud has newer items (cross-till edit), using cloud version');
              debugPrint('[RESUME_ORDER]    This order was likely edited on another till');
              return cloud;
            } else {
              debugPrint('[RESUME_ORDER] ⚠️ Local has more items than cloud - using local (may have pending sync)');
              return local;
            }
          }
          
          // Same count - prefer local for offline-first consistency
          if (local.isNotEmpty) {
            debugPrint('[RESUME_ORDER] ✅ Using ${local.length} local items (same count as cloud)');
            return local;
          }
          
          // Local empty but cloud has items - use cloud
          if (cloud.isNotEmpty) {
            debugPrint('[RESUME_ORDER] ✅ Local empty, using ${cloud.length} cloud items');
            return cloud;
          }
        } catch (e, stack) {
          debugPrint('[RESUME_ORDER] ⚠️ Failed cloud getOrderItems: $e');
          debugPrint('Stack: $stack');
          // Continue with local items
        }
      }
      
      // Offline or cloud check failed - use local items
      if (local.isNotEmpty) {
        debugPrint('[RESUME_ORDER] ✅ Using ${local.length} local items (offline or cloud unavailable)');
        return local;
      }
      
      debugPrint('[RESUME_ORDER] ⚠️ No items found locally or in cloud');
      return [];
    }
  }

  /// Create table order header
  /// Platform-aware: Device builds use offline-first, web uses online-only
  Future<EposOrder?> createOrderHeaderForTable({
    required String outletId,
    required String tableId,
    required String tableNumber,
    String? staffId,
    int? covers,
  }) async {
    debugPrint('[TABLE_FLOW] Creating table order header (platform: ${kIsWeb ? "web" : "device"})');
    
    if (kIsWeb) {
      // Web: online-only (direct Supabase, no offline queue)
      debugPrint('[TABLE_FLOW] Using CLOUD path (web)');
      return createOrderHeader(
        outletId: outletId,
        staffId: staffId,
        orderType: 'table',
        tableId: tableId,
        tableNumber: tableNumber,
        covers: covers,
        onlineOnly: true,
      );
    } else {
      // Device: LOCAL-ONLY (no Supabase insert, only local save + queue)
      debugPrint('[TABLE_FLOW] Using LOCAL-ONLY path (device)');
      return _createTableOrderLocalOnly(
        outletId: outletId,
        tableId: tableId,
        tableNumber: tableNumber,
        staffId: staffId,
        covers: covers,
      );
    }
  }
  
  /// Device-only: Create table order locally without touching Supabase
  Future<EposOrder?> _createTableOrderLocalOnly({
    required String outletId,
    required String tableId,
    required String tableNumber,
    String? staffId,
    int? covers,
  }) async {
    debugPrint('[ORDER_REPO] Creating table order LOCAL-ONLY (no Supabase insert)');
    debugPrint('[ORDER_REPO]    Table ID: $tableId');
    debugPrint('[ORDER_REPO]    Table Number: $tableNumber');
    
    // Create order header locally
    final localOrder = await _offlineRepo.createOrderHeader(
      outletId: outletId,
      staffId: staffId,
      orderType: 'table',
      tableId: tableId,
      tableNumber: tableNumber,
      covers: covers,
    );
    
    if (localOrder == null) {
      debugPrint('[ORDER_REPO] ❌ Failed to create local table order');
      return null;
    }
    
    debugPrint('[ORDER_REPO]    Created order ID: ${localOrder.id}');
    debugPrint('[ORDER_REPO]    Stored table_id: ${localOrder.tableId}');
    debugPrint('[ORDER_REPO]    Stored table_number: ${localOrder.tableNumber}');
    
    // Save locally with sync_status='pending' and queue for sync
    final saved = await _offlineRepo.upsertOrderWithItems(
      localOrder, 
      const [], 
      queueForSync: true,  // Queue immediately for sync
    );
    
    if (!saved) {
      debugPrint('[ORDER_REPO] ❌ Failed to save local table order');
      return null;
    }
    
    debugPrint('[ORDER_REPO] ✅ Table order created locally: ${localOrder.id}');
    debugPrint('[ORDER_REPO]    sync_status=pending, queued for upload');
    return localOrder;
  }
}