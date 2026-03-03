import 'package:flutter/foundation.dart';
import 'package:flowtill/models/stock_movement.dart';
import 'package:flowtill/models/inventory_item.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:uuid/uuid.dart';

/// Service for managing stock movements and inventory adjustments  
/// NOTE: This is different from the existing StockService which tracks in-memory product stock
class StockMovementService {
  final _uuid = const Uuid();

  /// Create a stock movement and update inventory quantity
  /// 
  /// For 'add' and 'remove' operations, this modifies current_qty by changeQty
  /// For 'set' operation, this sets current_qty to the new value directly
  Future<bool> createStockMovement({
    required String outletId,
    required String inventoryItemId,
    required double changeQty,
    required String reason,
    String? note,
    String? staffId,
  }) async {
    debugPrint('📦 StockService: Creating stock movement');
    debugPrint('   Inventory ID: $inventoryItemId');
    debugPrint('   Change Qty: $changeQty');
    debugPrint('   Reason: $reason');

    try {
      // 1. Fetch current inventory item
      final itemResponse = await SupabaseConfig.client
          .from('inventory_items')
          .select()
          .eq('id', inventoryItemId)
          .maybeSingle() as Map<String, dynamic>?;

      if (itemResponse == null) {
        debugPrint('❌ Inventory item not found');
        return false;
      }

      final currentItem = InventoryItem.fromJson(itemResponse);
      final newQty = currentItem.currentQty + changeQty;

      debugPrint('   Current Qty: ${currentItem.currentQty}');
      debugPrint('   New Qty: $newQty');

      // 2. Create stock movement record
      final movement = StockMovement(
        id: _uuid.v4(),
        outletId: outletId,
        inventoryItemId: inventoryItemId,
        changeQty: changeQty,
        reason: reason,
        note: note,
        createdByStaffId: staffId,
        createdAt: DateTime.now(),
      );

      await SupabaseConfig.client
          .from('stock_movements')
          .insert(movement.toJson());

      // 3. Update inventory quantity
      await SupabaseConfig.client
          .from('inventory_items')
          .update({
            'current_qty': newQty,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', inventoryItemId);

      debugPrint('✅ Stock movement created successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating stock movement: $e');
      debugPrint('Stack: $stackTrace');
      return false;
    }
  }

  /// Set inventory to a specific quantity (creates movement with delta)
  Future<bool> setInventoryQuantity({
    required String outletId,
    required String inventoryItemId,
    required double newQty,
    required String reason,
    String? note,
    String? staffId,
  }) async {
    debugPrint('📦 StockService: Setting inventory quantity to $newQty');

    try {
      // Fetch current quantity
      final itemResponse = await SupabaseConfig.client
          .from('inventory_items')
          .select()
          .eq('id', inventoryItemId)
          .maybeSingle() as Map<String, dynamic>?;

      if (itemResponse == null) {
        debugPrint('❌ Inventory item not found');
        return false;
      }

      final currentItem = InventoryItem.fromJson(itemResponse);
      final changeQty = newQty - currentItem.currentQty;

      debugPrint('   Current Qty: ${currentItem.currentQty}');
      debugPrint('   Target Qty: $newQty');
      debugPrint('   Change: $changeQty');

      // Use the standard createStockMovement which handles both movement + update
      return await createStockMovement(
        outletId: outletId,
        inventoryItemId: inventoryItemId,
        changeQty: changeQty,
        reason: reason,
        note: note,
        staffId: staffId,
      );
    } catch (e) {
      debugPrint('❌ Error setting inventory quantity: $e');
      return false;
    }
  }

  /// Get stock movements for an outlet, optionally filtered by inventory item
  Future<List<StockMovement>> getStockMovements({
    required String outletId,
    String? inventoryItemId,
    int limit = 50,
  }) async {
    debugPrint('📦 StockService: Fetching stock movements for outlet $outletId');

    try {
      // Build query with explicit column selection to avoid builder type issues
      var queryBuilder = SupabaseConfig.client
          .from('stock_movements')
          .select('*')
          .eq('outlet_id', outletId);

      // Conditionally filter by inventory item
      if (inventoryItemId != null) {
        queryBuilder = queryBuilder.eq('inventory_item_id', inventoryItemId);
      }

      // Chain ordering and limit, then await
      final response = await queryBuilder
          .order('created_at', ascending: false)
          .limit(limit);

      // Cast to List<dynamic> AFTER awaiting (operator precedence fix)
      final data = response as List<dynamic>;

      final movements = data
          .map((json) => StockMovement.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Fetched ${movements.length} stock movements');
      return movements;
    } catch (e) {
      debugPrint('❌ Error fetching stock movements: $e');
      return [];
    }
  }

  /// Get stock movements with inventory item details (for display)
  Future<List<Map<String, dynamic>>> getStockMovementsWithDetails({
    required String outletId,
    int limit = 50,
  }) async {
    debugPrint('📦 StockService: Fetching stock movements with details');

    try {
      final response = await SupabaseConfig.client
          .from('stock_movements')
          .select('*, inventory_items!inner(name, unit), staff!left(full_name)')
          .eq('outlet_id', outletId)
          .order('created_at', ascending: false)
          .limit(limit) as List<dynamic>;

      final movementsWithDetails = response.map((json) {
        final movement = StockMovement.fromJson(json as Map<String, dynamic>);
        final inventoryData = json['inventory_items'] as Map<String, dynamic>?;
        final staffData = json['staff'] as Map<String, dynamic>?;

        return {
          'movement': movement,
          'inventory_name': inventoryData?['name'] ?? 'Unknown Item',
          'inventory_unit': inventoryData?['unit'] ?? 'unit',
          'staff_name': staffData?['full_name'] ?? 'Unknown',
        };
      }).toList();

      debugPrint('✅ Fetched ${movementsWithDetails.length} movements with details');
      return movementsWithDetails;
    } catch (e) {
      debugPrint('❌ Error fetching movements with details: $e');
      return [];
    }
  }
}
