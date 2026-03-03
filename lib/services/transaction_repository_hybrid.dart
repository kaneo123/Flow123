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