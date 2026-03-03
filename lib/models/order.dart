import 'package:flowtill/models/order_item.dart';
import 'package:flowtill/models/epos_order.dart';
import 'package:flowtill/models/epos_order_item.dart';
import 'package:flowtill/models/product.dart';
import 'package:flowtill/models/promotion.dart';

class Order {
  final String id;
  final String outletId;
  final String? staffId;
  final List<OrderItem> items;
  final double discountAmount;
  final double voucherAmount;
  final double loyaltyRedeemed;
  final double serviceChargeRate;
  final List<AppliedPromotion> appliedPromotions;
  final double promotionDiscount;
  final String? loyaltyCustomerId;
  final String? loyaltyCustomerName;
  final String? loyaltyIdentifier;
  final String? loyaltyRewardId;
  final String? loyaltyRewardType;
  final String? loyaltyRewardName;
  final String? loyaltyRewardDiscountType;
  final double? loyaltyRewardValue;
  final double? loyaltyPointsToAward;
  final String? loyaltyRestaurantId;
  final String? tableId;
  final String? tableNumber;
  final String? paymentMethod;
  final double amountPaid;
  final double changeDue;
  final DateTime createdAt;
  final DateTime? completedAt;

  Order({
    required this.id,
    required this.outletId,
    this.staffId,
    this.items = const [],
    this.discountAmount = 0.0,
    this.voucherAmount = 0.0,
    this.loyaltyRedeemed = 0.0,
    this.serviceChargeRate = 0.0,
    this.appliedPromotions = const [],
    this.promotionDiscount = 0.0,
    this.loyaltyCustomerId,
    this.loyaltyCustomerName,
    this.loyaltyIdentifier,
    this.loyaltyRewardId,
    this.loyaltyRewardType,
    this.loyaltyRewardName,
    this.loyaltyRewardDiscountType,
    this.loyaltyRewardValue,
    this.loyaltyPointsToAward,
    this.loyaltyRestaurantId,
    this.tableId,
    this.tableNumber,
    this.paymentMethod,
    this.amountPaid = 0.0,
    this.changeDue = 0.0,
    required this.createdAt,
    this.completedAt,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.subtotal);
  double get taxAmount => items.fold(0.0, (sum, item) => sum + item.taxAmount);
  double get serviceCharge => subtotal * serviceChargeRate;
  double get totalDiscounts => discountAmount + voucherAmount + loyaltyRedeemed + promotionDiscount;
  double get totalDue => subtotal + taxAmount + serviceCharge - totalDiscounts;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Order copyWith({
    String? id,
    String? outletId,
    String? staffId,
    List<OrderItem>? items,
    double? discountAmount,
    double? voucherAmount,
    double? loyaltyRedeemed,
    double? serviceChargeRate,
    List<AppliedPromotion>? appliedPromotions,
    double? promotionDiscount,
    String? loyaltyCustomerId,
    String? loyaltyCustomerName,
    String? loyaltyIdentifier,
    String? loyaltyRewardId,
    String? loyaltyRewardType,
    String? loyaltyRewardName,
    String? loyaltyRewardDiscountType,
    double? loyaltyRewardValue,
    double? loyaltyPointsToAward,
    String? loyaltyRestaurantId,
    String? tableId,
    String? tableNumber,
    String? paymentMethod,
    double? amountPaid,
    double? changeDue,
    DateTime? createdAt,
    DateTime? completedAt,
  }) => Order(
    id: id ?? this.id,
    outletId: outletId ?? this.outletId,
    staffId: staffId ?? this.staffId,
    items: items ?? this.items,
    discountAmount: discountAmount ?? this.discountAmount,
    voucherAmount: voucherAmount ?? this.voucherAmount,
    loyaltyRedeemed: loyaltyRedeemed ?? this.loyaltyRedeemed,
    serviceChargeRate: serviceChargeRate ?? this.serviceChargeRate,
    appliedPromotions: appliedPromotions ?? this.appliedPromotions,
    promotionDiscount: promotionDiscount ?? this.promotionDiscount,
    loyaltyCustomerId: loyaltyCustomerId ?? this.loyaltyCustomerId,
    loyaltyCustomerName: loyaltyCustomerName ?? this.loyaltyCustomerName,
    loyaltyIdentifier: loyaltyIdentifier ?? this.loyaltyIdentifier,
    loyaltyRewardId: loyaltyRewardId ?? this.loyaltyRewardId,
    loyaltyRewardType: loyaltyRewardType ?? this.loyaltyRewardType,
    loyaltyRewardName: loyaltyRewardName ?? this.loyaltyRewardName,
    loyaltyRewardDiscountType: loyaltyRewardDiscountType ?? this.loyaltyRewardDiscountType,
    loyaltyRewardValue: loyaltyRewardValue ?? this.loyaltyRewardValue,
    loyaltyPointsToAward: loyaltyPointsToAward ?? this.loyaltyPointsToAward,
    loyaltyRestaurantId: loyaltyRestaurantId ?? this.loyaltyRestaurantId,
    tableId: tableId ?? this.tableId,
    tableNumber: tableNumber ?? this.tableNumber,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    amountPaid: amountPaid ?? this.amountPaid,
    changeDue: changeDue ?? this.changeDue,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt ?? this.completedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'staff_id': staffId,
    'items': items.map((item) => item.toJson()).toList(),
    'discount_amount': discountAmount,
    'voucher_amount': voucherAmount,
    'loyalty_redeemed': loyaltyRedeemed,
    'service_charge_rate': serviceChargeRate,
    'applied_promotions': appliedPromotions.map((p) => p.toJson()).toList(),
    'promotion_discount': promotionDiscount,
    'loyalty_customer_id': loyaltyCustomerId,
    'loyalty_customer_name': loyaltyCustomerName,
    'loyalty_identifier': loyaltyIdentifier,
    'loyalty_reward_id': loyaltyRewardId,
    'loyalty_reward_type': loyaltyRewardType,
    'loyalty_reward_name': loyaltyRewardName,
    'loyalty_reward_discount_type': loyaltyRewardDiscountType,
    'loyalty_reward_value': loyaltyRewardValue,
    'loyalty_points_to_award': loyaltyPointsToAward,
    'loyalty_restaurant_id': loyaltyRestaurantId,
    'table_id': tableId,
    'table_number': tableNumber,
    'payment_method': paymentMethod,
    'amount_paid': amountPaid,
    'change_due': changeDue,
    'created_at': createdAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    outletId: json['outlet_id'] as String,
    staffId: json['staff_id'] as String?,
    items: (json['items'] as List<dynamic>)
        .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
        .toList(),
    discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
    voucherAmount: (json['voucher_amount'] as num?)?.toDouble() ?? 0.0,
    loyaltyRedeemed: (json['loyalty_redeemed'] as num?)?.toDouble() ?? 0.0,
    serviceChargeRate: (json['service_charge_rate'] as num?)?.toDouble() ?? 0.0,
    appliedPromotions: json['applied_promotions'] != null
        ? (json['applied_promotions'] as List<dynamic>)
            .map((p) => AppliedPromotion.fromJson(p as Map<String, dynamic>))
            .toList()
        : [],
    promotionDiscount: (json['promotion_discount'] as num?)?.toDouble() ?? 0.0,
    loyaltyCustomerId: json['loyalty_customer_id'] as String?,
    loyaltyCustomerName: json['loyalty_customer_name'] as String?,
    loyaltyIdentifier: json['loyalty_identifier'] as String?,
    loyaltyRewardId: json['loyalty_reward_id'] as String?,
    loyaltyRewardType: json['loyalty_reward_type'] as String?,
    loyaltyRewardName: json['loyalty_reward_name'] as String?,
    loyaltyRewardDiscountType: json['loyalty_reward_discount_type'] as String?,
    loyaltyRewardValue: (json['loyalty_reward_value'] as num?)?.toDouble(),
    loyaltyPointsToAward: (json['loyalty_points_to_award'] as num?)?.toDouble(),
    loyaltyRestaurantId: json['loyalty_restaurant_id'] as String?,
    tableId: json['table_id'] as String?,
    tableNumber: json['table_number'] as String?,
    paymentMethod: json['payment_method'] as String?,
    amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
    changeDue: (json['change_due'] as num?)?.toDouble() ?? 0.0,
    createdAt: DateTime.parse(json['created_at'] as String),
    completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
  );

  /// Convert EposOrder and EposOrderItems from Supabase back to in-memory Order
  factory Order.fromEposModels(EposOrder eposOrder, List<EposOrderItem> eposItems) {
    // Convert EposOrderItems to OrderItems
    final items = eposItems.map((eposItem) {
      // Create a minimal Product from EposOrderItem data
      // For misc items, productId will be null - generate a temp ID
      final productId = eposItem.productId ?? 'misc_${eposItem.id}';
      
      // Calculate base product price by subtracting modifier price deltas from unitPrice
      // This is necessary because OrderItem.unitPrice will recalculate: product.price + modifier deltas
      final modifierTotal = eposItem.modifiers.fold<double>(
        0.0,
        (sum, mod) => sum + mod.priceDelta,
      );
      final baseProductPrice = eposItem.unitPrice - modifierTotal;
      
      final product = Product(
        id: productId,
        outletId: eposOrder.outletId,
        categoryId: eposItem.categoryId,
        name: eposItem.productName,
        plu: eposItem.plu,
        price: baseProductPrice,
        course: eposItem.course,
      );

      return OrderItem(
        id: eposItem.id,
        product: product,
        quantity: eposItem.quantity.toInt(),
        taxRate: eposItem.taxRate,
        notes: eposItem.notes ?? '',
        selectedModifiers: eposItem.modifiers,
      );
    }).toList();

    // Calculate service charge rate from the stored service charge amount
    final calculatedServiceChargeRate = eposOrder.subtotal > 0 
        ? eposOrder.serviceCharge / eposOrder.subtotal 
        : 0.0;

    return Order(
      id: eposOrder.id,
      outletId: eposOrder.outletId,
      staffId: eposOrder.staffId,
      items: items,
      discountAmount: eposOrder.discountAmount,
      voucherAmount: eposOrder.voucherAmount,
      loyaltyRedeemed: eposOrder.loyaltyRedeemed,
      serviceChargeRate: calculatedServiceChargeRate,
      tableId: eposOrder.tableId,
      tableNumber: eposOrder.tableNumber,
      paymentMethod: eposOrder.paymentMethod,
      amountPaid: 0.0,
      changeDue: eposOrder.changeDue,
      createdAt: eposOrder.openedAt,
      completedAt: eposOrder.completedAt,
    );
  }
}
