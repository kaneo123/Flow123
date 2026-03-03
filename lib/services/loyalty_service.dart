import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flowtill/models/loyalty_models.dart';
import 'package:flowtill/supabase/supabase_config.dart';

/// Thin client for loyalty operations - all business logic is in the edge function
class LoyaltyService {
  static const _functionName = 'loyalty-proxy';
  static FunctionsClient get _functions => SupabaseConfig.client.functions;

  /// Find customer by identifier (barcode/card number)
  static Future<List<LoyaltyCustomer>> findCustomer(String identifier) async {
    try {
      debugPrint('🔍 LoyaltyService: Finding customer with identifier: $identifier');

      final response = await _functions.invoke(
        _functionName,
        method: HttpMethod.get,
        queryParameters: {'action': 'customer', 'identifier': identifier},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Customer lookup timed out after 10 seconds'),
      );

      debugPrint('📥 LoyaltyService: Response status: ${response.status}');
      debugPrint('📥 LoyaltyService: Response data type: ${response.data.runtimeType}');
      debugPrint('📥 LoyaltyService: Response data: ${response.data}');

      if (response.data == null) {
        debugPrint('⚠️ LoyaltyService: Response data is null');
        return [];
      }

      final responseData = response.data as Map<String, dynamic>;
      debugPrint('📋 LoyaltyService: Response data keys: ${responseData.keys.toList()}');
      
      final customers = (responseData['customers'] as List?) ?? [];
      debugPrint('📋 LoyaltyService: Customers list length: ${customers.length}');
      debugPrint('📋 LoyaltyService: Customers raw: $customers');

      debugPrint('✅ LoyaltyService: Found ${customers.length} customers');

      return customers.map((raw) {
        final map = raw as Map<String, dynamic>;
        return LoyaltyCustomer(
          id: map['id']?.toString() ?? '',
          fullName: map['fullName']?.toString() ?? 'Customer',
          email: map['email']?.toString(),
          phone: map['phone']?.toString(),
          identifier: map['identifier']?.toString(),
          points: (map['points'] as num?)?.toDouble() ?? 0,
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('❌ LoyaltyService: Error finding customer: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Load available rewards (offers + coupons) for a customer at a restaurant
  static Future<({List<LoyaltyReward> offers, List<LoyaltyReward> coupons})> loadRewards({
    required String userId,
    required String restaurantId,
  }) async {
    try {
      debugPrint('🎁 LoyaltyService: Loading rewards for userId=$userId, restaurantId=$restaurantId');

      final response = await _functions.invoke(
        _functionName,
        method: HttpMethod.get,
        queryParameters: {
          'action': 'rewards',
          'userId': userId,
          'restaurantId': restaurantId,
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Rewards lookup timed out after 10 seconds'),
      );

      debugPrint('📥 LoyaltyService: Response status: ${response.status}');

      if ((response.status ?? 200) >= 400) {
        final errorData = response.data as Map<String, dynamic>?;
        final error = errorData?['error']?.toString() ?? 'Unknown error';
        throw Exception('Failed to load rewards: $error');
      }

      if (response.data == null) {
        debugPrint('⚠️ LoyaltyService: Response data is null');
        return (offers: <LoyaltyReward>[], coupons: <LoyaltyReward>[]);
      }

      final responseData = response.data as Map<String, dynamic>;
      final offersRaw = (responseData['offers'] as List?) ?? [];
      final couponsRaw = (responseData['coupons'] as List?) ?? [];

      List<LoyaltyReward> parse(List list, LoyaltyRewardType type) {
        return list.map((raw) {
          final map = raw as Map<String, dynamic>;
          final discountTypeStr = (map['discountType'] ?? 'fixed').toString();
          return LoyaltyReward(
            id: map['id']?.toString() ?? '',
            type: type,
            name: map['name']?.toString() ?? 'Reward',
            description: map['description']?.toString(),
            discountType: discountTypeStr == 'percentage'
                ? LoyaltyDiscountType.percentage
                : LoyaltyDiscountType.fixed,
            discountValue: (map['discountValue'] as num?)?.toDouble() ?? 0,
          );
        }).toList();
      }

      final result = (
        offers: parse(offersRaw, LoyaltyRewardType.offer),
        coupons: parse(couponsRaw, LoyaltyRewardType.coupon),
      );

      debugPrint('✅ LoyaltyService: Loaded ${result.offers.length} offers and ${result.coupons.length} coupons');

      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ LoyaltyService: Error loading rewards: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Complete payment flow: award points + record reward redemption
  /// This calls the consolidated edge function that handles all the logic
  static Future<Map<String, dynamic>> completePayment({
    required String orderId,
    required String userId,
    required String restaurantId,
    required double totalAmount,
    double pointsPerPound = 1.0,
    Map<String, dynamic>? reward, // { id, type, name }
  }) async {
    try {
      debugPrint('💰 LoyaltyService: Completing payment for order $orderId');
      debugPrint('   userId: $userId');
      debugPrint('   restaurantId: $restaurantId');
      debugPrint('   totalAmount: £${totalAmount.toStringAsFixed(2)}');
      debugPrint('   reward: $reward');

      final response = await _functions.invoke(
        _functionName,
        method: HttpMethod.post,
        body: {
          'action': 'complete_payment',
          'orderId': orderId,
          'userId': userId,
          'restaurantId': restaurantId,
          'totalAmount': totalAmount,
          'pointsPerPound': pointsPerPound,
          'reward': reward,
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Payment completion timed out after 15 seconds'),
      );

      debugPrint('📥 LoyaltyService: Response status: ${response.status}');
      debugPrint('📥 LoyaltyService: Response data: ${response.data}');

      final result = response.data as Map<String, dynamic>;

      if (response.status == 200) {
        debugPrint('✅ LoyaltyService: Payment completed successfully');
      } else if (response.status == 207) {
        debugPrint('⚠️ LoyaltyService: Payment partially completed with errors');
        debugPrint('   Errors: ${result['errors']}');
      } else {
        throw Exception('Payment completion failed with status ${response.status}: ${result['error']}');
      }

      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ LoyaltyService: Error completing payment: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Legacy methods for backward compatibility (used by outbox processor)
  
  static Future<Map<String, dynamic>?> awardPoints(Map<String, dynamic> body) async {
    debugPrint('🎯 LoyaltyService: Awarding points (legacy method)');
    
    final response = await _functions.invoke(
      _functionName,
      method: HttpMethod.post,
      queryParameters: {'action': 'points_award'},
      body: body,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Points award timed out after 10 seconds'),
    );

    if (response.status != null && (response.status! >= 200 && response.status! < 300)) {
      debugPrint('✅ LoyaltyService: Points awarded successfully');
      return response.data as Map<String, dynamic>?;
    }

    throw Exception('Points award failed with status ${response.status}');
  }

  static Future<void> recordOffer(Map<String, dynamic> body) async {
    debugPrint('🎯 LoyaltyService: Recording offer history (legacy method)');
    
    await _functions.invoke(
      _functionName,
      method: HttpMethod.post,
      queryParameters: {'action': 'offer_history'},
      body: body,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Offer recording timed out after 10 seconds'),
    );
  }

  static Future<void> recordCoupon(Map<String, dynamic> body) async {
    debugPrint('🎯 LoyaltyService: Recording coupon history (legacy method)');
    
    await _functions.invoke(
      _functionName,
      method: HttpMethod.post,
      queryParameters: {'action': 'coupon_history'},
      body: body,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Coupon recording timed out after 10 seconds'),
    );
  }

  static Future<void> scratchCoupon(String id, Map<String, dynamic> body) async {
    debugPrint('🎯 LoyaltyService: Scratching coupon (legacy method)');
    
    await _functions.invoke(
      _functionName,
      method: HttpMethod.put,
      queryParameters: {'action': 'coupon_scratch', 'id': id},
      body: body,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Coupon scratch timed out after 10 seconds'),
    );
  }

  static Future<void> processOutboxPayload(Map<String, dynamic> payload) async {
    final action = payload['action'] as String?;
    final body = Map<String, dynamic>.from(payload['body'] as Map);

    switch (action) {
      case 'points_award':
        await awardPoints(body);
        break;
      case 'offer_history':
        await recordOffer(body);
        break;
      case 'coupon_history':
        await recordCoupon(body);
        break;
      case 'coupon_scratch':
        final id = payload['id']?.toString() ?? '';
        await scratchCoupon(id, body);
        break;
      default:
        debugPrint('Unknown loyalty action $action');
    }
  }
}
