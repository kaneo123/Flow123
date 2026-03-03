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

  /// Upsert order + items, queue if Supabase fails
  Future<bool> upsertOrderWithItems(EposOrder order, List<EposOrderItem> items) async {
    final isOnline = _connectionService.isOnline;
    if (isOnline) {
      try {
        final saved = await _cloudRepo.upsertOrderWithItems(order, items);
        if (saved) return true;
      } catch (e, stack) {
        debugPrint('⚠️ Hybrid upsertOrderWithItems failed online, will fallback: $e');
        debugPrint('Stack: $stack');
      }
    }

    debugPrint('📥 Falling back to local queue for order ${order.id}');
    return _offlineRepo.upsertOrderWithItems(order, items);
  }

  Future<bool> completeOrder(String orderId, {
    required String paymentMethod,
    required double amountPaid,
    double changeDue = 0.0,
  }) async {
    final isOnline = _connectionService.isOnline;
    if (isOnline) {
      try {
        final success = await _cloudRepo.completeOrder(
          orderId,
          paymentMethod: paymentMethod,
          amountPaid: amountPaid,
          changeDue: changeDue,
        );
        if (success) return true;
      } catch (e, stack) {
        debugPrint('⚠️ Hybrid completeOrder failed online, will fallback: $e');
        debugPrint('Stack: $stack');
      }
    }

    debugPrint('📥 Falling back to local completion for order $orderId');
    return _offlineRepo.completeOrder(
      orderId,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      changeDue: changeDue,
    );
  }

  Future<bool> parkOrder(String orderId) async {
    final isOnline = _connectionService.isOnline;
    if (isOnline) {
      try {
        final success = await _cloudRepo.parkOrder(orderId);
        if (success) return true;
      } catch (e, stack) {
        debugPrint('⚠️ Hybrid parkOrder failed online, will fallback: $e');
        debugPrint('Stack: $stack');
      }
    }

    debugPrint('📥 Falling back to local park for order $orderId');
    return _offlineRepo.parkOrder(orderId);
  }

  Future<bool> voidOrder(String orderId) async {
    final isOnline = _connectionService.isOnline;
    if (isOnline) {
      try {
        final success = await _cloudRepo.voidOrder(orderId);
        if (success) return true;
      } catch (e, stack) {
        debugPrint('⚠️ Hybrid voidOrder failed online, will fallback: $e');
        debugPrint('Stack: $stack');
      }
    }

    debugPrint('📥 Falling back to local void for order $orderId');
    return _offlineRepo.voidOrder(orderId);
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
    try {
      final cloud = await _cloudRepo.getOrderById(orderId);
      if (cloud != null) return cloud;
    } catch (e, stack) {
      debugPrint('⚠️ Failed cloud getOrderById: $e');
      debugPrint('Stack: $stack');
      if (onlineOnly) {
        return null;
      }
    }

    if (onlineOnly) {
      return null;
    }

    return _offlineRepo.getOrderById(orderId);
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
    try {
      final cloud = await _cloudRepo.getOrderItems(orderId);
      if (cloud.isNotEmpty) return cloud;
    } catch (e, stack) {
      debugPrint('⚠️ Failed cloud getOrderItems: $e');
      debugPrint('Stack: $stack');
      if (onlineOnly) {
        return [];
      }
    }

    if (onlineOnly) {
      return [];
    }

    return _offlineRepo.getOrderItems(orderId);
  }

  Future<EposOrder?> createOrderHeaderForTable({
    required String outletId,
    required String tableId,
    required String tableNumber,
    String? staffId,
    int? covers,
  }) async {
    return createOrderHeader(
      outletId: outletId,
      staffId: staffId,
      orderType: 'table',
      tableId: tableId,
      tableNumber: tableNumber,
      covers: covers,
      onlineOnly: true,
    );
  }
}