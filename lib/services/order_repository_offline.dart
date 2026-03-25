import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
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
    final orderId = _uuid.v4();
    
    // Log table identity if this is a table order
    if (orderType == 'table' && tableId != null) {
      debugPrint('[TABLE_FLOW] Creating order header:');
      debugPrint('[TABLE_FLOW]    order_id=$orderId');
      debugPrint('[TABLE_FLOW]    table_id=$tableId');
      debugPrint('[TABLE_FLOW]    table_number=$tableNumber');
    }
    
    final order = EposOrder(
      id: orderId,
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
  /// 
  /// USAGE CONTEXTS:
  /// 1. LOCAL USER EDIT (queueForSync=true): User creates/modifies order on device
  ///    - Allowed to update even if row is currently 'synced'
  ///    - Re-marks row as 'pending' to trigger re-sync of latest state
  /// 2. MIRROR IMPORT (queueForSync=false): Cloud-origin row being imported during mirror sync
  ///    - Protected from accidentally marking synced rows as pending
  ///    - Should use MirrorContentSyncService.importMirroredRow() instead
  Future<bool> upsertOrderWithItems(
    EposOrder order,
    List<EposOrderItem> items, {
    bool queueForSync = true,
  }) async {
    try {
      final db = await _db.database;
      
      // Get actual local table columns to ensure proper mapping
      final tableInfo = await db.rawQuery('PRAGMA table_info(orders)');
      final columnNames = tableInfo.map((col) => col['name'] as String).toSet();
      
      // Check if orders table has sync_status column (new offline sync system)
      final hasSyncStatus = columnNames.contains('sync_status');
      
      // TRANSACTIONAL UPDATE LOGIC:
      // Allow updating synced orders if this is a legitimate user edit (queueForSync=true)
      // Only block if this is a mirror import trying to overwrite a synced row (queueForSync=false)
      if (hasSyncStatus && !queueForSync) {
        // Mirror import path - protect synced rows from being corrupted
        final existing = await db.query(
          'orders',
          where: 'id = ?',
          whereArgs: [order.id],
          limit: 1,
        );
        
        if (existing.isNotEmpty) {
          final existingSyncStatus = existing.first['sync_status'] as String?;
          if (existingSyncStatus == 'synced') {
            debugPrint('[ORDER_REPO] ⚠️ PROTECTION: Refusing to overwrite synced order ${order.id} during mirror import');
            debugPrint('[ORDER_REPO]    This order came from cloud and should not be marked pending');
            debugPrint('[ORDER_REPO]    Use MirrorContentSyncService.importMirroredRow() for cloud-origin rows');
            return false;
          }
        }
      }
      
      // User edit path - check if we're updating a synced order
      if (hasSyncStatus && queueForSync) {
        final existing = await db.query(
          'orders',
          where: 'id = ?',
          whereArgs: [order.id],
          limit: 1,
        );
        
        if (existing.isNotEmpty) {
          final existingSyncStatus = existing.first['sync_status'] as String?;
          if (existingSyncStatus == 'synced') {
            debugPrint('[ORDER_REPO] 🔄 TRANSACTIONAL UPDATE: Order ${order.id} was synced, re-marking as pending');
            debugPrint('[ORDER_REPO]    Reason: Legitimate user modification (park/complete/add item)');
            debugPrint('[ORDER_REPO]    Action: Will update local row and re-sync latest state');
          }
        }
      }
      
      // Build order data map using ONLY columns that exist in the local schema
      // This prevents mismatched field name errors
      final localOrder = <String, dynamic>{
        'id': order.id,
      };
      
      // Map fields only if they exist in the actual schema
      if (columnNames.contains('outlet_id')) localOrder['outlet_id'] = order.outletId;
      if (columnNames.contains('table_id')) localOrder['table_id'] = order.tableId;
      if (columnNames.contains('table_number')) localOrder['table_number'] = order.tableNumber;
      if (columnNames.contains('staff_id')) localOrder['staff_id'] = order.staffId;
      if (columnNames.contains('status')) localOrder['status'] = order.status;
      
      // Log table identity for table orders
      if (order.orderType == 'table' && order.tableId != null) {
        debugPrint('[TABLE_FLOW] Saving order to local DB:');
        debugPrint('[TABLE_FLOW]    order_id=${order.id}');
        debugPrint('[TABLE_FLOW]    table_id=${order.tableId}');
        debugPrint('[TABLE_FLOW]    table_number=${order.tableNumber}');
      }
      if (columnNames.contains('order_type')) localOrder['order_type'] = order.orderType;
      if (columnNames.contains('subtotal')) localOrder['subtotal'] = order.subtotal;
      if (columnNames.contains('notes')) localOrder['notes'] = order.notes;
      if (columnNames.contains('created_at')) localOrder['created_at'] = order.openedAt.millisecondsSinceEpoch;
      if (columnNames.contains('updated_at')) localOrder['updated_at'] = DateTime.now().millisecondsSinceEpoch;
      
      // Handle items - stored as JSON in orders table if column exists
      // NOTE: Most schemas store items in separate order_items table, not in orders.items
      if (columnNames.contains('items')) {
        localOrder['items'] = jsonEncode(items.map((i) => i.toJson()).toList());
      }
      
      // Tax, discount, total fields - use actual Supabase column names (snake_case)
      if (columnNames.contains('tax_amount')) localOrder['tax_amount'] = order.taxAmount;
      if (columnNames.contains('discount_amount')) localOrder['discount_amount'] = order.discountAmount;
      if (columnNames.contains('total_due')) localOrder['total_due'] = order.totalDue;
      if (columnNames.contains('service_charge')) localOrder['service_charge'] = order.serviceCharge;
      if (columnNames.contains('voucher_amount')) localOrder['voucher_amount'] = order.voucherAmount;
      if (columnNames.contains('loyalty_redeemed')) localOrder['loyalty_redeemed'] = order.loyaltyRedeemed;
      if (columnNames.contains('total_paid')) localOrder['total_paid'] = order.totalPaid;
      if (columnNames.contains('change_due')) localOrder['change_due'] = order.changeDue;
      if (columnNames.contains('payment_method')) localOrder['payment_method'] = order.paymentMethod;
      
      // CRITICAL: Mark locally-created orders as 'pending' for upload
      // This is a NEW local order, not a mirrored cloud-origin row
      if (hasSyncStatus) {
        localOrder['sync_status'] = 'pending';
        localOrder['sync_error'] = null;
        localOrder['last_sync_attempt_at'] = null;
        localOrder['sync_attempt_count'] = 0;
        
        // Set device_id if available (could be enhanced to use actual device ID)
        if (columnNames.contains('device_id')) {
          localOrder['device_id'] = null; // TODO: Set to actual device ID
        }
        
        debugPrint('[ORDER_REPO] 💾 Saving LOCAL order with sync_status=pending: ${order.id}');
        debugPrint('[ORDER_REPO]    This order will be queued for upload to Supabase');
      }

      // SAFE UPSERT: Try update first, then insert if not exists
      // This prevents ConflictAlgorithm.replace from deleting and recreating the row
      final updateCount = await db.update(
        'orders',
        localOrder,
        where: 'id = ?',
        whereArgs: [order.id],
      );
      
      if (updateCount == 0) {
        // Row doesn't exist, insert it
        await db.insert('orders', localOrder);
        debugPrint('[ORDER_REPO]    ✅ Inserted new local order: ${order.id}');
      } else {
        debugPrint('[ORDER_REPO]    ✅ Updated existing local order: ${order.id}');
      }

      // Add to outbox queue for sync (with deduplication)
      if (queueForSync) {
        final orderJson = order.toJson();
        orderJson['items'] = items.map((i) => i.toJson()).toList();
        
        // Queue will deduplicate if an entry already exists
        await _db.addToOutbox(
          entityType: 'order',
          entityId: order.id,
          operation: 'insert',
          payload: orderJson,
        );
        
        debugPrint('[ORDER_REPO]    ✅ Queued for upload via outbox (deduplication handled by queue)');
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('[ORDER_REPO] ❌ Failed to save order: $e');
      debugPrint('Stack: $stackTrace');
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
  /// Queries order_items table (not orders.items column)
  Future<List<EposOrderItem>> getOrderItems(String orderId) async {
    try {
      final db = await _db.database;
      
      // Query order_items table directly (most schemas don't store items in orders table)
      final localItems = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
        orderBy: 'sort_order ASC',
      );
      
      if (localItems.isEmpty) {
        return [];
      }
      
      // Convert local items to EposOrderItem
      // CRITICAL: Do not use empty strings for UUID fields - use null instead
      final items = localItems.map((row) {
        final productId = row['product_id'] as String?;
        final categoryId = row['category_id'] as String?;
        
        return EposOrderItem(
          id: row['id'] as String,
          orderId: row['order_id'] as String,
          productId: productId?.isEmpty ?? true ? null : productId,
          productName: row['product_name'] as String,
          plu: row['plu'] as String?,
          categoryId: categoryId?.isEmpty ?? true ? null : categoryId,
          unitPrice: (row['unit_price'] as num).toDouble(),
          quantity: (row['quantity'] as num).toDouble(),
          taxRate: (row['tax_rate'] as num?)?.toDouble() ?? 0.0,
          course: row['course'] as String?,
          sortOrder: row['sort_order'] as int? ?? 0,
        );
      }).toList();
      
      return items;
    } catch (e, stackTrace) {
      debugPrint('[ORDER_REPO_OFFLINE] ❌ Failed to get order items: $e');
      debugPrint('Stack: $stackTrace');
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
  /// Updates local row status to 'parked' and queues for sync
  Future<bool> parkOrder(String orderId) async {
    try {
      final db = await _db.database;
      final now = DateTime.now();
      
      // Get actual local table columns
      final tableInfo = await db.rawQuery('PRAGMA table_info(orders)');
      final columnNames = tableInfo.map((col) => col['name'] as String).toSet();
      final hasSyncStatus = columnNames.contains('sync_status');
      
      // Build update map with only existing columns
      final updateData = <String, dynamic>{
        'status': 'parked',
        'updated_at': now.millisecondsSinceEpoch,
      };
      
      if (columnNames.contains('parked_at')) {
        updateData['parked_at'] = now.millisecondsSinceEpoch;
      }
      
      // Re-mark as pending if synced (transactional update)
      if (hasSyncStatus) {
        final existing = await db.query(
          'orders',
          where: 'id = ?',
          whereArgs: [orderId],
          limit: 1,
        );
        
        if (existing.isNotEmpty) {
          final existingSyncStatus = existing.first['sync_status'] as String?;
          if (existingSyncStatus == 'synced') {
            debugPrint('[ORDER_REPO_OFFLINE] 🔄 Park: Order $orderId was synced, re-marking as pending');
          }
        }
        
        updateData['sync_status'] = 'pending';
        updateData['sync_error'] = null;
        updateData['last_sync_attempt_at'] = null;
        updateData['sync_attempt_count'] = 0;
      }
      
      // Update local row
      await db.update(
        'orders',
        updateData,
        where: 'id = ?',
        whereArgs: [orderId],
      );
      
      debugPrint('[ORDER_REPO_OFFLINE] ✅ Local row updated to status=parked, sync_status=pending');
      
      // Queue for sync
      await _db.addToOutbox(
        entityType: 'order',
        entityId: orderId,
        operation: 'update',
        payload: {
          'id': orderId,
          'status': 'parked',
          'parked_at': now.toIso8601String(),
        },
      );

      return true;
    } catch (e, stackTrace) {
      debugPrint('[ORDER_REPO_OFFLINE] ❌ Failed to park order: $e');
      debugPrint('Stack: $stackTrace');
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

  /// Save order items locally with sync_status='pending'
  /// For locally-created order items that need to be synced to Supabase
  /// 
  /// TRANSACTIONAL UPDATES: If an item already exists with sync_status='synced',
  /// it will be re-marked as 'pending' to trigger re-sync of latest state
  Future<bool> saveOrderItemsLocally(List<EposOrderItem> items) async {
    if (items.isEmpty) return true;
    
    try {
      final db = await _db.database;
      
      // Get actual local table columns
      final tableInfo = await db.rawQuery('PRAGMA table_info(order_items)');
      final columnNames = tableInfo.map((col) => col['name'] as String).toSet();
      final hasSyncStatus = columnNames.contains('sync_status');
      
      debugPrint('[ORDER_REPO_OFFLINE] 💾 Saving ${items.length} order items locally');
      
      for (final item in items) {
        // Check if item already exists and is synced
        if (hasSyncStatus) {
          final existing = await db.query(
            'order_items',
            where: 'id = ?',
            whereArgs: [item.id],
            limit: 1,
          );
          
          if (existing.isNotEmpty) {
            final existingSyncStatus = existing.first['sync_status'] as String?;
            if (existingSyncStatus == 'synced') {
              debugPrint('[ORDER_REPO_OFFLINE]    🔄 Item ${item.id} was synced, re-marking as pending (transactional update)');
            }
          }
        }
        
        // Build item data map using only columns that exist
        final localItem = <String, dynamic>{
          'id': item.id,
        };
        
        if (columnNames.contains('order_id')) localItem['order_id'] = item.orderId;
        if (columnNames.contains('product_id')) localItem['product_id'] = item.productId;
        if (columnNames.contains('product_name')) localItem['product_name'] = item.productName;
        if (columnNames.contains('quantity')) localItem['quantity'] = item.quantity;
        if (columnNames.contains('unit_price')) localItem['unit_price'] = item.unitPrice;
        if (columnNames.contains('gross_line_total')) localItem['gross_line_total'] = item.grossLineTotal;
        if (columnNames.contains('net_line_total')) localItem['net_line_total'] = item.netLineTotal;
        if (columnNames.contains('discount_amount')) localItem['discount_amount'] = item.discountAmount;
        if (columnNames.contains('tax_rate')) localItem['tax_rate'] = item.taxRate;
        if (columnNames.contains('tax_amount')) localItem['tax_amount'] = item.taxAmount;
        if (columnNames.contains('notes')) localItem['notes'] = item.notes;
        if (columnNames.contains('plu')) localItem['plu'] = item.plu;
        if (columnNames.contains('course')) localItem['course'] = item.course;
        if (columnNames.contains('sort_order')) localItem['sort_order'] = item.sortOrder;
        if (columnNames.contains('modifiers') && item.modifiers.isNotEmpty) {
          localItem['modifiers'] = jsonEncode(item.modifiers.map((m) => m.toJson()).toList());
        }
        if (columnNames.contains('created_at')) localItem['created_at'] = DateTime.now().millisecondsSinceEpoch;
        
        // Mark as pending for local-origin items (or re-pending for synced items being modified)
        if (hasSyncStatus) {
          localItem['sync_status'] = 'pending';
          localItem['sync_error'] = null;
          localItem['last_sync_attempt_at'] = null;
          localItem['sync_attempt_count'] = 0;
        }
        
        // Safe upsert
        final updateCount = await db.update(
          'order_items',
          localItem,
          where: 'id = ?',
          whereArgs: [item.id],
        );
        
        if (updateCount == 0) {
          await db.insert('order_items', localItem);
          debugPrint('[ORDER_REPO_OFFLINE]    ✅ Inserted item ${item.id} (${item.productName}) - sync_status=pending');
        } else {
          debugPrint('[ORDER_REPO_OFFLINE]    ✅ Updated item ${item.id} (${item.productName}) - sync_status=pending');
        }
      }
      
      // Add to outbox for sync
      for (final item in items) {
        await _db.addToOutbox(
          entityType: 'order_item',
          entityId: item.id,
          operation: 'insert',
          payload: item.toJson(),
        );
      }
      
      debugPrint('[ORDER_REPO_OFFLINE] ✅ All order items saved and queued for sync');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[ORDER_REPO_OFFLINE] ❌ Failed to save order items: $e');
      debugPrint('Stack: $stackTrace');
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
  /// Uses actual Supabase column names (snake_case) for reading
  EposOrder _localOrderToEposOrder(Map<String, dynamic> localOrder) {
    // Decode items if stored in orders table (some schemas store items separately)
    List<EposOrderItem> items = [];
    if (localOrder.containsKey('items') && localOrder['items'] != null) {
      try {
        final itemsJson = jsonDecode(localOrder['items'] as String) as List<dynamic>;
        items = itemsJson.map((json) => EposOrderItem.fromJson(json as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('[ORDER_REPO] ⚠️ Failed to decode items: $e');
      }
    }
    
    // Use actual Supabase column names (snake_case) with fallbacks
    final subtotal = (localOrder['subtotal'] as num?)?.toDouble() ?? 0.0;
    final taxAmount = (localOrder['tax_amount'] as num?)?.toDouble() ?? 
                      (localOrder['tax_total'] as num?)?.toDouble() ?? 0.0;
    final discountAmount = (localOrder['discount_amount'] as num?)?.toDouble() ?? 
                           (localOrder['discount_total'] as num?)?.toDouble() ?? 0.0;
    final totalDue = (localOrder['total_due'] as num?)?.toDouble() ?? 
                     (localOrder['total'] as num?)?.toDouble() ?? 0.0;
    final serviceCharge = (localOrder['service_charge'] as num?)?.toDouble() ?? 0.0;
    final voucherAmount = (localOrder['voucher_amount'] as num?)?.toDouble() ?? 0.0;
    final loyaltyRedeemed = (localOrder['loyalty_redeemed'] as num?)?.toDouble() ?? 0.0;
    final totalPaid = (localOrder['total_paid'] as num?)?.toDouble() ?? 0.0;
    final changeDue = (localOrder['change_due'] as num?)?.toDouble() ?? 0.0;

    final orderId = localOrder['id'] as String;
    final orderType = localOrder['order_type'] as String? ?? 'quick_service';
    final tableId = localOrder['table_id'] as String?;
    final tableNumber = localOrder['table_number'] as String?;
    
    // Log table identity for table orders being loaded from local DB
    if (orderType == 'table' && tableId != null) {
      debugPrint('[TABLE_FLOW] Loading order from local DB:');
      debugPrint('[TABLE_FLOW]    order_id=$orderId');
      debugPrint('[TABLE_FLOW]    table_id=$tableId');
      debugPrint('[TABLE_FLOW]    table_number=$tableNumber');
    }

    return EposOrder(
      id: orderId,
      outletId: localOrder['outlet_id'] as String,
      staffId: localOrder['staff_id'] as String?,
      orderType: orderType,
      status: localOrder['status'] as String,
      tableId: tableId,
      tableNumber: tableNumber,
      subtotal: subtotal,
      taxAmount: taxAmount,
      serviceCharge: serviceCharge,
      discountAmount: discountAmount,
      voucherAmount: voucherAmount,
      loyaltyRedeemed: loyaltyRedeemed,
      totalDue: totalDue,
      totalPaid: totalPaid,
      changeDue: changeDue,
      paymentMethod: localOrder['payment_method'] as String?,
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
      
      // Normalize UUID fields: convert empty strings to null
      final productId = item.product.id.isEmpty ? null : item.product.id;
      final categoryId = item.product.categoryId?.isEmpty ?? true ? null : item.product.categoryId;
      
      return EposOrderItem(
        id: item.id,
        orderId: order.id,
        productId: productId,
        productName: item.product.name,
        plu: null,  // Use null instead of empty string
        categoryId: categoryId,
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
