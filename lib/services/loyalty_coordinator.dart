import 'package:flutter/foundation.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/models/order.dart';
import 'package:flowtill/services/loyalty_service.dart';
import 'package:flowtill/services/local_storage_service.dart';

/// Coordinator for loyalty operations - orchestrates calls to the edge function
/// All business logic lives in the edge function; this just manages client-side state
class LoyaltyCoordinator {
  LoyaltyCoordinator._();
  static final instance = LoyaltyCoordinator._();
  final AppDatabase _db = AppDatabase.instance;
  final LocalStorageService _localStorage = LocalStorageService();

  /// Default points per pound (fallback if not configured)
  static const double _defaultPointsPerPound = 1.0;

  /// Handle complete payment flow: award points + record reward redemption
  /// 
  /// [pointsPerPound] - Points to award per pound spent (defaults to 1.0)
  /// [doublePointsEnabled] - Whether to double the points (defaults to false)
  Future<bool> handlePaymentCompletion(
    Order order, {
    double pointsPerPound = _defaultPointsPerPound,
    bool doublePointsEnabled = false,
  }) async {
    if (order.loyaltyCustomerId == null) {
      debugPrint('⚠️ LoyaltyCoordinator: No loyaltyCustomerId attached, skipping loyalty sync');
      return false;
    }

    // Validate required fields
    if (order.loyaltyCustomerId == null || order.loyaltyCustomerId!.isEmpty) {
      debugPrint('❌ LoyaltyCoordinator: Missing loyaltyCustomerId');
      return false;
    }
    
    if (order.loyaltyRestaurantId == null || order.loyaltyRestaurantId!.isEmpty) {
      debugPrint('❌ LoyaltyCoordinator: Missing loyaltyRestaurantId');
      return false;
    }

    if (order.totalDue <= 0) {
      debugPrint('⚠️ LoyaltyCoordinator: No points to award (totalDue is zero or negative)');
      return false;
    }

    // Idempotency check: prevent double-award
    final storageKey = 'points_awarded_for_order_${order.id}';
    final alreadyAwarded = _localStorage.tryGetBool(storageKey) ?? false;
    
    if (!_localStorage.isInitialized) {
      debugPrint('⚠️ LoyaltyCoordinator: LocalStorage not ready yet, skipping idempotency check');
    }
    
    if (alreadyAwarded) {
      debugPrint('🛡️ LoyaltyCoordinator: Points already awarded for order ${order.id}; skipping');
      return false;
    }

    debugPrint('💰 LoyaltyCoordinator: Processing payment completion for order ${order.id}');
    debugPrint('   userId: ${order.loyaltyCustomerId}');
    debugPrint('   restaurantId: ${order.loyaltyRestaurantId}');
    debugPrint('   billTotal: £${order.totalDue.toStringAsFixed(2)}');
    debugPrint('   reward: ${order.loyaltyRewardId != null ? "${order.loyaltyRewardType}/${order.loyaltyRewardId}" : "none"}');

    // Prepare reward data if applicable
    Map<String, dynamic>? reward;
    if (order.loyaltyRewardId != null && order.loyaltyRewardType != null) {
      reward = {
        'id': order.loyaltyRewardId,
        'type': order.loyaltyRewardType,
        'name': order.loyaltyRewardName ?? 'Reward',
      };
    }

    try {
      // Apply double points multiplier if enabled
      final effectivePointsPerPound = doublePointsEnabled 
        ? pointsPerPound * 2 
        : pointsPerPound;
      
      debugPrint('   pointsPerPound: $pointsPerPound (${doublePointsEnabled ? "2x enabled" : "normal"})');
      
      // Call the consolidated edge function that handles everything
      final result = await LoyaltyService.completePayment(
        orderId: order.id,
        userId: order.loyaltyCustomerId!,
        restaurantId: order.loyaltyRestaurantId!,
        totalAmount: order.totalDue,
        pointsPerPound: effectivePointsPerPound,
        reward: reward,
      );

      debugPrint('📥 LoyaltyCoordinator: Edge function result: $result');
      debugPrint('   pointsAwarded: ${result['pointsAwarded']}');
      debugPrint('   rewardRecorded: ${result['rewardRecorded']}');
      debugPrint('   errors: ${result['errors']}');

      final pointsAwarded = result['pointsAwarded'] == true;
      final rewardRecorded = reward != null ? (result['rewardRecorded'] == true) : true;
      final errors = (result['errors'] as List?) ?? [];

      if (pointsAwarded && rewardRecorded) {
        // Mark as awarded to prevent double-awarding
        final marked = await _localStorage.trySetBool(storageKey, true);
        if (marked) {
          debugPrint('✅ LoyaltyCoordinator: Payment completed successfully and marked');
        } else {
          debugPrint('⚠️ LoyaltyCoordinator: Payment completed but could not mark as awarded (LocalStorage not ready)');
        }
        return true;
      } else if (errors.isNotEmpty) {
        debugPrint('⚠️ LoyaltyCoordinator: Payment partially completed with errors');
        debugPrint('   Errors: $errors');
        // Don't mark as complete if there were errors - allow retry
        return false;
      } else {
        debugPrint('⚠️ LoyaltyCoordinator: Payment completion returned unexpected state');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ LoyaltyCoordinator: Failed to complete payment: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Queue for retry if the call failed entirely (preserve settings)
      final effectivePointsPerPound = doublePointsEnabled 
        ? pointsPerPound * 2 
        : pointsPerPound;
      await _queuePaymentForRetry(order, reward, pointsPerPound: effectivePointsPerPound);
      
      // Don't rethrow - we've queued it for retry
      return false;
    }
  }

  /// Queue failed payment for retry via outbox
  Future<void> _queuePaymentForRetry(
    Order order, 
    Map<String, dynamic>? reward, {
    double pointsPerPound = _defaultPointsPerPound,
  }) async {
    final idempotencyKey = order.id;

    debugPrint('📦 LoyaltyCoordinator: Queueing payment for retry');

    // Queue points award
    final pointsToAward = (order.totalDue * pointsPerPound).floor();
    
    final pointsPayload = {
      'idempotencyKey': idempotencyKey,
      'action': 'points_award',
      'body': {
        'userId': order.loyaltyCustomerId,
        'type': 'earn',
        'restaurantId': order.loyaltyRestaurantId,
        'points': pointsToAward,
        'orderDetails': 'FlowTill POS | Order #${order.id.substring(0, 8)} | Bill £${order.totalDue.toStringAsFixed(2)}',
      },
    };

    final pointsExists = await _db.outboxItemExists(entityType: 'loyalty', entityId: idempotencyKey);
    if (!pointsExists) {
      await _db.addToOutbox(
        operation: 'forward',
        entityType: 'loyalty',
        entityId: idempotencyKey,
        payload: pointsPayload,
      );
      debugPrint('✅ Points award queued for retry');
    }

    // Queue reward recording if applicable
    if (reward != null) {
      if (reward['type'] == 'offer') {
        final offerPayload = {
          'idempotencyKey': '${idempotencyKey}_offer',
          'action': 'offer_history',
          'body': {
            'userId': order.loyaltyCustomerId,
            'offerId': reward['id'],
            'status': 'redeemed',
            'orderId': order.id,
          },
        };
        
        final offerExists = await _db.outboxItemExists(entityType: 'loyalty', entityId: '${idempotencyKey}_offer');
        if (!offerExists) {
          await _db.addToOutbox(
            operation: 'forward',
            entityType: 'loyalty',
            entityId: '${idempotencyKey}_offer',
            payload: offerPayload,
          );
          debugPrint('✅ Offer redemption queued for retry');
        }
      } else if (reward['type'] == 'coupon') {
        final couponPayload = {
          'idempotencyKey': '${idempotencyKey}_coupon',
          'action': 'coupon_history',
          'body': {
            'userId': order.loyaltyCustomerId,
            'couponId': reward['id'],
            'status': 'redeemed',
            'orderId': order.id,
          },
        };

        final couponExists = await _db.outboxItemExists(entityType: 'loyalty', entityId: '${idempotencyKey}_coupon');
        if (!couponExists) {
          await _db.addToOutbox(
            operation: 'forward',
            entityType: 'loyalty',
            entityId: '${idempotencyKey}_coupon',
            payload: couponPayload,
          );
        }

        final scratchPayload = {
          'idempotencyKey': '${idempotencyKey}_scratch',
          'action': 'coupon_scratch',
          'id': reward['id'],
          'body': {'status': 'redeemed'},
        };

        final scratchExists = await _db.outboxItemExists(entityType: 'loyalty', entityId: '${idempotencyKey}_scratch');
        if (!scratchExists) {
          await _db.addToOutbox(
            operation: 'forward',
            entityType: 'loyalty',
            entityId: '${idempotencyKey}_scratch',
            payload: scratchPayload,
          );
        }
        
        debugPrint('✅ Coupon redemption and scratch queued for retry');
      }
    }
  }
}
