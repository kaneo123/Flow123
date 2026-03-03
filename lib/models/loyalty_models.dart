import 'package:flutter/foundation.dart';

enum LoyaltyRewardType { offer, coupon }

enum LoyaltyDiscountType { percentage, fixed }

class LoyaltyCustomer {
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String? identifier;
  final double points;

  const LoyaltyCustomer({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.identifier,
    this.points = 0,
  });
}

class LoyaltyReward {
  final String id;
  final LoyaltyRewardType type;
  final String name;
  final String? description;
  final LoyaltyDiscountType discountType;
  final double discountValue;

  const LoyaltyReward({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    required this.discountType,
    required this.discountValue,
  });

  double calculateDiscount(double subtotal) {
    final value = discountType == LoyaltyDiscountType.percentage
        ? subtotal * (discountValue / 100)
        : discountValue;
    return value.clamp(0, subtotal);
  }
}

class LoyaltyOutboxPayload {
  final String idempotencyKey;
  final Map<String, dynamic> body;
  final String action;

  LoyaltyOutboxPayload({
    required this.idempotencyKey,
    required this.body,
    required this.action,
  });

  Map<String, dynamic> toMap() => {
        'idempotencyKey': idempotencyKey,
        'body': body,
        'action': action,
      };

  factory LoyaltyOutboxPayload.fromMap(Map<String, dynamic> map) =>
      LoyaltyOutboxPayload(
        idempotencyKey: map['idempotencyKey'] as String,
        body: Map<String, dynamic>.from(map['body'] as Map),
        action: map['action'] as String,
      );
}