import 'package:flutter/foundation.dart';
import 'package:flowtill/models/epos_transaction.dart';
import 'package:flowtill/models/epos_order.dart';
import 'package:flowtill/models/epos_order_item.dart';
import 'package:flowtill/models/refund_transaction.dart';
import 'package:flowtill/services/inventory_repository.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:uuid/uuid.dart';

class TransactionRepository {
  final _uuid = const Uuid();
  final _inventoryRepository = InventoryRepository();

  /// Record a transaction after payment completion
  /// This creates the main payment transaction and additional transactions for discounts/vouchers/loyalty
  Future<EposTransaction?> recordTransactionFromOrder({
    required EposOrder order,
    required String paymentMethod,
    required double amountPaid,
    double changeGiven = 0.0,
    String? tillId,
    String? paymentRef,
    Map<String, dynamic>? meta,
  }) async {
    debugPrint('💰 TransactionRepository: Recording transaction for order ${order.id}');
    debugPrint('   Payment Method: $paymentMethod');
    debugPrint('   Amount Paid: £${amountPaid.toStringAsFixed(2)}');
    debugPrint('   Change: £${changeGiven.toStringAsFixed(2)}');

    final transaction = EposTransaction(
      id: _uuid.v4(),
      outletId: order.outletId,
      orderId: order.id,
      staffId: order.staffId,
      paymentMethod: paymentMethod,
      paymentStatus: 'completed',
      amountPaid: amountPaid,
      changeGiven: changeGiven,
      subtotal: order.subtotal,
      taxAmount: order.taxAmount,
      serviceCharge: order.serviceCharge,
      discountAmount: order.discountAmount,
      voucherAmount: order.voucherAmount,
      loyaltyRedeemed: order.loyaltyRedeemed,
      totalDue: order.totalDue,
      tillId: tillId,
      paymentRef: paymentRef,
      meta: meta,
      createdAt: DateTime.now(),
    );

    final result = await SupabaseService.insert('transactions', transaction.toJson());

    if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
      debugPrint('❌ Failed to record transaction: ${result.error}');
      return null;
    }

    final created = EposTransaction.fromJson(result.data!.first);
    debugPrint('✅ Transaction recorded: ${created.id}');
    
    // Record additional transactions for discounts, vouchers, and loyalty if present
    if (order.discountAmount > 0) {
      await _recordAdjustmentTransaction(
        order: order,
        type: 'discount',
        amount: order.discountAmount,
      );
    }
    
    if (order.voucherAmount > 0) {
      await _recordAdjustmentTransaction(
        order: order,
        type: 'voucher',
        amount: order.voucherAmount,
      );
    }
    
    if (order.loyaltyRedeemed > 0) {
      await _recordAdjustmentTransaction(
        order: order,
        type: 'loyalty',
        amount: order.loyaltyRedeemed,
      );
    }
    
    return created;
  }

  /// Record adjustment transactions (discount, voucher, loyalty)
  Future<void> _recordAdjustmentTransaction({
    required EposOrder order,
    required String type,
    required double amount,
  }) async {
    debugPrint('🎫 TransactionRepository: Recording $type transaction (£${amount.toStringAsFixed(2)})');

    final transaction = EposTransaction(
      id: _uuid.v4(),
      outletId: order.outletId,
      orderId: order.id,
      staffId: order.staffId,
      paymentMethod: type,
      paymentStatus: 'completed',
      amountPaid: amount,
      changeGiven: 0.0,
      subtotal: 0.0,
      taxAmount: 0.0,
      serviceCharge: 0.0,
      discountAmount: type == 'discount' ? amount : 0.0,
      voucherAmount: type == 'voucher' ? amount : 0.0,
      loyaltyRedeemed: type == 'loyalty' ? amount : 0.0,
      totalDue: 0.0,
      meta: {'type': type},
      createdAt: DateTime.now(),
    );

    final result = await SupabaseService.insert('transactions', transaction.toJson());

    if (result.isSuccess) {
      debugPrint('✅ $type transaction recorded');
    } else {
      debugPrint('⚠️ Failed to record $type transaction: ${result.error}');
    }
  }

  /// Get all transactions for an outlet
  Future<List<EposTransaction>> getTransactionsForOutlet(
    String outletId, {
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    debugPrint('📥 TransactionRepository: Fetching transactions for outlet $outletId');

    try {
      dynamic query = SupabaseService.from('transactions')
          .select()
          .eq('outlet_id', outletId);

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      query = query.order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query as List<dynamic>;

      final transactions = response.map((json) => EposTransaction.fromJson(json as Map<String, dynamic>)).toList();
      debugPrint('✅ Fetched ${transactions.length} transactions');
      return transactions;
    } catch (e) {
      debugPrint('❌ Error fetching transactions: $e');
      return [];
    }
  }

  /// Get transactions by payment method
  Future<List<EposTransaction>> getTransactionsByPaymentMethod(
    String outletId,
    String paymentMethod, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    debugPrint('📥 TransactionRepository: Fetching $paymentMethod transactions');

    try {
      dynamic query = SupabaseService.from('transactions')
          .select()
          .eq('outlet_id', outletId)
          .eq('payment_method', paymentMethod);

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false) as List<dynamic>;

      final transactions = response.map((json) => EposTransaction.fromJson(json as Map<String, dynamic>)).toList();
      debugPrint('✅ Fetched ${transactions.length} $paymentMethod transactions');
      return transactions;
    } catch (e) {
      debugPrint('❌ Error fetching transactions by payment method: $e');
      return [];
    }
  }

  /// Get transaction totals by payment method for reporting
  Future<Map<String, double>> getTotalsByPaymentMethod(
    String outletId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    debugPrint('📊 TransactionRepository: Calculating totals by payment method');

    final transactions = await getTransactionsForOutlet(
      outletId,
      startDate: startDate,
      endDate: endDate,
    );

    final totals = <String, double>{};

    for (final transaction in transactions) {
      totals[transaction.paymentMethod] = (totals[transaction.paymentMethod] ?? 0.0) + transaction.totalDue;
    }

    debugPrint('✅ Totals by payment method: $totals');
    return totals;
  }

  /// Get total revenue for a date range
  Future<double> getTotalRevenue(
    String outletId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    debugPrint('💷 TransactionRepository: Calculating total revenue');

    final transactions = await getTransactionsForOutlet(
      outletId,
      startDate: startDate,
      endDate: endDate,
    );

    final total = transactions.fold<double>(0.0, (sum, t) => sum + t.totalDue);
    debugPrint('✅ Total revenue: £${total.toStringAsFixed(2)}');
    return total;
  }

  /// Get transaction count for a date range
  Future<int> getTransactionCount(
    String outletId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final transactions = await getTransactionsForOutlet(
      outletId,
      startDate: startDate,
      endDate: endDate,
    );

    return transactions.length;
  }

  /// Record a refund transaction (negative amount)
  Future<bool> refundOrder({
    required String orderId,
    required String outletId,
    required String staffId,
    required double amount,
    String? reason,
    bool restoreInventory = false,
  }) async {
    debugPrint('💸 TransactionRepository: Recording refund for order $orderId');
    debugPrint('   Amount: £${amount.toStringAsFixed(2)}');
    debugPrint('   Reason: ${reason ?? "None"}');
    debugPrint('   Restore Inventory: $restoreInventory');

    if (amount <= 0) {
      debugPrint('❌ Refund amount must be positive');
      return false;
    }

    // Check if order has already been refunded
    final existingRefunds = await getRefundsForOrder(orderId);
    if (existingRefunds.isNotEmpty) {
      final totalRefunded = existingRefunds.fold<double>(0.0, (sum, r) => sum + r.amount);
      debugPrint('⚠️ Order already has refunds totaling £${totalRefunded.toStringAsFixed(2)}');
      
      // Get original order total to prevent over-refunding
      try {
        final orderResponse = await SupabaseConfig.client
            .from('orders')
            .select('total_due')
            .eq('id', orderId)
            .maybeSingle();
        
        if (orderResponse != null) {
          final orderTotal = (orderResponse['total_due'] as num).toDouble();
          if (totalRefunded >= orderTotal) {
            debugPrint('❌ Order is already fully refunded');
            return false;
          }
          if (totalRefunded + amount > orderTotal) {
            debugPrint('❌ Refund amount exceeds remaining refundable amount');
            return false;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Could not verify order total: $e');
      }
    }

    // Build meta object
    final meta = <String, dynamic>{};
    if (reason != null) meta['reason'] = reason;
    meta['restore_inventory'] = restoreInventory;

    final refundTransaction = EposTransaction(
      id: _uuid.v4(),
      outletId: outletId,
      orderId: orderId,
      staffId: staffId,
      paymentMethod: 'refund',
      paymentStatus: 'completed',
      amountPaid: -amount, // Negative amount for refund
      changeGiven: 0.0,
      subtotal: 0.0,
      taxAmount: 0.0,
      serviceCharge: 0.0,
      discountAmount: 0.0,
      voucherAmount: 0.0,
      loyaltyRedeemed: 0.0,
      totalDue: 0.0,
      meta: meta,
      createdAt: DateTime.now(),
    );

    final result = await SupabaseService.insert('transactions', refundTransaction.toJson());

    if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
      debugPrint('❌ Failed to record refund: ${result.error}');
      return false;
    }

    // Restore inventory if requested
    if (restoreInventory) {
      await _restoreInventoryForOrder(orderId);
    }

    debugPrint('✅ Refund transaction recorded successfully');
    return true;
  }

  /// Get all refund transactions for an order
  Future<List<RefundTransaction>> getRefundsForOrder(String orderId) async {
    debugPrint('📥 TransactionRepository: Fetching refunds for order $orderId');

    try {
      final response = await SupabaseConfig.client
          .from('transactions')
          .select('*, staff:staff_id(full_name)')
          .eq('order_id', orderId)
          .eq('payment_method', 'refund')
          .order('created_at', ascending: false);

      final refunds = (response as List).map((json) {
        // Add staff name to the json
        final staffName = json['staff'] != null ? (json['staff']['full_name'] as String?) : null;
        final refundJson = Map<String, dynamic>.from(json);
        refundJson['staff_name'] = staffName;
        return RefundTransaction.fromJson(refundJson);
      }).toList();

      debugPrint('✅ Fetched ${refunds.length} refunds');
      return refunds;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching refunds: $e');
      debugPrint('Stack: $stackTrace');
      return [];
    }
  }

  /// Restore inventory for refunded order items
  Future<void> _restoreInventoryForOrder(String orderId) async {
    debugPrint('📦 TransactionRepository: Restoring inventory for order $orderId');

    try {
      // Fetch order and items
      final orderResponse = await SupabaseConfig.client
          .from('orders')
          .select('outlet_id')
          .eq('id', orderId)
          .maybeSingle();

      if (orderResponse == null) {
        debugPrint('❌ Order not found: $orderId');
        return;
      }

      final outletId = orderResponse['outlet_id'] as String;
      debugPrint('   Outlet ID: $outletId');

      final itemsResponse = await SupabaseConfig.client
          .from('order_items')
          .select()
          .eq('order_id', orderId);

      final items = (itemsResponse as List)
          .map((json) => EposOrderItem.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('   Found ${items.length} order items to restore');

      // Restore inventory for each item
      for (final item in items) {
        debugPrint('\n🔄 Processing order item: ${item.productName}');
        debugPrint('   - Product ID: ${item.productId}');
        debugPrint('   - Inventory Item ID: ${item.inventoryItemId}');
        debugPrint('   - Quantity to restore: ${item.quantity}');

        if (item.productId != null) {
          // Fetch the product to check its configuration
          final productResponse = await SupabaseConfig.client
              .from('products')
              .select('linked_inventory_item_id, track_stock')
              .eq('id', item.productId!)
              .maybeSingle();

          if (productResponse != null) {
            debugPrint('   - Product track_stock: ${productResponse['track_stock']}');
            debugPrint('   - Product linked_inventory_item_id: ${productResponse['linked_inventory_item_id']}');
          }

          // First try recipe-based restoration (enhanced inventory)
          debugPrint('   → Attempting recipe-based restoration...');
          await _inventoryRepository.restoreRecipeBasedStock(
            productId: item.productId!,
            quantity: item.quantity.toInt(),
          );

          // If recipe restoration failed, check for linked_inventory_item_id in product
          debugPrint('   → Recipe restoration failed, checking product.linked_inventory_item_id...');
          if (productResponse != null && productResponse['linked_inventory_item_id'] != null) {
            final linkedInventoryItemId = productResponse['linked_inventory_item_id'] as String;
            debugPrint('   → Found linked inventory item: $linkedInventoryItemId');
            
            final inventoryItem = await SupabaseConfig.client
                .from('inventory_items')
                .select('id, name, current_qty')
                .eq('id', linkedInventoryItemId)
                .maybeSingle();

            if (inventoryItem != null) {
              final currentQty = (inventoryItem['current_qty'] as num).toDouble();
              final newQty = currentQty + item.quantity;
              debugPrint('   → Inventory: ${inventoryItem['name']}');
              debugPrint('   → Current qty: $currentQty');
              debugPrint('   → New qty after restore: $newQty');
              
              await SupabaseConfig.client
                  .from('inventory_items')
                  .update({'current_qty': newQty})
                  .eq('id', linkedInventoryItemId);
              debugPrint('   ✓ Restored ${item.quantity} units via product.linked_inventory_item_id');
              continue;
            } else {
              debugPrint('   ⚠️ Inventory item $linkedInventoryItemId not found in database');
            }
          }

          // Fallback: try looking for inventory linked TO this product
          debugPrint('   → Checking for inventory items linked to this product...');
          await _inventoryRepository.incrementStockForProduct(
            outletId: outletId,
            productId: item.productId!,
            quantity: item.quantity.toInt(),
          );
        } else if (item.inventoryItemId != null) {
          // Direct inventory item restoration
          debugPrint('   → Direct inventory item restoration (item.inventoryItemId)');
          final inventoryItem = await SupabaseConfig.client
              .from('inventory_items')
              .select('id, name, current_qty')
              .eq('id', item.inventoryItemId!)
              .maybeSingle();

          if (inventoryItem != null) {
            final currentQty = (inventoryItem['current_qty'] as num).toDouble();
            final newQty = currentQty + item.quantity;
            debugPrint('   → Inventory: ${inventoryItem['name']}');
            debugPrint('   → Current qty: $currentQty');
            debugPrint('   → New qty after restore: $newQty');
            
            await SupabaseConfig.client
                .from('inventory_items')
                .update({'current_qty': newQty})
                .eq('id', item.inventoryItemId!);
            debugPrint('   ✓ Restored ${item.quantity} units to inventory item');
          } else {
            debugPrint('   ⚠️ Inventory item ${item.inventoryItemId} not found');
          }
        } else {
          debugPrint('   ⚠️ No product_id or inventory_item_id found for this item');
        }
      }

      debugPrint('\n✅ Inventory restoration process completed');
    } catch (e, stackTrace) {
      debugPrint('❌ Error restoring inventory: $e');
      debugPrint('Stack: $stackTrace');
    }
  }
}
