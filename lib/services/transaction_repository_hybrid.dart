import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/models/epos_order.dart';
import 'package:flowtill/models/epos_transaction.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:uuid/uuid.dart';

/// Cloud-first transaction repository with offline outbox fallback
class TransactionRepositoryHybrid {
  final _uuid = const Uuid();
  final _db = AppDatabase.instance;
  final ConnectionService _connectionService = ConnectionService();

  /// Record a payment transaction. Falls back to outbox when offline or Supabase fails.
  Future<EposTransaction?> recordTransactionFromOrder({
    required EposOrder order,
    required String paymentMethod,
    required double amountPaid,
    double changeGiven = 0.0,
    String? tillId,
    String? paymentRef,
    Map<String, dynamic>? meta,
  }) async {
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

    // Cloud-first attempt
    if (_connectionService.isOnline) {
      try {
        final result = await SupabaseService.insert('transactions', transaction.toJson());
        if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
          final created = EposTransaction.fromJson(result.data!.first);
          // Record adjustments online as well
          await _recordAdjustmentIfNeeded(order, 'discount', order.discountAmount);
          await _recordAdjustmentIfNeeded(order, 'voucher', order.voucherAmount);
          await _recordAdjustmentIfNeeded(order, 'loyalty', order.loyaltyRedeemed);
          return created;
        }
      } catch (e, stack) {
        debugPrint('⚠️ Hybrid transaction insert failed online, will queue: $e');
        debugPrint('Stack: $stack');
      }
    }

    // Offline/failed: queue for outbox (including adjustments)
    await _queueTransaction(transaction);
    await _queueAdjustmentIfNeeded(order, 'discount', order.discountAmount);
    await _queueAdjustmentIfNeeded(order, 'voucher', order.voucherAmount);
    await _queueAdjustmentIfNeeded(order, 'loyalty', order.loyaltyRedeemed);
    return transaction;
  }

  Future<void> _recordAdjustmentIfNeeded(EposOrder order, String type, double amount) async {
    if (amount <= 0) return;

    final adjustment = EposTransaction(
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

    try {
      await SupabaseService.insert('transactions', adjustment.toJson());
    } catch (e, stack) {
      debugPrint('⚠️ Failed to record $type adjustment online, queuing: $e');
      debugPrint('Stack: $stack');
      await _queueTransaction(adjustment);
    }
  }

  Future<void> _queueAdjustmentIfNeeded(EposOrder order, String type, double amount) async {
    if (amount <= 0) return;

    final adjustment = EposTransaction(
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

    await _queueTransaction(adjustment);
  }

  /// Save transaction locally with sync_status='pending'
  /// For locally-created transactions that need to be synced to Supabase
  Future<EposTransaction?> saveTransactionLocally({
    required EposOrder order,
    required String paymentMethod,
    required double amountPaid,
    double changeGiven = 0.0,
    String? tillId,
    String? paymentRef,
    Map<String, dynamic>? meta,
  }) async {
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

    try {
      final db = await _db.database;
      
      // Get actual local table columns
      final tableInfo = await db.rawQuery('PRAGMA table_info(transactions)');
      final columnNames = tableInfo.map((col) => col['name'] as String).toSet();
      final hasSyncStatus = columnNames.contains('sync_status');
      
      debugPrint('[TRANSACTION_REPO] 💾 Saving transaction locally: ${transaction.id}');
      debugPrint('[TRANSACTION_REPO]    Payment method: $paymentMethod, Amount: £${amountPaid.toStringAsFixed(2)}');
      
      // Build transaction data map
      final localTransaction = <String, dynamic>{
        'id': transaction.id,
      };
      
      if (columnNames.contains('outlet_id')) localTransaction['outlet_id'] = transaction.outletId;
      if (columnNames.contains('order_id')) localTransaction['order_id'] = transaction.orderId;
      if (columnNames.contains('staff_id')) localTransaction['staff_id'] = transaction.staffId;
      if (columnNames.contains('payment_method')) localTransaction['payment_method'] = transaction.paymentMethod;
      if (columnNames.contains('payment_status')) localTransaction['payment_status'] = transaction.paymentStatus;
      if (columnNames.contains('amount_paid')) localTransaction['amount_paid'] = transaction.amountPaid;
      if (columnNames.contains('change_given')) localTransaction['change_given'] = transaction.changeGiven;
      if (columnNames.contains('subtotal')) localTransaction['subtotal'] = transaction.subtotal;
      if (columnNames.contains('tax_amount')) localTransaction['tax_amount'] = transaction.taxAmount;
      if (columnNames.contains('service_charge')) localTransaction['service_charge'] = transaction.serviceCharge;
      if (columnNames.contains('discount_amount')) localTransaction['discount_amount'] = transaction.discountAmount;
      if (columnNames.contains('voucher_amount')) localTransaction['voucher_amount'] = transaction.voucherAmount;
      if (columnNames.contains('loyalty_redeemed')) localTransaction['loyalty_redeemed'] = transaction.loyaltyRedeemed;
      if (columnNames.contains('total_due')) localTransaction['total_due'] = transaction.totalDue;
      if (columnNames.contains('till_id')) localTransaction['till_id'] = transaction.tillId;
      if (columnNames.contains('payment_ref')) localTransaction['payment_ref'] = transaction.paymentRef;
      if (columnNames.contains('meta') && transaction.meta != null) {
        localTransaction['meta'] = jsonEncode(transaction.meta);
      }
      if (columnNames.contains('created_at')) localTransaction['created_at'] = transaction.createdAt.millisecondsSinceEpoch;
      
      // Mark as pending for local-origin transactions
      if (hasSyncStatus) {
        localTransaction['sync_status'] = 'pending';
        localTransaction['sync_error'] = null;
        localTransaction['last_sync_attempt_at'] = null;
        localTransaction['sync_attempt_count'] = 0;
        debugPrint('[TRANSACTION_REPO]    Marked as sync_status=pending (local-origin)');
      }
      
      // Safe upsert
      final updateCount = await db.update(
        'transactions',
        localTransaction,
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
      
      if (updateCount == 0) {
        await db.insert('transactions', localTransaction);
        debugPrint('[TRANSACTION_REPO]    ✅ Inserted transaction locally');
      } else {
        debugPrint('[TRANSACTION_REPO]    ✅ Updated transaction locally');
      }
      
      // Queue for sync
      await _queueTransaction(transaction);
      
      // Queue adjustments if needed
      await _queueAdjustmentIfNeeded(order, 'discount', order.discountAmount);
      await _queueAdjustmentIfNeeded(order, 'voucher', order.voucherAmount);
      await _queueAdjustmentIfNeeded(order, 'loyalty', order.loyaltyRedeemed);
      
      return transaction;
    } catch (e, stackTrace) {
      debugPrint('[TRANSACTION_REPO] ❌ Failed to save transaction locally: $e');
      debugPrint('Stack: $stackTrace');
      return null;
    }
  }

  Future<void> _queueTransaction(EposTransaction transaction) async {
    await _db.addToOutbox(
      operation: 'insert',
      entityType: 'transaction',
      entityId: transaction.id,
      payload: transaction.toJson(),
    );
    debugPrint('📥 Queued transaction ${transaction.id} (${transaction.paymentMethod}) for sync');
  }
}