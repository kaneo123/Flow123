class StockMovement {
  final String id;
  final String outletId;
  final String inventoryItemId;
  final double changeQty;
  final String reason;
  final String? note;
  final String? createdByStaffId;
  final DateTime createdAt;

  StockMovement({
    required this.id,
    required this.outletId,
    required this.inventoryItemId,
    required this.changeQty,
    required this.reason,
    this.note,
    this.createdByStaffId,
    required this.createdAt,
  });

  StockMovement copyWith({
    String? id,
    String? outletId,
    String? inventoryItemId,
    double? changeQty,
    String? reason,
    String? note,
    String? createdByStaffId,
    DateTime? createdAt,
  }) => StockMovement(
    id: id ?? this.id,
    outletId: outletId ?? this.outletId,
    inventoryItemId: inventoryItemId ?? this.inventoryItemId,
    changeQty: changeQty ?? this.changeQty,
    reason: reason ?? this.reason,
    note: note ?? this.note,
    createdByStaffId: createdByStaffId ?? this.createdByStaffId,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'inventory_item_id': inventoryItemId,
    'change_qty': changeQty,
    'reason': reason,
    if (note != null) 'note': note,
    if (createdByStaffId != null) 'created_by_staff_id': createdByStaffId,
    'created_at': createdAt.toIso8601String(),
  };

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    double parseNumeric(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    
    return StockMovement(
      id: json['id']?.toString() ?? '',
      outletId: json['outlet_id']?.toString() ?? '',
      inventoryItemId: json['inventory_item_id']?.toString() ?? '',
      changeQty: parseNumeric(json['change_qty']),
      reason: json['reason']?.toString() ?? '',
      note: json['note']?.toString(),
      createdByStaffId: json['created_by_staff_id']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }
}
