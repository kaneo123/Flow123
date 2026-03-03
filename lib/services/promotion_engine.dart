import 'package:flutter/foundation.dart';
import 'package:flowtill/models/order.dart';
import 'package:flowtill/models/order_item.dart';
import 'package:flowtill/models/product.dart';
import 'package:flowtill/models/promotion.dart';
import 'package:flowtill/services/promotion_service.dart';

class PromotionEngine {
  final PromotionService _promotionService;

  PromotionEngine(this._promotionService);

  /// Calculate all applicable promotions for the given order
  PromotionResult calculate({
    required Order order,
    required List<Promotion> promotions,
    required Map<String, Product> productsById,
  }) {
    if (order.items.isEmpty || promotions.isEmpty) {
      return PromotionResult.empty();
    }

    final appliedPromotions = <AppliedPromotion>[];
    double totalDiscount = 0.0;

    // Apply each promotion independently
    for (final promotion in promotions) {
      final discount = _calculatePromotionDiscount(
        promotion: promotion,
        order: order,
        productsById: productsById,
      );

      if (discount > 0) {
        appliedPromotions.add(AppliedPromotion(
          promotionId: promotion.id,
          name: promotion.name,
          discountAmount: discount,
        ));
        totalDiscount += discount;
      }
    }

    return PromotionResult(
      totalDiscount: totalDiscount,
      appliedPromotions: appliedPromotions,
    );
  }

  double _calculatePromotionDiscount({
    required Promotion promotion,
    required Order order,
    required Map<String, Product> productsById,
  }) {
    // Get eligible items for this promotion
    final eligibleItems = order.items.where((item) {
      final product = item.product;
      return _promotionService.isProductEligible(
        promotion,
        product.id,
        product.categoryId,
      );
    }).toList();

    if (eligibleItems.isEmpty) return 0.0;

    switch (promotion.discountType) {
      case PromotionDiscountType.xForY:
        return _calculateXForYDiscount(promotion, eligibleItems);
      case PromotionDiscountType.percent:
        return _calculatePercentDiscount(promotion, eligibleItems);
      case PromotionDiscountType.fixedAmount:
        return _calculateFixedAmountDiscount(promotion, eligibleItems);
      case PromotionDiscountType.fixedPrice:
        return _calculateFixedPriceDiscount(promotion, eligibleItems);
      case PromotionDiscountType.bulkPrice:
        return _calculateBulkPriceDiscount(promotion, eligibleItems);
    }
  }

  /// Calculate X-for-Y discount (e.g., 2-for-1)
  double _calculateXForYDiscount(Promotion promotion, List<OrderItem> eligibleItems) {
    final xQty = promotion.xQty;
    final yQty = promotion.yQty;

    if (xQty == null || yQty == null || xQty <= 0 || yQty <= 0) {
      return 0.0;
    }

    // Sum total eligible quantity
    final totalQty = eligibleItems.fold(0, (sum, item) => sum + item.quantity);

    // Calculate number of complete groups
    final groupSize = xQty + yQty;
    final groups = totalQty ~/ groupSize;

    if (groups == 0) {
      return 0.0;
    }

    final freeQty = groups * yQty;

    // Find cheapest items to discount (most common approach for X-for-Y)
    final allUnits = <double>[];
    for (final item in eligibleItems) {
      for (var i = 0; i < item.quantity; i++) {
        allUnits.add(item.product.price);
      }
    }

    // Sort by price ascending (cheapest first)
    allUnits.sort();

    // Discount the cheapest freeQty items
    final discountAmount = allUnits.take(freeQty).fold(0.0, (sum, price) => sum + price);

    return discountAmount;
  }

  /// Calculate percent discount
  double _calculatePercentDiscount(Promotion promotion, List<OrderItem> eligibleItems) {
    final discountValue = promotion.discountValue;
    if (discountValue == null || discountValue <= 0) return 0.0;

    final eligibleTotal = eligibleItems.fold(0.0, (sum, item) => sum + item.subtotal);
    final discountAmount = eligibleTotal * (discountValue / 100.0);

    return discountAmount;
  }

  /// Calculate fixed amount discount
  double _calculateFixedAmountDiscount(Promotion promotion, List<OrderItem> eligibleItems) {
    final discountValue = promotion.discountValue;
    if (discountValue == null || discountValue <= 0) return 0.0;

    final eligibleTotal = eligibleItems.fold(0.0, (sum, item) => sum + item.subtotal);

    // Cap discount at eligible total (can't discount more than the total)
    final discountAmount = discountValue > eligibleTotal ? eligibleTotal : discountValue;

    return discountAmount;
  }

  /// Calculate fixed price discount
  double _calculateFixedPriceDiscount(Promotion promotion, List<OrderItem> eligibleItems) {
    final fixedPrice = promotion.discountValue;
    if (fixedPrice == null || fixedPrice < 0) return 0.0;

    final eligibleTotal = eligibleItems.fold(0.0, (sum, item) => sum + item.subtotal);

    if (eligibleTotal <= fixedPrice) {
      // If already cheaper than fixed price, no discount
      return 0.0;
    }

    final discountAmount = eligibleTotal - fixedPrice;

    return discountAmount;
  }

  /// Calculate bulk price discount (e.g., 2 for £X)
  /// Uses xQty to define the quantity threshold and discountValue for the total price
  double _calculateBulkPriceDiscount(Promotion promotion, List<OrderItem> eligibleItems) {
    final bulkQty = promotion.xQty;
    final bulkPrice = promotion.discountValue;

    if (bulkQty == null || bulkQty <= 0 || bulkPrice == null || bulkPrice < 0) {
      return 0.0;
    }

    // Sum total eligible quantity
    final totalQty = eligibleItems.fold(0, (sum, item) => sum + item.quantity);

    // Calculate number of complete bulk groups
    final groups = totalQty ~/ bulkQty;

    if (groups == 0) {
      return 0.0;
    }

    // Calculate what the customer would normally pay for these groups
    final itemsInBulkGroups = groups * bulkQty;
    final allUnits = <double>[];
    
    for (final item in eligibleItems) {
      for (var i = 0; i < item.quantity; i++) {
        allUnits.add(item.product.price);
      }
    }

    // Take the first itemsInBulkGroups items (they'll be discounted to bulkPrice per group)
    final normalPriceForBulkItems = allUnits.take(itemsInBulkGroups).fold(0.0, (sum, price) => sum + price);
    final discountedPrice = groups * bulkPrice;
    final discountAmount = normalPriceForBulkItems - discountedPrice;

    return discountAmount > 0 ? discountAmount : 0.0;
  }
}
