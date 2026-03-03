import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/models/epos_order.dart';
import 'package:flowtill/models/epos_order_item.dart';
import 'package:flowtill/models/order.dart' as models;
import 'package:flowtill/models/order_item.dart';
import 'package:uuid/uuid.dart';

/// Offline-first order repository using local database and outbox queue
class OrderRepositoryOffline {
  final AppDatabase _db = AppDatabase.instance;
  final _uuid = const Uuid();

  /// Create a new order header and save to local DB
  Future<EposOrder?> createOrderHeader({
    required String outletId,
    String? staffId,
    String orderType = 'quick_service',
    String? tableId,
    String? tableNumber,
    String? tabName,
    String? customerName,
    int? covers,
  }) async {
    final now = DateTime.now();
    final order = EposOrder(
      id: _uuid.v4(),
      outletId: outletId,
      staffId: staffId,
      orderType: orderType,
      status: 'open',
      tableId: tableId,
      tableNumber: tableNumber,
      tabName: tabName,
      customerName: customerName,
      covers: covers,
      openedAt: now,
      updatedAt: now,
    );

    return order;
  }

  /// Save order to local DB and queue for sync
  Future<bool> upsertOrderWithItems(
    EposOrder order,
    List<EposOrderItem> items, {
    bool queueForSync = true,
  }) async {
    try {
      // Convert to local Order model for storage
      final localOrder = {
        'id': order.id,
        'outlet_id': order.outletId,
        'table_id': order.tableId,
        'staff_id': order.staffId,
        'status': order.status,
        'order_type': order.orderType,
        'items': jsonEncode(items.map((i) => i.toJson()).toList()),
        'subtotal': order.subtotal,
        'tax_total': order.taxAmount,
        'discount_total': order.discountAmount,
        'total': order.totalDue,
        'notes': order.notes,
        'created_at': order.openedAt.millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'synced_at': null,
      };

      // Save to local DB
      await _db.insertOrder(localOrder);

      // Add to outbox queue for sync
      if (queueForSync) {
        final orderJson = order.toJson();
        orderJson['items'] = items.map((i) => i.toJson()).toList();
        
        await _db.addToOutbox(
          entityType: 'order',
          entityId: order.id,
          operation: 'insert',
          payload: orderJson,
        );
      }

      return true;
    } catch (e, stackTrace) {
      return false;
    }
  }

  /// Get all open orders from local DB
  Future<List<EposOrder>> getOpenOrdersForOutlet(String outletId) async {
    try {
      final db = await _db.database;
      final localOrders = await db.query(
        'orders',
        where: 'outlet_id = ? AND status != ?',
        whereArgs: [outletId, 'completed'],
        orderBy: 'created_at DESC',
      );

      final eposOrders = localOrders.map(_localOrderToEposOrder).toList();
      return eposOrders;
    } catch (e) {
      return [];
    }
  }

  /// Get open table orders
  Future<List<EposOrder>> getOpenTables(String outletId) async {
    try {
      final db = await _db.database;
      final localOrders = await db.query(
        'orders',
        where: 'outlet_id = ? AND table_id IS NOT NULL AND status != ?',
        whereArgs: [outletId, 'completed'],
        orderBy: 'created_at ASC',
      );

      final eposOrders = localOrders.map(_localOrderToEposOrder).toList();
      return eposOrders;
    } catch (e) {
      return [];
    }
  }

  /// Get open tab orders
  Future<List<EposOrder>> getOpenTabs(String outletId) async {
    try {
      final db = await _db.database;
      final localOrders = await db.query(
        'orders',
        where: 'outlet_id = ? AND order_type = ? AND status != ?',
        whereArgs: [outletId, 'tab', 'completed'],
        orderBy: 'created_at DESC',
      );

      final eposOrders = localOrders.map(_localOrderToEposOrder).toList();
      return eposOrders;
    } catch (e) {
      return [];
    }
  }

  /// Get a single order by ID
  Future<EposOrder?> getOrderById(String orderId) async {
    try {
      final localOrder = await _db.getOrderById(orderId);
      
      if (localOrder == null) {
        return null;
      }

      return _localOrderToEposOrder(localOrder);
    } catch (e) {
      return null;
    }
  }

  /// Find open order by table_id
  Future<EposOrder?> findOpenOrderByTable(String tableId) async {
    try {
      final db = await _db.database;
      final localOrders = await db.query(
        'orders',
        where: 'table_id = ? AND status != ?',
        whereArgs: [tableId, 'completed'],
        orderBy: 'created_at DESC',
        limit: 1,
      );

      if (localOrders.isEmpty) {
        return null;
      }

      final order = _localOrderToEposOrder(localOrders.first);
      return order;
    } catch (e) {
      return null;
    }
  }

  /// Get active order for a specific table
  Future<EposOrder?> getActiveOrderForTable({
    required String outletId,
    required String tableId,
  }) async {
    try {
      final db = await _db.database;
      final localOrders = await db.query(
        'orders',
        where: 'outlet_id = ? AND table_id = ? AND status != ?',
        whereArgs: [outletId, tableId, 'completed'],
        orderBy: 'created_at DESC',
        limit: 1,
      );

      if (localOrders.isEmpty) {
        return null;
      }

      final order = _localOrderToEposOrder(localOrders.first);
      return order;
    } catch (e) {
      return null;
    }
  }

  /// Get order items for a specific order
  Future<List<EposOrderItem>> getOrderItems(String orderId) async {
    try {
      final localOrder = await _db.getOrderById(orderId);
      
      if (localOrder == null) {
        return [];
      }

      final itemsJson = jsonDecode(localOrder['items'] as String) as List<dynamic>;
      final items = itemsJson.map((json) => EposOrderItem.fromJson(json as Map<String, dynamic>)).toList();
      return items;
    } catch (e) {
      return [];
    }
  }

  /// Complete an order
  Future<bool> completeOrder(String orderId, {
    required String paymentMethod,
    required double amountPaid,
    double changeDue = 0.0,
  }) async {
    try {
      final now = DateTime.now();
      await _db.updateOrder(orderId, {
        'status': 'completed',
        'updated_at': now.millisecondsSinceEpoch,
      });

      // Queue for sync
      await _db.addToOutbox(
        entityType: 'order',
        entityId: orderId,
        operation: 'update',
        payload: {
          'id': orderId,
          'status': 'completed',
          'payment_method': paymentMethod,
          'completed_at': now.toIso8601String(),
          'change_due': changeDue,
        },
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Park an order
  Future<bool> parkOrder(String orderId) async {
    try {
      await _db.addToOutbox(
        entityType: 'order',
        entityId: orderId,
        operation: 'update',
        payload: {
          'id': orderId,
          'status': 'parked',
          'parked_at': DateTime.now().toIso8601String(),
        },
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Void an order
  Future<bool> voidOrder(String orderId) async {
    try {
      final now = DateTime.now();
      await _db.updateOrder(orderId, {
        'status': 'void',
        'updated_at': now.millisecondsSinceEpoch,
      });

      await _db.addToOutbox(
        entityType: 'order',
        entityId: orderId,
        operation: 'update',
        payload: {
          'id': orderId,
          'status': 'void',
          'completed_at': now.toIso8601String(),
        },
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create order header for table
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
    );
  }

  /// Convert local Order to EposOrder
  EposOrder _localOrderToEposOrder(Map<String, dynamic> localOrder) {
    // Decode items to calculate totals
    final itemsJson = jsonDecode(localOrder['items'] as String) as List<dynamic>;
    final items = itemsJson.map((json) => EposOrderItem.fromJson(json as Map<String, dynamic>)).toList();
    
    final subtotal = (localOrder['subtotal'] as num?)?.toDouble() ?? 0.0;
    final taxAmount = (localOrder['tax_total'] as num?)?.toDouble() ?? 0.0;
    final discountAmount = (localOrder['discount_total'] as num?)?.toDouble() ?? 0.0;
    final total = (localOrder['total'] as num?)?.toDouble() ?? 0.0;

    return EposOrder(
      id: localOrder['id'] as String,
      outletId: localOrder['outlet_id'] as String,
      staffId: localOrder['staff_id'] as String?,
      orderType: localOrder['order_type'] as String? ?? 'quick_service',
      status: localOrder['status'] as String,
      tableId: localOrder['table_id'] as String?,
      tableNumber: (localOrder['table_id'] as String?)?.split('-').last,
      subtotal: subtotal,
      taxAmount: taxAmount,
      serviceCharge: 0.0,
      discountAmount: discountAmount,
      voucherAmount: 0.0,
      loyaltyRedeemed: 0.0,
      totalDue: total,
      totalPaid: 0.0,
      changeDue: 0.0,
      paymentMethod: null,
      openedAt: DateTime.fromMillisecondsSinceEpoch(localOrder['created_at'] as int),
      completedAt: null,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(localOrder['updated_at'] as int),
    );
  }

  /// Convert in-memory Order to EposOrder and EposOrderItems
  (EposOrder, List<EposOrderItem>) convertToEposModels(models.Order order) {
    final now = DateTime.now();
    
    final orderType = order.tableId != null ? 'table' : 'quick_service';
    final isCompleted = order.completedAt != null;
    
    final eposOrder = EposOrder(
      id: order.id,
      outletId: order.outletId,
      staffId: order.staffId,
      orderType: orderType,
      status: isCompleted ? 'completed' : 'open',
      tableId: order.tableId,
      tableNumber: order.tableNumber,
      subtotal: order.subtotal,
      taxAmount: order.taxAmount,
      serviceCharge: order.serviceCharge,
      discountAmount: order.discountAmount,
      voucherAmount: order.voucherAmount,
      loyaltyRedeemed: order.loyaltyRedeemed,
      totalDue: order.totalDue,
      totalPaid: order.amountPaid,
      changeDue: order.changeDue,
      paymentMethod: order.paymentMethod,
      openedAt: order.createdAt,
      completedAt: order.completedAt,
      updatedAt: now,
    );

    final eposItems = order.items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      
      return EposOrderItem(
        id: item.id,
        orderId: order.id,
        productId: item.product.id,
        productName: item.product.name,
        plu: '',
        categoryId: item.product.categoryId ?? '',
        unitPrice: item.product.price,
        quantity: item.quantity.toDouble(),
        taxRate: item.taxRate,
        course: null,
        sortOrder: index,
      );
    }).toList();

    return (eposOrder, eposItems);
  }
}
