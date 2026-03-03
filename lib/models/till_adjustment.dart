class TillAdjustment {
  final String id;
  final String outletId;
  final String staffId;
  final DateTime timestamp;
  final int amountPennies;
  final String adjustmentType;
  final String reason;
  final String? notes;

  TillAdjustment({
    required this.id,
    required this.outletId,
    required this.staffId,
    required this.timestamp,
    required this.amountPennies,
    required this.adjustmentType,
    required this.reason,
    this.notes,
  });

  /// Get amount in pounds (for display)
  double get amount => amountPennies / 100.0;

  factory TillAdjustment.fromJson(Map<String, dynamic> json) {
    return TillAdjustment(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      staffId: json['staff_id'] as String,
      timestamp: json['timestamp'] is String
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as int) * 1000),
      amountPennies: json['amount_pennies'] as int,
      adjustmentType: json['adjustment_type'] as String,
      reason: json['reason'] as String,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlet_id': outletId,
      'staff_id': staffId,
      'timestamp': timestamp.toIso8601String(),
      'amount_pennies': amountPennies,
      'adjustment_type': adjustmentType,
      'reason': reason,
      'notes': notes,
    };
  }

  TillAdjustment copyWith({
    String? id,
    String? outletId,
    String? staffId,
    DateTime? timestamp,
    int? amountPennies,
    String? adjustmentType,
    String? reason,
    String? notes,
  }) {
    return TillAdjustment(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      staffId: staffId ?? this.staffId,
      timestamp: timestamp ?? this.timestamp,
      amountPennies: amountPennies ?? this.amountPennies,
      adjustmentType: adjustmentType ?? this.adjustmentType,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
    );
  }
}
