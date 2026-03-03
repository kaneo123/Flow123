enum PromotionDiscountType {
  percent,
  fixedAmount,
  fixedPrice,
  xForY,
  bulkPrice;

  static PromotionDiscountType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'percent':
        return PromotionDiscountType.percent;
      case 'fixed_amount':
        return PromotionDiscountType.fixedAmount;
      case 'fixed_price':
        return PromotionDiscountType.fixedPrice;
      case 'x_for_y':
        return PromotionDiscountType.xForY;
      case 'bulk_price':
        return PromotionDiscountType.bulkPrice;
      default:
        throw ArgumentError('Unknown discount type: $value');
    }
  }

  String toJson() {
    switch (this) {
      case PromotionDiscountType.percent:
        return 'percent';
      case PromotionDiscountType.fixedAmount:
        return 'fixed_amount';
      case PromotionDiscountType.fixedPrice:
        return 'fixed_price';
      case PromotionDiscountType.xForY:
        return 'x_for_y';
      case PromotionDiscountType.bulkPrice:
        return 'bulk_price';
    }
  }
}

enum PromotionScope {
  all,
  category,
  products;

  static PromotionScope fromString(String value) {
    switch (value.toLowerCase()) {
      case 'all':
        return PromotionScope.all;
      case 'category':
        return PromotionScope.category;
      case 'products':
        return PromotionScope.products;
      default:
        throw ArgumentError('Unknown scope: $value');
    }
  }

  String toJson() {
    switch (this) {
      case PromotionScope.all:
        return 'all';
      case PromotionScope.category:
        return 'category';
      case PromotionScope.products:
        return 'products';
    }
  }
}

class Promotion {
  final String id;
  final String outletId;
  final String name;
  final PromotionDiscountType discountType;
  final PromotionScope scope;
  final double? discountValue;
  final int? xQty;
  final int? yQty;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final List<int>? daysOfWeek; // 1 = Monday, 7 = Sunday
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  Promotion({
    required this.id,
    required this.outletId,
    required this.name,
    required this.discountType,
    required this.scope,
    this.discountValue,
    this.xQty,
    this.yQty,
    this.startDateTime,
    this.endDateTime,
    this.daysOfWeek,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      name: json['name'] as String,
      discountType: PromotionDiscountType.fromString(json['discount_type'] as String),
      scope: PromotionScope.fromString(json['scope'] as String),
      discountValue: (json['discount_value'] as num?)?.toDouble(),
      xQty: json['x_qty'] as int?,
      yQty: json['y_qty'] as int?,
      startDateTime: json['start_datetime'] != null 
          ? DateTime.parse(json['start_datetime'] as String) 
          : null,
      endDateTime: json['end_datetime'] != null 
          ? DateTime.parse(json['end_datetime'] as String) 
          : null,
      daysOfWeek: json['days_of_week'] != null
          ? (json['days_of_week'] as List<dynamic>).cast<int>()
          : null,
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'name': name,
    'discount_type': discountType.toJson(),
    'scope': scope.toJson(),
    if (discountValue != null) 'discount_value': discountValue,
    if (xQty != null) 'x_qty': xQty,
    if (yQty != null) 'y_qty': yQty,
    if (startDateTime != null) 'start_datetime': startDateTime!.toIso8601String(),
    if (endDateTime != null) 'end_datetime': endDateTime!.toIso8601String(),
    if (daysOfWeek != null) 'days_of_week': daysOfWeek,
    'active': active,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  /// Check if this promotion is active for the given date/time
  bool isActiveAt(DateTime dateTime) {
    if (!active) return false;

    // Check date/time window
    if (startDateTime != null && dateTime.isBefore(startDateTime!)) {
      return false;
    }
    if (endDateTime != null && dateTime.isAfter(endDateTime!)) {
      return false;
    }

    // Check day of week (1 = Monday, 7 = Sunday)
    if (daysOfWeek != null && daysOfWeek!.isNotEmpty) {
      final dayOfWeek = dateTime.weekday; // DateTime.weekday: 1 = Monday, 7 = Sunday
      if (!daysOfWeek!.contains(dayOfWeek)) {
        return false;
      }
    }

    return true;
  }
}

class PromotionProduct {
  final String promotionId;
  final String productId;

  PromotionProduct({
    required this.promotionId,
    required this.productId,
  });

  factory PromotionProduct.fromJson(Map<String, dynamic> json) {
    return PromotionProduct(
      promotionId: json['promotion_id'] as String,
      productId: json['product_id'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'promotion_id': promotionId,
    'product_id': productId,
  };
}

class PromotionCategory {
  final String promotionId;
  final String categoryId;

  PromotionCategory({
    required this.promotionId,
    required this.categoryId,
  });

  factory PromotionCategory.fromJson(Map<String, dynamic> json) {
    return PromotionCategory(
      promotionId: json['promotion_id'] as String,
      categoryId: json['category_id'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'promotion_id': promotionId,
    'category_id': categoryId,
  };
}

class AppliedPromotion {
  final String promotionId;
  final String name;
  final double discountAmount;

  AppliedPromotion({
    required this.promotionId,
    required this.name,
    required this.discountAmount,
  });

  Map<String, dynamic> toJson() => {
    'promotion_id': promotionId,
    'name': name,
    'discount_amount': discountAmount,
  };

  factory AppliedPromotion.fromJson(Map<String, dynamic> json) {
    return AppliedPromotion(
      promotionId: json['promotion_id'] as String,
      name: json['name'] as String,
      discountAmount: (json['discount_amount'] as num).toDouble(),
    );
  }
}

class PromotionResult {
  final double totalDiscount;
  final List<AppliedPromotion> appliedPromotions;

  PromotionResult({
    required this.totalDiscount,
    required this.appliedPromotions,
  });

  PromotionResult.empty()
      : totalDiscount = 0.0,
        appliedPromotions = [];

  Map<String, dynamic> toJson() => {
    'total_discount': totalDiscount,
    'applied_promotions': appliedPromotions.map((p) => p.toJson()).toList(),
  };

  factory PromotionResult.fromJson(Map<String, dynamic> json) {
    return PromotionResult(
      totalDiscount: (json['total_discount'] as num).toDouble(),
      appliedPromotions: (json['applied_promotions'] as List<dynamic>)
          .map((p) => AppliedPromotion.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}
