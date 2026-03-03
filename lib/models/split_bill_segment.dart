import 'package:flowtill/models/order_item.dart';

/// Represents a single segment of a split bill
class SplitBillSegment {
  final String id;
  final String name;
  final double amount;
  final double subtotal;
  final double taxAmount;
  final double discountShare;
  final double promotionDiscountShare;
  final double serviceChargeShare;
  final String? paymentMethod; // null = unpaid, 'card'/'cash' = paid
  final DateTime? paidAt;
  final List<OrderItem>? items; // For item-based splits, null for even splits
  final double? amountTendered; // For cash payments
  final double? changeDue; // For cash payments

  SplitBillSegment({
    required this.id,
    required this.name,
    required this.amount,
    required this.subtotal,
    required this.taxAmount,
    this.discountShare = 0.0,
    this.promotionDiscountShare = 0.0,
    this.serviceChargeShare = 0.0,
    this.paymentMethod,
    this.paidAt,
    this.items,
    this.amountTendered,
    this.changeDue,
  });

  bool get isPaid => paymentMethod != null;

  SplitBillSegment copyWith({
    String? id,
    String? name,
    double? amount,
    double? subtotal,
    double? taxAmount,
    double? discountShare,
    double? promotionDiscountShare,
    double? serviceChargeShare,
    String? paymentMethod,
    DateTime? paidAt,
    List<OrderItem>? items,
    double? amountTendered,
    double? changeDue,
  }) =>
      SplitBillSegment(
        id: id ?? this.id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        subtotal: subtotal ?? this.subtotal,
        taxAmount: taxAmount ?? this.taxAmount,
        discountShare: discountShare ?? this.discountShare,
        promotionDiscountShare: promotionDiscountShare ?? this.promotionDiscountShare,
        serviceChargeShare: serviceChargeShare ?? this.serviceChargeShare,
        paymentMethod: paymentMethod,
        paidAt: paidAt,
        items: items ?? this.items,
        amountTendered: amountTendered,
        changeDue: changeDue,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'subtotal': subtotal,
        'tax_amount': taxAmount,
        'discount_share': discountShare,
        'promotion_discount_share': promotionDiscountShare,
        'service_charge_share': serviceChargeShare,
        'payment_method': paymentMethod,
        'paid_at': paidAt?.toIso8601String(),
        'items': items?.map((i) => i.toJson()).toList(),
        'amount_tendered': amountTendered,
        'change_due': changeDue,
      };
}
