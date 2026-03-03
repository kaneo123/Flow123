import 'package:flutter/foundation.dart';
import 'package:flowtill/models/order.dart';
import 'package:flowtill/models/order_item.dart';
import 'package:flowtill/models/product.dart';
import 'package:flowtill/models/packaged_deal.dart';
import 'package:flowtill/services/packaged_deal_service.dart';
import 'package:uuid/uuid.dart';

/// Result of packaged deal detection
class PackagedDealDetectionResult {
  final List<OrderItem> updatedItems;
  final List<String> appliedDealIds;
  final bool dealsDetected;

  PackagedDealDetectionResult({
    required this.updatedItems,
    required this.appliedDealIds,
    required this.dealsDetected,
  });
}

/// Engine for detecting and applying packaged deals automatically
class PackagedDealEngine {
  final PackagedDealService _packagedDealService;
  final _uuid = const Uuid();

  PackagedDealEngine(this._packagedDealService);

  /// Detect and apply packaged deals to an order
  /// Returns updated order items with deals applied
  PackagedDealDetectionResult detectAndApplyDeals({
    required Order order,
    required Map<String, Product> productsById,
  }) {
    debugPrint('📦📦📦 PackagedDealEngine: DETECTING DEALS 📦📦📦');
    debugPrint('   Order ID: ${order.id}');
    debugPrint('   Order items: ${order.items.length}');
    
    // Log all items in order with details
    for (int i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      debugPrint('   [$i] ${item.product.name} (ID: ${item.product.id}) x${item.quantity} @ £${item.product.price.toStringAsFixed(2)} | Deal item: ${item.isPackagedDeal}');
    }

    // Get available deals
    final availableDeals = _packagedDealService.getAvailableDealsForNow();
    if (availableDeals.isEmpty) {
      debugPrint('   ❌ No available deals found');
      return PackagedDealDetectionResult(
        updatedItems: order.items,
        appliedDealIds: [],
        dealsDetected: false,
      );
    }

    debugPrint('   ✅ Available deals: ${availableDeals.length}');
    for (final deal in availableDeals) {
      debugPrint('      - ${deal.name} @ £${deal.price.toStringAsFixed(2)} (ID: ${deal.id})');
    }

    // Start with current items, excluding existing deal items
    final nonDealItems = order.items.where((item) => !item.isPackagedDeal).toList();
    debugPrint('   Non-deal items (excluding existing deals): ${nonDealItems.length}');
    for (int i = 0; i < nonDealItems.length; i++) {
      final item = nonDealItems[i];
      debugPrint('     [$i] ${item.product.name} (ID: ${item.product.id}) x${item.quantity} | OrderItem ID: ${item.id}');
    }

    // Build product quantity map (product_id -> quantity)
    final productQuantities = <String, int>{};
    for (final item in nonDealItems) {
      productQuantities[item.product.id] = (productQuantities[item.product.id] ?? 0) + item.quantity;
    }

    debugPrint('   Product quantities by ID:');
    productQuantities.forEach((productId, qty) {
      final product = productsById[productId];
      debugPrint('      - ${product?.name ?? "Unknown"} ($productId): $qty');
    });

    // Track which deals were applied
    final appliedDealIds = <String>[];
    final remainingItems = List<OrderItem>.from(nonDealItems);
    final dealItems = <OrderItem>[];

    // Try to match deals (sorted by price descending to prioritize better deals)
    final sortedDeals = List<PackagedDeal>.from(availableDeals)
      ..sort((a, b) => b.price.compareTo(a.price));

    for (final deal in sortedDeals) {
      debugPrint('');
      debugPrint('   🔍 CHECKING DEAL: ${deal.name} @ £${deal.price.toStringAsFixed(2)} (ID: ${deal.id})');
      
      // Get components for this deal
      final components = _packagedDealService.getComponentsForDeal(deal.id);
      if (components.isEmpty) {
        debugPrint('     ⚠️  No components found for this deal - SKIPPING');
        continue;
      }

      debugPrint('     📋 Deal has ${components.length} component(s):');
      for (int i = 0; i < components.length; i++) {
        final component = components[i];
        debugPrint('       [$i] "${component.componentName}": needs ${component.quantity} items from these product IDs:');
        for (final productId in component.productIds) {
          final product = productsById[productId];
          debugPrint('          • ${product?.name ?? "Unknown"} ($productId)');
        }
      }

      // Keep matching while we have enough items
      while (true) {
        final matchResult = _tryMatchDeal(
          deal: deal,
          components: components,
          remainingItems: remainingItems,
          productsById: productsById,
        );

        if (!matchResult.matched) {
          debugPrint('     ❌ No match found for this deal (not enough items)');
          break;
        }

        debugPrint('     ✅✅✅ DEAL MATCHED! Used ${matchResult.matchedItems.length} order items:');
        for (final item in matchResult.matchedItems) {
          debugPrint('        • ${item.product.name} x${item.quantity} (ID: ${item.id})');
        }
        debugPrint('     TOTAL QUANTITY IN MATCHED ITEMS: ${matchResult.matchedItems.fold(0, (sum, item) => sum + item.quantity)}');

        // Remove matched items from remaining
        for (final matchedItem in matchResult.matchedItems) {
          remainingItems.remove(matchedItem);
        }

        // Create deal item
        final dealItem = _createDealItem(
          deal: deal,
          matchedItems: matchResult.matchedItems,
          productsById: productsById,
        );
        dealItems.add(dealItem);
        appliedDealIds.add(deal.id);

        debugPrint('     Created deal item: ${dealItem.product.name}');
        debugPrint('     Deal component items stored: ${dealItem.dealComponentItems?.length ?? 0}');
        if (dealItem.dealComponentItems != null) {
          for (final compItem in dealItem.dealComponentItems!) {
            debugPrint('       - ${compItem.product.name} x${compItem.quantity}');
          }
        }
      }
    }

    // Combine remaining items with deal items
    final finalItems = [...remainingItems, ...dealItems];

    debugPrint('');
    debugPrint('   📊 FINAL RESULT:');
    debugPrint('      Regular items: ${remainingItems.length}');
    debugPrint('      Deal items: ${dealItems.length}');
    debugPrint('      Total items: ${finalItems.length}');
    debugPrint('      Applied deal IDs: ${appliedDealIds.isEmpty ? "none" : appliedDealIds.join(", ")}');
    debugPrint('📦📦📦 END DEAL DETECTION 📦📦📦');
    debugPrint('');

    return PackagedDealDetectionResult(
      updatedItems: finalItems,
      appliedDealIds: appliedDealIds,
      dealsDetected: dealItems.isNotEmpty,
    );
  }

  /// Try to match a deal with remaining items
  _DealMatchResult _tryMatchDeal({
    required PackagedDeal deal,
    required List<dynamic> components,
    required List<OrderItem> remainingItems,
    required Map<String, Product> productsById,
  }) {
    debugPrint('     🔎 Attempting to match deal with current remaining items...');
    final matchedItems = <OrderItem>[];
    final tempRemaining = List<OrderItem>.from(remainingItems);

    // Check each component requirement
    for (int compIndex = 0; compIndex < components.length; compIndex++) {
      final component = components[compIndex];
      final requiredChoices = component.quantity;
      int collectedChoices = 0;

      debugPrint('       Component [$compIndex] "${component.componentName}": need $requiredChoices choice(s)');

      // Try to collect required choices from matching products
      for (final productId in component.productIds) {
        if (collectedChoices >= requiredChoices) break;

        // Quantity multiplier for this product (e.g., "4 pints" = 4)
        final int rawProductQtyMultiplier = component.getProductQuantity(productId);
        final int productQtyMultiplier = rawProductQtyMultiplier <= 0 ? 1 : rawProductQtyMultiplier;

        // For components that need multiple choices (e.g., 2 steaks), allow each
        // item to count as a choice even if the multiplier > 1. This keeps
        // "2 steaks" deals working when the DB quantity is set to 2.
        final bool ignoreMultiplierForMatching = component.quantity > 1 && productQtyMultiplier > 1;
        final int effectiveMultiplier = ignoreMultiplierForMatching ? 1 : productQtyMultiplier;

        // Find items with this product
        final matchingItems = tempRemaining.where((item) =>
          item.product.id == productId && !item.isPackagedDeal
        ).toList();

        debugPrint('         Looking for product $productId (requires $productQtyMultiplier units per choice, using $effectiveMultiplier for matching): found ${matchingItems.length} matching order items');

        if (matchingItems.isEmpty) continue;

        // Total units we have across all matching items
        final int totalUnitsAvailable = matchingItems.fold<int>(0, (sum, item) => sum + item.quantity);
        final int choicesPossible = totalUnitsAvailable ~/ effectiveMultiplier;
        final int choicesNeeded = requiredChoices - collectedChoices;
        final int choicesToTake = choicesPossible < choicesNeeded ? choicesPossible : choicesNeeded;

        debugPrint('         Total units available: $totalUnitsAvailable → can satisfy up to $choicesPossible choice(s). Taking $choicesToTake now.');

        if (choicesToTake <= 0) {
          continue;
        }

        // Consume the required units across the matching items, splitting if necessary
        int unitsNeeded = choicesToTake * effectiveMultiplier;
        int unitsTaken = 0;

        for (final item in matchingItems) {
          if (unitsTaken >= unitsNeeded) break;

          final int remainingUnitsNeeded = unitsNeeded - unitsTaken;

          if (item.quantity <= remainingUnitsNeeded) {
            // Take the whole item
            debugPrint('           ✓ Taking entire item ${item.product.name} x${item.quantity}');
            matchedItems.add(item);
            tempRemaining.remove(item);
            unitsTaken += item.quantity;
          } else {
            // Split the item to take only what is needed
            debugPrint('           ✓ Splitting item ${item.product.name}: taking $remainingUnitsNeeded, leaving ${item.quantity - remainingUnitsNeeded}');
            final takenItem = item.copyWith(quantity: remainingUnitsNeeded);
            final remainingItem = item.copyWith(quantity: item.quantity - remainingUnitsNeeded);
            matchedItems.add(takenItem);
            final index = tempRemaining.indexOf(item);
            tempRemaining[index] = remainingItem;
            unitsTaken += remainingUnitsNeeded;
          }
        }

        final int choicesMade = unitsTaken ~/ effectiveMultiplier;
        collectedChoices += choicesMade;

        debugPrint('         ✅ Collected $choicesMade choice(s) from $productId (units taken: $unitsTaken/$unitsNeeded). Total collected: $collectedChoices/$requiredChoices');
      }

      // Check if we collected enough for this component
      if (collectedChoices < requiredChoices) {
        debugPrint('       ❌ COMPONENT FAILED: "${component.componentName}" needs $requiredChoices choice(s) but only found $collectedChoices');
        debugPrint('          Required product IDs: ${component.productIds.join(", ")}');
        return _DealMatchResult(matched: false, matchedItems: []);
      }
      
      debugPrint('       ✅ Component satisfied: collected $collectedChoices choice(s)');
    }

    debugPrint('     ✅ All components satisfied - DEAL CAN BE APPLIED');
    return _DealMatchResult(matched: true, matchedItems: matchedItems);
  }

  /// Create a deal item from matched items
  OrderItem _createDealItem({
    required PackagedDeal deal,
    required List<OrderItem> matchedItems,
    required Map<String, Product> productsById,
  }) {
    // Create a synthetic product for the deal
    final dealProduct = Product(
      id: 'deal_${deal.id}',
      outletId: deal.outletId,
      name: deal.name,
      price: deal.price,
      active: true,
      trackStock: false,
      createdAt: DateTime.now(),
    );

    // Calculate average tax rate from matched items
    final totalTax = matchedItems.fold<double>(0.0, (sum, item) => sum + item.taxRate * item.subtotal);
    final totalSubtotal = matchedItems.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    final averageTaxRate = totalSubtotal > 0 ? totalTax / totalSubtotal : 0.0;

    return OrderItem(
      id: _uuid.v4(),
      product: dealProduct,
      quantity: 1,
      taxRate: averageTaxRate,
      packagedDealId: deal.id,
      dealComponentItemIds: matchedItems.map((item) => item.id).toList(),
      dealComponentItems: List.from(matchedItems), // Store actual items for display
    );
  }
}

class _DealMatchResult {
  final bool matched;
  final List<OrderItem> matchedItems;

  _DealMatchResult({
    required this.matched,
    required this.matchedItems,
  });
}
