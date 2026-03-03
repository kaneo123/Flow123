class EposTransaction {
  final String id;
  final String outletId;
  final String orderId;
  final String? staffId;
  final String paymentMethod;
  final String paymentStatus;
  final double amountPaid;
  final double changeGiven;
  final double subtotal;
  final double taxAmount;
  final double serviceCharge;
  final double discountAmount;
  final double voucherAmount;
  final double loyaltyRedeemed;
  final double totalDue;
  final String? tillId;
  final String? paymentRef;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;

  EposTransaction({
    required this.id,
    required this.outletId,
    required this.orderId,
    this.staffId,
    required this.paymentMethod,
    this.paymentStatus = 'completed',
    required this.amountPaid,
    this.changeGiven = 0.0,
    required this.subtotal,
    required this.taxAmount,
    this.serviceCharge = 0.0,
    this.discountAmount = 0.0,
    this.voucherAmount = 0.0,
    this.loyaltyRedeemed = 0.0,
    required this.totalDue,
    this.tillId,
    this.paymentRef,
    this.meta,
    required this.createdAt,
  });

  EposTransaction copyWith({
    String? id,
    String? outletId,
    String? orderId,
    String? staffId,
    String? paymentMethod,
    String? paymentStatus,
    double? amountPaid,
    double? changeGiven,
    double? subtotal,
    double? taxAmount,
    double? serviceCharge,
    double? discountAmount,
    double? voucherAmount,
    double? loyaltyRedeemed,
    double? totalDue,
    String? tillId,
    String? paymentRef,
    Map<String, dynamic>? meta,
    DateTime? createdAt,
  }) => EposTransaction(
    id: id ?? this.id,
    outletId: outletId ?? this.outletId,
    orderId: orderId ?? this.orderId,
    staffId: staffId ?? this.staffId,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    amountPaid: amountPaid ?? this.amountPaid,
    changeGiven: changeGiven ?? this.changeGiven,
    subtotal: subtotal ?? this.subtotal,
    taxAmount: taxAmount ?? this.taxAmount,
    serviceCharge: serviceCharge ?? this.serviceCharge,
    discountAmount: discountAmount ?? this.discountAmount,
    voucherAmount: voucherAmount ?? this.voucherAmount,
    loyaltyRedeemed: loyaltyRedeemed ?? this.loyaltyRedeemed,
    totalDue: totalDue ?? this.totalDue,
    tillId: tillId ?? this.tillId,
    paymentRef: paymentRef ?? this.paymentRef,
    meta: meta ?? this.meta,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'order_id': orderId,
    'staff_id': staffId,
    'payment_method': paymentMethod,
    'payment_status': paymentStatus,
    'amount_paid': amountPaid,
    'change_given': changeGiven,
    'subtotal': subtotal,
    'tax_amount': taxAmount,
    'service_charge': serviceCharge,
    'discount_amount': discountAmount,
    'voucher_amount': voucherAmount,
    'loyalty_redeemed': loyaltyRedeemed,
    'total_due': totalDue,
    'till_id': tillId,
    'payment_ref': paymentRef,
    'meta': meta,
    'created_at': createdAt.toIso8601String(),
  };

  factory EposTransaction.fromJson(Map<String, dynamic> json) => EposTransaction(
    id: json['id'] as String,
    outletId: json['outlet_id'] as String,
    orderId: json['order_id'] as String,
    staffId: json['staff_id'] as String?,
    paymentMethod: json['payment_method'] as String,
    paymentStatus: json['payment_status'] as String? ?? 'completed',
    amountPaid: (json['amount_paid'] as num).toDouble(),
    changeGiven: (json['change_given'] as num?)?.toDouble() ?? 0.0,
    subtotal: (json['subtotal'] as num).toDouble(),
    taxAmount: (json['tax_amount'] as num).toDouble(),
    serviceCharge: (json['service_charge'] as num?)?.toDouble() ?? 0.0,
    discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
    voucherAmount: (json['voucher_amount'] as num?)?.toDouble() ?? 0.0,
    loyaltyRedeemed: (json['loyalty_redeemed'] as num?)?.toDouble() ?? 0.0,
    totalDue: (json['total_due'] as num).toDouble(),
    tillId: json['till_id'] as String?,
    paymentRef: json['payment_ref'] as String?,
    meta: json['meta'] as Map<String, dynamic>?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
