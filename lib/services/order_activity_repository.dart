import 'package:flutter/foundation.dart';
import 'package:flowtill/models/order_activity.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:uuid/uuid.dart';

/// Repository for order activity logging
/// 
/// Platform-aware behavior:
/// - WEB: Direct Supabase insert into order_activity_log
/// - DEVICE: Deferred/skipped to avoid FK violations with local-first orders
///   Activity logs on device can be recreated from order history if needed
class OrderActivityRepository {
  final _uuid = const Uuid();

  /// Log an action to order_activity_log
  /// 
  /// Platform-aware behavior:
  /// - WEB: Inserts directly to Supabase order_activity_log
  /// - DEVICE: Defers logging to avoid FK violations (parent order may only exist locally)
  /// 
  /// DEVICE RATIONALE:
  /// Activity logs are informational/audit trail only. On device builds:
  /// - Parent order exists locally first, not in Supabase
  /// - Direct insert would cause FK violation
  /// - Deferring until order syncs adds complexity
  /// - Activity history can be reconstructed from order status/timestamps if needed
  Future<void> logAction({
    required String outletId,
    required String orderId,
    String? tableId,
    String? staffId,
    required String actionType,
    required String actionDescription,
    Map<String, dynamic>? meta,
  }) async {
    if (kIsWeb) {
      // WEB: Direct Supabase insert
      return _logActionWeb(
        outletId: outletId,
        orderId: orderId,
        tableId: tableId,
        staffId: staffId,
        actionType: actionType,
        actionDescription: actionDescription,
        meta: meta,
      );
    } else {
      // DEVICE: Defer/skip activity logging to avoid FK violations
      debugPrint('[ACTIVITY_LOG] Device: Deferring activity log (local-first order)');
      debugPrint('[ACTIVITY_LOG]    Order: $orderId');
      debugPrint('[ACTIVITY_LOG]    Action: $actionType');
      debugPrint('[ACTIVITY_LOG]    Description: $actionDescription');
      debugPrint('[ACTIVITY_LOG]    Reason: Parent order may only exist locally, FK violation risk');
      debugPrint('[ACTIVITY_LOG]    Note: Activity can be reconstructed from order timestamps');
      
      // Silently skip - activity logs are informational, not critical for order flow
      return;
    }
  }
  
  /// WEB ONLY: Insert activity log to Supabase
  Future<void> _logActionWeb({
    required String outletId,
    required String orderId,
    String? tableId,
    String? staffId,
    required String actionType,
    required String actionDescription,
    Map<String, dynamic>? meta,
  }) async {
    debugPrint('[ACTIVITY_LOG] Web: Logging action to Supabase');
    debugPrint('[ACTIVITY_LOG]    Order: $orderId');
    debugPrint('[ACTIVITY_LOG]    Action: $actionType');
    debugPrint('[ACTIVITY_LOG]    Description: $actionDescription');

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
        debugPrint('[ACTIVITY_LOG] ✅ Activity logged successfully');
      } else {
        debugPrint('[ACTIVITY_LOG] ❌ Failed to log activity: ${result.error}');
      }
    } catch (e, stackTrace) {
      debugPrint('[ACTIVITY_LOG] ❌ Error logging activity: $e');
      debugPrint('Stack: $stackTrace');
    }
  }

  /// Get history for a specific order (sorted by created_at ascending = oldest first)
  /// Only functional on web builds (device builds don't log activities to avoid FK violations)
  Future<List<OrderActivity>> getHistoryForOrder(String orderId) async {
    if (!kIsWeb) {
      debugPrint('[ACTIVITY_LOG] Device: Skipping history fetch (not logged on device builds)');
      return [];
    }
    
    debugPrint('[ACTIVITY_LOG] Web: Fetching history for order $orderId');

    try {
      final response = await SupabaseService.from('order_activity_log')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: true) as List<dynamic>;

      final activities = response
          .map((json) => OrderActivity.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('[ACTIVITY_LOG] ✅ Fetched ${activities.length} history entries');
      return activities;
    } catch (e, stackTrace) {
      debugPrint('[ACTIVITY_LOG] ❌ Error fetching order history: $e');
      debugPrint('Stack: $stackTrace');
      return [];
    }
  }

  /// Clear all history for a specific order (called when order is completed)
  /// Only functional on web builds
  Future<void> clearHistoryForOrder(String orderId) async {
    if (!kIsWeb) {
      debugPrint('[ACTIVITY_LOG] Device: Skipping history clear (not logged on device builds)');
      return;
    }
    
    debugPrint('[ACTIVITY_LOG] Web: Clearing history for order $orderId');

    try {
      final result = await SupabaseService.delete(
        'order_activity_log',
        filters: {'order_id': orderId},
      );

      if (result.isSuccess) {
        debugPrint('[ACTIVITY_LOG] ✅ History cleared successfully');
      } else {
        debugPrint('[ACTIVITY_LOG] ❌ Failed to clear history: ${result.error}');
      }
    } catch (e, stackTrace) {
      debugPrint('[ACTIVITY_LOG] ❌ Error clearing history: $e');
      debugPrint('Stack: $stackTrace');
    }
  }
}
