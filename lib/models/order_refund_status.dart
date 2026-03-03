class OrderRefundStatus {
  final bool hasRefund;
  final bool isFullyRefunded;
  final double totalRefunded;

  OrderRefundStatus({
    required this.hasRefund,
    required this.isFullyRefunded,
    required this.totalRefunded,
  });

  factory OrderRefundStatus.empty() => OrderRefundStatus(
    hasRefund: false,
    isFullyRefunded: false,
    totalRefunded: 0.0,
  );

  factory OrderRefundStatus.fromRefundAmount({
    required double refundedAmount,
    required double orderTotal,
  }) => OrderRefundStatus(
    hasRefund: refundedAmount > 0,
    isFullyRefunded: refundedAmount >= orderTotal,
    totalRefunded: refundedAmount,
  );
}
