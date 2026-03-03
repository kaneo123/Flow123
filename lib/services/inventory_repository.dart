import 'package:flowtill/models/inventory_item.dart';
import 'package:flowtill/models/product_recipe.dart';
import 'package:flowtill/models/product_recipe_component.dart';
import 'package:flowtill/supabase/supabase_config.dart';

class InventoryRepository {
  final _supabase = SupabaseConfig.client;

  Future<List<InventoryItem>> fetchInventoryForOutlet(String outletId) async {
    try {
      final response = await _supabase
          .from('inventory_items')
          .select()
          .eq('outlet_id', outletId)
          .order('name');

      final items = (response as List<dynamic>)
          .map((json) => InventoryItem.fromJson(json as Map<String, dynamic>))
          .toList();

      return items;
    } catch (e) {
      return [];
    }
  }

  // Alias for compatibility
  Future<List<InventoryItem>> getInventoryForOutlet(String outletId) => fetchInventoryForOutlet(outletId);

  Future<InventoryItem?> fetchInventoryForProduct(String productId) async {
    try {
      final productResponse = await _supabase
          .from('products')
          .select('inventory_item_id')
          .eq('id', productId)
          .maybeSingle();

      if (productResponse == null) {
        return null;
      }

      final inventoryItemId = productResponse['inventory_item_id'];
      if (inventoryItemId == null) {
        return null;
      }

      final inventoryResponse = await _supabase
          .from('inventory_items')
          .select()
          .eq('id', inventoryItemId)
          .maybeSingle();

      if (inventoryResponse == null) return null;

      final item = InventoryItem.fromJson(inventoryResponse as Map<String, dynamic>);
      return item;
    } catch (e) {
      return null;
    }
  }

  Future<void> decrementStock({
    required String productId,
    required double qty,
  }) async {
    try {
      final productResponse = await _supabase
          .from('products')
          .select('inventory_item_id')
          .eq('id', productId)
          .maybeSingle();

      if (productResponse == null || productResponse['inventory_item_id'] == null) {
        return;
      }

      final inventoryItemId = productResponse['inventory_item_id'] as String;
      final inventoryResponse = await _supabase
          .from('inventory_items')
          .select()
          .eq('id', inventoryItemId)
          .maybeSingle();

      if (inventoryResponse == null) return;

      final inventoryItem = InventoryItem.fromJson(inventoryResponse as Map<String, dynamic>);
      final newQty = (inventoryItem.currentQty - qty).clamp(0.0, double.infinity);

      await _supabase
          .from('inventory_items')
          .update({'current_qty': newQty, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', inventoryItemId);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> incrementStock({
    required String productId,
    required double qty,
  }) async {
    try {
      final productResponse = await _supabase
          .from('products')
          .select('inventory_item_id')
          .eq('id', productId)
          .maybeSingle();

      if (productResponse == null || productResponse['inventory_item_id'] == null) {
        return;
      }

      final inventoryItemId = productResponse['inventory_item_id'] as String;

      final inventoryResponse = await _supabase
          .from('inventory_items')
          .select()
          .eq('id', inventoryItemId)
          .maybeSingle();

      if (inventoryResponse == null) return;

      final inventoryItem = InventoryItem.fromJson(inventoryResponse as Map<String, dynamic>);
      final newQty = inventoryItem.currentQty + qty;

      await _supabase
          .from('inventory_items')
          .update({'current_qty': newQty, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', inventoryItemId);
    } catch (e) {
      // Silent fail
    }
  }

  // Alias for compatibility
  Future<void> incrementStockForProduct({
    required String outletId,
    required String productId,
    required int quantity,
  }) => incrementStock(productId: productId, qty: quantity.toDouble());

  Future<void> updateInventoryQuantity(String inventoryItemId, double newQty) async {
    try {
      await _supabase
          .from('inventory_items')
          .update({'current_qty': newQty, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', inventoryItemId);
    } catch (e) {
      // Silent fail
    }
  }

  Future<List<InventoryItem>> fetchLowStockItems(String outletId, {double threshold = 10.0}) async {
    try {
      final response = await _supabase
          .from('inventory_items')
          .select()
          .eq('outlet_id', outletId)
          .lte('current_qty', threshold)
          .order('current_qty');

      final lowStockItems = (response as List<dynamic>)
          .map((json) => InventoryItem.fromJson(json as Map<String, dynamic>))
          .toList();

      return lowStockItems;
    } catch (e) {
      return [];
    }
  }

  Future<ProductRecipe?> fetchActiveRecipeForProduct(String productId) async {
    try {
      final response = await _supabase
          .from('product_recipes')
          .select()
          .eq('product_id', productId)
          .eq('active', true)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      final recipe = ProductRecipe.fromJson(response as Map<String, dynamic>);
      return recipe;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, ProductRecipe>> fetchAllActiveRecipes(String outletId) async {
    try {
      final response = await _supabase
          .from('product_recipes')
          .select('*, products!inner(outlet_id)')
          .eq('products.outlet_id', outletId)
          .eq('active', true);

      final recipesByProductId = <String, ProductRecipe>{};
      for (final json in response as List<dynamic>) {
        final recipe = ProductRecipe.fromJson(json as Map<String, dynamic>);
        recipesByProductId[recipe.productId] = recipe;
      }

      return recipesByProductId;
    } catch (e) {
      return {};
    }
  }

  // Alias for compatibility
  Future<Map<String, ProductRecipe>> getAllActiveRecipesForOutlet(String outletId) => fetchAllActiveRecipes(outletId);

  Future<Map<String, List<ProductRecipeComponent>>> fetchComponentsForRecipes(List<String> recipeIds) async {
    if (recipeIds.isEmpty) return {};

    try {
      final response = await _supabase
          .from('product_recipe_components')
          .select()
          .inFilter('recipe_id', recipeIds);

      final componentsByRecipeId = <String, List<ProductRecipeComponent>>{};
      for (final json in response as List<dynamic>) {
        final component = ProductRecipeComponent.fromJson(json as Map<String, dynamic>);
        componentsByRecipeId.putIfAbsent(component.recipeId, () => []).add(component);
      }

      return componentsByRecipeId;
    } catch (e) {
      return {};
    }
  }

  // Alias for compatibility
  Future<Map<String, List<ProductRecipeComponent>>> getAllRecipeComponents(List<String> recipeIds) => fetchComponentsForRecipes(recipeIds);

  Future<List<ProductRecipeComponent>> fetchRecipeComponents(String recipeId) async {
    try {
      final response = await _supabase
          .from('product_recipe_components')
          .select()
          .eq('recipe_id', recipeId);

      final components = (response as List<dynamic>)
          .map((json) => ProductRecipeComponent.fromJson(json as Map<String, dynamic>))
          .toList();

      return components;
    } catch (e) {
      return [];
    }
  }

  Future<void> deductRecipeBasedStock({
    required String productId,
    required int quantity,
  }) async {
    try {
      final recipe = await fetchActiveRecipeForProduct(productId);
      if (recipe == null) {
        return;
      }

      final components = await fetchRecipeComponents(recipe.id);
      if (components.isEmpty) {
        return;
      }

      for (final component in components) {
        final inventoryResponse = await _supabase
            .from('inventory_items')
            .select()
            .eq('id', component.inventoryItemId)
            .maybeSingle();

        if (inventoryResponse == null) continue;

        final inventoryItem = InventoryItem.fromJson(inventoryResponse as Map<String, dynamic>);
        final effectivePerUnit = component.quantityPerUnit * (1.0 + (component.wastageFactor ?? 0.0));
        final totalUsage = effectivePerUnit * quantity;
        final newQty = (inventoryItem.currentQty - totalUsage).clamp(0.0, double.infinity);

        await _supabase
            .from('inventory_items')
            .update({'current_qty': newQty, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', component.inventoryItemId);
      }
    } catch (e, stackTrace) {
      // Silent fail
    }
  }

  Future<void> deductBasicInventoryStock({
    required String inventoryItemId,
    required double quantity,
  }) async {
    try {
      final inventoryResponse = await _supabase
          .from('inventory_items')
          .select()
          .eq('id', inventoryItemId)
          .maybeSingle();

      if (inventoryResponse == null) {
        return;
      }

      final inventoryItem = InventoryItem.fromJson(inventoryResponse as Map<String, dynamic>);
      final newQty = (inventoryItem.currentQty - quantity).clamp(0.0, double.infinity);

      await _supabase
          .from('inventory_items')
          .update({'current_qty': newQty, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', inventoryItemId);
    } catch (e, stackTrace) {
      // Silent fail
    }
  }

  Future<void> restoreRecipeBasedStock({
    required String productId,
    required int quantity,
  }) async {
    try {
      final recipe = await fetchActiveRecipeForProduct(productId);
      if (recipe == null) {
        return;
      }

      final components = await fetchRecipeComponents(recipe.id);
      if (components.isEmpty) {
        return;
      }

      for (final component in components) {
        final inventoryResponse = await _supabase
            .from('inventory_items')
            .select()
            .eq('id', component.inventoryItemId)
            .maybeSingle();

        if (inventoryResponse == null) continue;

        final inventoryItem = InventoryItem.fromJson(inventoryResponse as Map<String, dynamic>);
        final effectivePerUnit = component.quantityPerUnit * (1.0 + (component.wastageFactor ?? 0.0));
        final totalRestore = effectivePerUnit * quantity;
        final newQty = inventoryItem.currentQty + totalRestore;

        await _supabase
            .from('inventory_items')
            .update({'current_qty': newQty, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', component.inventoryItemId);
      }
    } catch (e, stackTrace) {
      // Silent fail
    }
  }
}
