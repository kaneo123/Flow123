import 'package:flowtill/models/product.dart';
import 'package:flowtill/models/product_stock_info.dart';
import 'package:flowtill/models/inventory_item.dart';
import 'package:flowtill/services/inventory_repository.dart';

/// Service for managing in-memory product stock information
/// This is different from StockMovementService which handles stock movements/adjustments
class StockService {
  final _inventoryRepository = InventoryRepository();
  final Map<String, ProductStockInfo> _stockCache = {};

  /// Load stock information for products in an outlet
  Future<void> loadStockForOutlet(String outletId, List<Product> products) async {
    try {
      // STEP 1: Load all inventory items for the outlet
      final inventoryItems = await _inventoryRepository.getInventoryForOutlet(outletId);
      
      // Build a map of inventory by ID and by linked product ID for quick lookup
      final inventoryById = <String, InventoryItem>{};
      final inventoryByProductId = <String, double>{};
      for (final item in inventoryItems) {
        inventoryById[item.id] = item;
        if (item.linkedProductId != null) {
          inventoryByProductId[item.linkedProductId!] = item.currentQty;
        }
      }

      // STEP 2: Batch fetch ALL recipes and components (avoid N+1 queries)
      final allRecipes = await _inventoryRepository.getAllActiveRecipesForOutlet(outletId);
      final recipeIds = allRecipes.values.map((r) => r.id).toList();
      final allComponents = await _inventoryRepository.getAllRecipeComponents(recipeIds);

      // STEP 3: Build stock info for each product using cached data
      for (final product in products) {
        // Check if product has basic inventory tracking
        if (product.linkedInventoryItemId != null) {
          final qty = inventoryByProductId[product.id] ?? 0.0;
          _stockCache[product.id] = ProductStockInfo(
            productId: product.id,
            trackStock: true,
            isBasicMode: true,
            isEnhancedMode: false,
            currentQty: qty,
          );
        } else {
          // Check for enhanced mode (recipe-based)
          final recipe = allRecipes[product.id];
          
          if (recipe != null) {
            // Get recipe components from batch fetch
            final components = allComponents[recipe.id] ?? [];
            
            if (components.isNotEmpty) {
              // Calculate minimum portions available based on components
              int minPortions = 999999;
              
              for (final component in components) {
                final inventoryItem = inventoryById[component.inventoryItemId];
                if (inventoryItem == null) continue;
                
                final available = inventoryItem.currentQty;
                final neededPerPortion = component.quantityPerUnit;
                
                if (neededPerPortion > 0) {
                  final portionsFromThisComponent = (available / neededPerPortion).floor();
                  if (portionsFromThisComponent < minPortions) {
                    minPortions = portionsFromThisComponent;
                  }
                }
              }
              
              _stockCache[product.id] = ProductStockInfo(
                productId: product.id,
                trackStock: true,
                isBasicMode: false,
                isEnhancedMode: true,
                portionsRemaining: minPortions,
              );
            }
          }
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Get stock info for a specific product
  ProductStockInfo? getStockInfoForProduct(String productId) => _stockCache[productId];

  /// Clear cached stock information
  void clear() {
    _stockCache.clear();
  }
}
