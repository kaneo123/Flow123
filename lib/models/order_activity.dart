class OrderActivity {
  final String id;
  final String outletId;
  final String orderId;
  final String? tableId;
  final String? staffId;
  final String actionType;
  final String actionDescription;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;

  OrderActivity({
    required this.id,
    required this.outletId,
    required this.orderId,
    this.tableId,
    this.staffId,
    required this.actionType,
    required this.actionDescription,
    this.meta,
    required this.createdAt,
  });

  factory OrderActivity.fromJson(Map<String, dynamic> json) {
    return OrderActivity(
      id: json['id'] as String? ?? '',
      outletId: json['outlet_id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      tableId: json['table_id'] as String?,
      staffId: json['staff_id'] as String?,
      actionType: json['action_type'] as String? ?? '',
      actionDescription: json['action_description'] as String? ?? '',
      meta: json['meta'] != null ? Map<String, dynamic>.from(json['meta'] as Map) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'order_id': orderId,
    'table_id': tableId,
    'staff_id': staffId,
    'action_type': actionType,
    'action_description': actionDescription,
    'meta': meta,
    'created_at': createdAt.toIso8601String(),
  };
}
