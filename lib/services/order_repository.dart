import 'package:flowtill/models/epos_order.dart';
import 'package:flowtill/models/epos_order_item.dart';
import 'package:flowtill/models/order.dart';
import 'package:flowtill/models/order_with_meta.dart';
import 'package:flowtill/models/order_refund_status.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:uuid/uuid.dart';

class OrderRepository {
  final _uuid = const Uuid();

  /// Create a new order header in Supabase
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

    final result = await SupabaseService.insert('orders', order.toJson());

    if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
      return null;
    }

    final created = EposOrder.fromJson(result.data!.first);
    return created;
  }

  /// Upsert order with items (insert or update order + replace all items)
  Future<bool> upsertOrderWithItems(EposOrder order, List<EposOrderItem> items) async {
    try {
      // 1. Upsert the order header
      final orderResult = await SupabaseService.from('orders')
          .upsert(order.toJson())
          .select();

      if (orderResult.isEmpty) {
        return false;
      }

      // 2. Delete existing order items
      await SupabaseService.delete('order_items', filters: {'order_id': order.id});

      // 3. Insert new order items
      if (items.isNotEmpty) {
        final itemsJson = items.map((item) => item.toJson()).toList();
        final itemsResult = await SupabaseService.insertMultiple('order_items', itemsJson);

        if (!itemsResult.isSuccess) {
          return false;
        }
      }

      return true;
    } catch (e, stackTrace) {
      return false;
    }
  }

  /// Get all open orders for an outlet (status in 'open' or 'parked')
  Future<List<EposOrder>> getOpenOrdersForOutlet(String outletId) async {
    try {
      final response = await SupabaseService.from('orders')
          .select()
          .eq('outlet_id', outletId)
          .inFilter('status', ['open', 'parked'])
          .order('opened_at', ascending: false) as List<dynamic>;

      final orders = response.map((json) => EposOrder.fromJson(json as Map<String, dynamic>)).toList();
      return orders;
    } catch (e) {
      return [];
    }
  }

  /// Get open table orders (order_type='table')
  Future<List<EposOrder>> getOpenTables(String outletId) async {
    try {
      final response = await SupabaseService.from('orders')
          .select()
          .eq('outlet_id', outletId)
          .eq('order_type', 'table')
          .inFilter('status', ['open', 'parked'])
          .order('table_number', ascending: true) as List<dynamic>;

      final orders = response.map((json) => EposOrder.fromJson(json as Map<String, dynamic>)).toList();
      return orders;
    } catch (e) {
      return [];
    }
  }

  /// Get open tab orders (order_type='tab')
  Future<List<EposOrder>> getOpenTabs(String outletId) async {
    try {
      final response = await SupabaseService.from('orders')
          .select()
          .eq('outlet_id', outletId)
          .eq('order_type', 'tab')
          .inFilter('status', ['open', 'parked'])
          .order('tab_name', ascending: true) as List<dynamic>;

      final orders = response.map((json) => EposOrder.fromJson(json as Map<String, dynamic>)).toList();
      return orders;
    } catch (e) {
      return [];
    }
  }

  /// Get a single order by ID
  Future<EposOrder?> getOrderById(String orderId) async {
    final result = await SupabaseService.selectSingle(
      'orders',
      filters: {'id': orderId},
    );

    if (!result.isSuccess || result.data == null) {
      return null;
    }

    return EposOrder.fromJson(result.data!);
  }

  /// Find open order by table_id
  Future<EposOrder?> findOpenOrderByTable(String tableId) async {
    try {
      final response = await SupabaseService.from('orders')
          .select()
          .eq('table_id', tableId)
          .inFilter('status', ['open', 'parked'])
          .order('opened_at', ascending: false)
          .limit(1) as List<dynamic>;

      if (response.isEmpty) {
        return null;
      }

      final order = EposOrder.fromJson(response.first as Map<String, dynamic>);
      return order;
    } catch (e) {
      return null;
    }
  }

  /// Get active order for a specific table (status in 'open' or 'parked')
  /// Used to determine table occupancy - completed/void orders don't count
  Future<EposOrder?> getActiveOrderForTable({
    required String outletId,
    required String tableId,
  }) async {
    try {
      final response = await SupabaseService.from('orders')
          .select()
          .eq('outlet_id', outletId)
          .eq('table_id', tableId)
          .inFilter('status', ['open', 'parked'])
          .order('opened_at', ascending: false)
          .limit(1) as List<dynamic>;

      if (response.isEmpty) {
        return null;
      }

      final order = EposOrder.fromJson(response.first as Map<String, dynamic>);
      return order;
    } catch (e) {
      return null;
    }
  }

  /// Get order items for a specific order
  Future<List<EposOrderItem>> getOrderItems(String orderId) async {
    final result = await SupabaseService.select(
      'order_items',
      filters: {'order_id': orderId},
      orderBy: 'sort_order',
      ascending: true,
    );

    if (!result.isSuccess || result.data == null) {
      return [];
    }

    final items = result.data!.map((json) => EposOrderItem.fromJson(json)).toList();
    return items;
  }

  /// Complete an order (update status to 'completed', set completedAt, payment details)
  Future<bool> completeOrder(String orderId, {
    required String paymentMethod,
    required double amountPaid,
    double changeDue = 0.0,
  }) async {
    final result = await SupabaseService.update(
      'orders',
      {
        'status': 'completed',
        'payment_method': paymentMethod,
        'completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'change_due': changeDue,
      },
      filters: {'id': orderId},
    );

    return result.isSuccess;
  }

  /// Park an order (update status to 'parked')
  Future<bool> parkOrder(String orderId) async {
    final result = await SupabaseService.update(
      'orders',
      {
        'status': 'parked',
        'parked_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      filters: {'id': orderId},
    );

    return result.isSuccess;
  }

  /// Void an order (update status to 'void', frees the table)
  Future<bool> voidOrder(String orderId) async {
    final result = await SupabaseService.update(
      'orders',
      {
        'status': 'void',
        'completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      filters: {'id': orderId},
    );

    return result.isSuccess;
  }

  /// Convert in-memory Order to EposOrder and EposOrderItems for Supabase
  /// Create order header specifically for table orders
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

  (EposOrder, List<EposOrderItem>) convertToEposModels(Order order) {
    final now = DateTime.now();
    
    // Determine order type based on whether it has a table
    final orderType = order.tableId != null ? 'table' : 'quick_service';
    
    // Determine status based on completedAt
    final isCompleted = order.completedAt != null;
    
    final eposOrder = EposOrder(
      id: order.id,
      outletId: order.outletId,
      staffId: order.staffId,
      orderType: orderType,
      status: isCompleted ? 'completed' : 'open',
      // Keep table associations for history - status='completed' is what frees the table
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
      
      // For misc items (ID starts with 'misc_'), set productId and categoryId to null to avoid FK constraint
      final isMiscItem = item.product.id.startsWith('misc_');
      final productId = isMiscItem ? null : item.product.id;
      final categoryId = isMiscItem ? null : item.product.categoryId;
      
      return EposOrderItem(
        id: item.id,
        orderId: order.id,
        productId: productId,
        inventoryItemId: null, // Not stored in Product model
        categoryId: categoryId,
        productName: item.product.name,
        plu: item.product.plu,
        course: item.product.course,
        quantity: item.quantity.toDouble(),
        unitPrice: item.unitPrice,
        grossLineTotal: item.subtotal,
        discountAmount: 0.0,
        netLineTotal: item.subtotal,
        taxRate: item.taxRate,
        taxAmount: item.taxAmount,
        notes: item.notes,
        sortOrder: index,
        modifiers: item.selectedModifiers,
      );
    }).toList();

    return (eposOrder, eposItems);
  }

  /// Fetch completed orders for a date range with staff names and refund status
  Future<List<OrderWithMeta>> fetchOrdersForDateRange({
    required String outletId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      // Note: staff table has 'full_name' column, not 'name'
      final response = await SupabaseService.from('orders')
          .select('*, staff:staff_id(full_name)')
          .eq('outlet_id', outletId)
          .eq('status', 'completed')
          .gte('completed_at', from.toIso8601String())
          .lte('completed_at', to.toIso8601String())
          .order('completed_at', ascending: false) as List<dynamic>;

      if (response.isEmpty) {
        return [];
      }

      // Get all order IDs to fetch refunds in batch
      final orderIds = response.map((json) => json['id'] as String).toList();

      // Fetch refund transactions for all orders in one query
      // Note: Refunds are identified by payment_method='refund'
      Map<String, double> refundsByOrderId = {};
      if (orderIds.isNotEmpty) {
        final refundResponse = await SupabaseService.from('transactions')
            .select('order_id, amount_paid')
            .inFilter('order_id', orderIds)
            .eq('payment_method', 'refund') as List<dynamic>;

        // Sum refunds by order_id
        for (final refund in refundResponse) {
          final orderId = refund['order_id'] as String;
          final amount = (refund['amount_paid'] as num).toDouble().abs();
          refundsByOrderId[orderId] = (refundsByOrderId[orderId] ?? 0.0) + amount;
        }
      }

      // Map to OrderWithMeta
      final orders = response.map((json) {
        final order = EposOrder.fromJson(json);
        final staffName = json['staff'] != null ? (json['staff']['full_name'] as String?) : null;
        final totalRefunded = refundsByOrderId[order.id] ?? 0.0;
        
        final refundStatus = OrderRefundStatus.fromRefundAmount(
          refundedAmount: totalRefunded,
          orderTotal: order.totalDue,
        );

        return OrderWithMeta(
          order: order,
          staffName: staffName,
          refundStatus: refundStatus,
        );
      }).toList();

      return orders;
    } catch (e, stackTrace) {
      return [];
    }
  }

  /// Get order with metadata by ID
  Future<OrderWithMeta?> getOrderWithMetaById(String orderId) async {
    try {
      // Query order with staff join
      // Note: staff table has 'full_name' column, not 'name'
      final response = await SupabaseService.from('orders')
          .select('*, staff:staff_id(full_name)')
          .eq('id', orderId)
          .limit(1) as List<dynamic>;

      if (response.isEmpty) {
        return null;
      }

      final json = response.first;
      final order = EposOrder.fromJson(json);
      final staffName = json['staff'] != null ? (json['staff']['full_name'] as String?) : null;

      // Fetch refund transactions for this order
      // Note: Refunds are identified by payment_method='refund'
      final refundResponse = await SupabaseService.from('transactions')
          .select('amount_paid')
          .eq('order_id', orderId)
          .eq('payment_method', 'refund') as List<dynamic>;

      final totalRefunded = refundResponse.fold<double>(
        0.0,
        (sum, refund) => sum + (refund['amount_paid'] as num).toDouble().abs(),
      );

      final refundStatus = OrderRefundStatus.fromRefundAmount(
        refundedAmount: totalRefunded,
        orderTotal: order.totalDue,
      );

      return OrderWithMeta(
        order: order,
        staffName: staffName,
        refundStatus: refundStatus,
      );
    } catch (e, stackTrace) {
      return null;
    }
  }
}
