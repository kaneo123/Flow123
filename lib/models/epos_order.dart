class EposOrder {
  final String id;
  final String outletId;
  final String? staffId;
  final String orderType;
  final String status;
  final String? tableId;
  final String? tableNumber;
  final String? tabName;
  final String? customerName;
  final int? covers;
  final double subtotal;
  final double taxAmount;
  final double serviceCharge;
  final double discountAmount;
  final double voucherAmount;
  final double loyaltyRedeemed;
  final double totalDue;
  final double totalPaid;
  final double changeDue;
  final String? paymentMethod;
  final String? notes;
  final DateTime openedAt;
  final DateTime? parkedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  EposOrder({
    required this.id,
    required this.outletId,
    this.staffId,
    this.orderType = 'quick_service',
    this.status = 'open',
    this.tableId,
    this.tableNumber,
    this.tabName,
    this.customerName,
    this.covers,
    this.subtotal = 0.0,
    this.taxAmount = 0.0,
    this.serviceCharge = 0.0,
    this.discountAmount = 0.0,
    this.voucherAmount = 0.0,
    this.loyaltyRedeemed = 0.0,
    this.totalDue = 0.0,
    this.totalPaid = 0.0,
    this.changeDue = 0.0,
    this.paymentMethod,
    this.notes,
    required this.openedAt,
    this.parkedAt,
    this.completedAt,
    required this.updatedAt,
  });

  EposOrder copyWith({
    String? id,
    String? outletId,
    String? staffId,
    String? orderType,
    String? status,
    String? tableId,
    String? tableNumber,
    String? tabName,
    String? customerName,
    int? covers,
    double? subtotal,
    double? taxAmount,
    double? serviceCharge,
    double? discountAmount,
    double? voucherAmount,
    double? loyaltyRedeemed,
    double? totalDue,
    double? totalPaid,
    double? changeDue,
    String? paymentMethod,
    String? notes,
    DateTime? openedAt,
    DateTime? parkedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) => EposOrder(
    id: id ?? this.id,
    outletId: outletId ?? this.outletId,
    staffId: staffId ?? this.staffId,
    orderType: orderType ?? this.orderType,
    status: status ?? this.status,
    tableId: tableId ?? this.tableId,
    tableNumber: tableNumber ?? this.tableNumber,
    tabName: tabName ?? this.tabName,
    customerName: customerName ?? this.customerName,
    covers: covers ?? this.covers,
    subtotal: subtotal ?? this.subtotal,
    taxAmount: taxAmount ?? this.taxAmount,
    serviceCharge: serviceCharge ?? this.serviceCharge,
    discountAmount: discountAmount ?? this.discountAmount,
    voucherAmount: voucherAmount ?? this.voucherAmount,
    loyaltyRedeemed: loyaltyRedeemed ?? this.loyaltyRedeemed,
    totalDue: totalDue ?? this.totalDue,
    totalPaid: totalPaid ?? this.totalPaid,
    changeDue: changeDue ?? this.changeDue,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    notes: notes ?? this.notes,
    openedAt: openedAt ?? this.openedAt,
    parkedAt: parkedAt ?? this.parkedAt,
    completedAt: completedAt ?? this.completedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'staff_id': staffId,
    'order_type': orderType,
    'status': status,
    'table_id': tableId,
    'table_number': tableNumber,
    'tab_name': tabName,
    'customer_name': customerName,
    'covers': covers,
    'subtotal': subtotal,
    'tax_amount': taxAmount,
    'service_charge': serviceCharge,
    'discount_amount': discountAmount,
    'voucher_amount': voucherAmount,
    'loyalty_redeemed': loyaltyRedeemed,
    'total_due': totalDue,
    'total_paid': totalPaid,
    'change_due': changeDue,
    'payment_method': paymentMethod,
    'notes': notes,
    'opened_at': openedAt.toIso8601String(),
    'parked_at': parkedAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory EposOrder.fromJson(Map<String, dynamic> json) => EposOrder(
    id: json['id'] as String,
    outletId: json['outlet_id'] as String,
    staffId: json['staff_id'] as String?,
    orderType: json['order_type'] as String? ?? 'quick_service',
    status: json['status'] as String? ?? 'open',
    tableId: json['table_id'] as String?,
    tableNumber: json['table_number'] as String?,
    tabName: json['tab_name'] as String?,
    customerName: json['customer_name'] as String?,
    covers: json['covers'] as int?,
    subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
    taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
    serviceCharge: (json['service_charge'] as num?)?.toDouble() ?? 0.0,
    discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
    voucherAmount: (json['voucher_amount'] as num?)?.toDouble() ?? 0.0,
    loyaltyRedeemed: (json['loyalty_redeemed'] as num?)?.toDouble() ?? 0.0,
    totalDue: (json['total_due'] as num?)?.toDouble() ?? 0.0,
    totalPaid: (json['total_paid'] as num?)?.toDouble() ?? 0.0,
    changeDue: (json['change_due'] as num?)?.toDouble() ?? 0.0,
    paymentMethod: json['payment_method'] as String?,
    notes: json['notes'] as String?,
    openedAt: DateTime.parse(json['opened_at'] as String),
    parkedAt: json['parked_at'] != null ? DateTime.parse(json['parked_at'] as String) : null,
    completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
}
