import 'package:flowtill/models/order_item.dart';

/// Represents a split portion of a bill for payment
class SplitBill {
  final List<OrderItem> items;
  final double subtotal;
  final double taxAmount;
  final double discountShare;
  final double promotionDiscountShare;
  final double serviceChargeShare;
  final double totalDue;
  final String splitType; // 'items' or 'even'
  final int? splitIndex; // For even splits (1 of N)
  final int? totalSplits; // Total number of splits for even splits

  SplitBill({
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    this.discountShare = 0.0,
    this.promotionDiscountShare = 0.0,
    this.serviceChargeShare = 0.0,
    required this.totalDue,
    required this.splitType,
    this.splitIndex,
    this.totalSplits,
  });

  Map<String, dynamic> toJson() => {
    'items': items.map((i) => i.toJson()).toList(),
    'subtotal': subtotal,
    'tax_amount': taxAmount,
    'discount_share': discountShare,
    'promotion_discount_share': promotionDiscountShare,
    'service_charge_share': serviceChargeShare,
    'total_due': totalDue,
    'split_type': splitType,
    'split_index': splitIndex,
    'total_splits': totalSplits,
  };

  SplitBill copyWith({
    List<OrderItem>? items,
    double? subtotal,
    double? taxAmount,
    double? discountShare,
    double? promotionDiscountShare,
    double? serviceChargeShare,
    double? totalDue,
    String? splitType,
    int? splitIndex,
    int? totalSplits,
  }) => SplitBill(
    items: items ?? this.items,
    subtotal: subtotal ?? this.subtotal,
    taxAmount: taxAmount ?? this.taxAmount,
    discountShare: discountShare ?? this.discountShare,
    promotionDiscountShare: promotionDiscountShare ?? this.promotionDiscountShare,
    serviceChargeShare: serviceChargeShare ?? this.serviceChargeShare,
    totalDue: totalDue ?? this.totalDue,
    splitType: splitType ?? this.splitType,
    splitIndex: splitIndex ?? this.splitIndex,
    totalSplits: totalSplits ?? this.totalSplits,
  );
}
