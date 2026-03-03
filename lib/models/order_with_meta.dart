import 'package:flowtill/models/epos_order.dart';
import 'package:flowtill/models/order_refund_status.dart';

class OrderWithMeta {
  final EposOrder order;
  final String? staffName;
  final OrderRefundStatus refundStatus;

  OrderWithMeta({
    required this.order,
    this.staffName,
    required this.refundStatus,
  });

  /// Get a display label for the order type (Table, Tab, Customer, or Quick Sale)
  String get orderLabel {
    if (order.tableNumber != null) return 'Table ${order.tableNumber}';
    if (order.tabName != null && order.tabName!.isNotEmpty) return order.tabName!;
    if (order.customerName != null && order.customerName!.isNotEmpty) return order.customerName!;
    return 'Quick sale';
  }

  /// Get a short order ID (first 8 characters)
  String get shortId => order.id.substring(0, 8);

  /// Get status badge label
  String get statusLabel {
    if (refundStatus.isFullyRefunded) return 'Refunded';
    if (refundStatus.hasRefund) return 'Partially Refunded';
    return order.status == 'completed' ? 'Completed' : order.status.toUpperCase();
  }
}
