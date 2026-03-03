import 'package:flutter/foundation.dart';
import 'package:flowtill/models/order_activity.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:uuid/uuid.dart';

class OrderActivityRepository {
  final _uuid = const Uuid();

  /// Log an action to order_activity_log
  Future<void> logAction({
    required String outletId,
    required String orderId,
    String? tableId,
    String? staffId,
    required String actionType,
    required String actionDescription,
    Map<String, dynamic>? meta,
  }) async {
    debugPrint('📝 OrderActivityRepository: Logging action');
    debugPrint('   Order: $orderId');
    debugPrint('   Action: $actionType');
    debugPrint('   Description: $actionDescription');

    try {
      final activity = OrderActivity(
        id: _uuid.v4(),
        outletId: outletId,
        orderId: orderId,
        tableId: tableId,
        staffId: staffId,
        actionType: actionType,
        actionDescription: actionDescription,
        meta: meta,
        createdAt: DateTime.now(),
      );

      final result = await SupabaseService.insert('order_activity_log', activity.toJson());

      if (result.isSuccess) {
        debugPrint('✅ Activity logged successfully');
      } else {
        debugPrint('❌ Failed to log activity: ${result.error}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error logging activity: $e');
      debugPrint('Stack: $stackTrace');
    }
  }

  /// Get history for a specific order (sorted by created_at ascending = oldest first)
  Future<List<OrderActivity>> getHistoryForOrder(String orderId) async {
    debugPrint('📥 OrderActivityRepository: Fetching history for order $orderId');

    try {
      final response = await SupabaseService.from('order_activity_log')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: true) as List<dynamic>;

      final activities = response
          .map((json) => OrderActivity.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Fetched ${activities.length} history entries');
      return activities;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching order history: $e');
      debugPrint('Stack: $stackTrace');
      return [];
    }
  }

  /// Clear all history for a specific order (called when order is completed)
  Future<void> clearHistoryForOrder(String orderId) async {
    debugPrint('🗑️ OrderActivityRepository: Clearing history for order $orderId');

    try {
      final result = await SupabaseService.delete(
        'order_activity_log',
        filters: {'order_id': orderId},
      );

      if (result.isSuccess) {
        debugPrint('✅ History cleared successfully');
      } else {
        debugPrint('❌ Failed to clear history: ${result.error}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error clearing history: $e');
      debugPrint('Stack: $stackTrace');
    }
  }
}
