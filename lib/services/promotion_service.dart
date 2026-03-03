import 'package:flutter/foundation.dart';
import 'package:flowtill/models/promotion.dart';
import 'package:flowtill/supabase/supabase_config.dart';

class PromotionService {
  final _supabase = SupabaseConfig.client;

  List<Promotion> _cachedPromotions = [];
  Map<String, List<String>> _promotionProducts = {}; // promotionId -> [productId]
  Map<String, List<String>> _promotionCategories = {}; // promotionId -> [categoryId]

  /// Load all active promotions for the given outlet from Supabase
  Future<void> loadActivePromotions(String outletId) async {
    try {
      // ⚡ PARALLEL FETCH: Load all promotion data simultaneously
      final results = await Future.wait([
        _supabase
            .from('promotions')
            .select()
            .eq('outlet_id', outletId)
            .eq('active', true),
        _supabase
            .from('promotion_products')
            .select(),
        _supabase
            .from('promotion_categories')
            .select(),
      ]);

      final promotionsData = results[0] as List<dynamic>;
      final productsData = results[1] as List<dynamic>;
      final categoriesData = results[2] as List<dynamic>;

      _cachedPromotions = promotionsData
          .map((json) => Promotion.fromJson(json as Map<String, dynamic>))
          .toList();

      // Build promotion_products mapping
      _promotionProducts.clear();
      for (final row in productsData) {
        final promotionId = row['promotion_id'] as String;
        final productId = row['product_id'] as String;
        _promotionProducts.putIfAbsent(promotionId, () => []).add(productId);
      }

      // Build promotion_categories mapping
      _promotionCategories.clear();
      for (final row in categoriesData) {
        final promotionId = row['promotion_id'] as String;
        final categoryId = row['category_id'] as String;
        _promotionCategories.putIfAbsent(promotionId, () => []).add(categoryId);
      }
    } catch (e, stackTrace) {
      _cachedPromotions = [];
      _promotionProducts.clear();
      _promotionCategories.clear();
    }
  }

  /// Get all promotions that are active right now (considering date/time and day of week)
  List<Promotion> getActivePromotionsForNow() {
    final now = DateTime.now();
    return _cachedPromotions.where((p) => p.isActiveAt(now)).toList();
  }

  /// Get promotions applicable to a specific product
  List<Promotion> getPromotionsForProduct(String productId, String? categoryId) {
    final activePromotions = getActivePromotionsForNow();
    final applicable = <Promotion>[];

    for (final promo in activePromotions) {
      switch (promo.scope) {
        case PromotionScope.all:
          applicable.add(promo);
          break;
        case PromotionScope.products:
          final linkedProducts = _promotionProducts[promo.id] ?? [];
          if (linkedProducts.contains(productId)) {
            applicable.add(promo);
          }
          break;
        case PromotionScope.category:
          if (categoryId != null) {
            final linkedCategories = _promotionCategories[promo.id] ?? [];
            if (linkedCategories.contains(categoryId)) {
              applicable.add(promo);
            }
          }
          break;
      }
    }

    return applicable;
  }

  /// Check if a product is eligible for a given promotion
  bool isProductEligible(Promotion promotion, String productId, String? categoryId) {
    switch (promotion.scope) {
      case PromotionScope.all:
        return true;
      case PromotionScope.products:
        final linkedProducts = _promotionProducts[promotion.id] ?? [];
        return linkedProducts.contains(productId);
      case PromotionScope.category:
        if (categoryId == null) return false;
        final linkedCategories = _promotionCategories[promotion.id] ?? [];
        return linkedCategories.contains(categoryId);
    }
  }
}
