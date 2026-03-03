class RefundTransaction {
  final String id;
  final String orderId;
  final String outletId;
  final String? staffId;
  final String? staffName;
  final double amount;
  final String? reason;
  final bool restoreInventory;
  final DateTime createdAt;

  RefundTransaction({
    required this.id,
    required this.orderId,
    required this.outletId,
    this.staffId,
    this.staffName,
    required this.amount,
    this.reason,
    this.restoreInventory = false,
    required this.createdAt,
  });

  factory RefundTransaction.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>?;
    return RefundTransaction(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      outletId: json['outlet_id'] as String,
      staffId: json['staff_id'] as String?,
      staffName: json['staff_name'] as String?,
      amount: (json['amount_paid'] as num).toDouble().abs(), // Store as positive for display
      reason: meta?['reason'] as String?,
      restoreInventory: meta?['restore_inventory'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
