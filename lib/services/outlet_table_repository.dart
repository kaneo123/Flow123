import 'package:flutter/foundation.dart';
import 'package:flowtill/models/outlet_table.dart';
import 'package:flowtill/supabase/supabase_config.dart';

class OutletTableRepository {
  /// Get all active tables for an outlet, ordered by room and sort_order
  Future<List<OutletTable>> getActiveTablesForOutlet(String outletId) async {
    debugPrint('📥 OutletTableRepository: Fetching active tables for outlet $outletId');

    final result = await SupabaseService.select(
      'outlet_tables',
      filters: {'outlet_id': outletId, 'active': true},
      orderBy: 'room_name, sort_order',
      ascending: true,
    );

    if (!result.isSuccess || result.data == null) {
      debugPrint('❌ Failed to fetch outlet tables: ${result.error}');
      return [];
    }

    final tables = result.data!.map((json) => OutletTable.fromJson(json)).toList();
    debugPrint('✅ Fetched ${tables.length} active tables');
    return tables;
  }

  /// Get a single table by ID
  Future<OutletTable?> getTableById(String tableId) async {
    debugPrint('📥 OutletTableRepository: Fetching table $tableId');

    final result = await SupabaseService.selectSingle(
      'outlet_tables',
      filters: {'id': tableId},
    );

    if (!result.isSuccess || result.data == null) {
      debugPrint('❌ Failed to fetch table: ${result.error}');
      return null;
    }

    return OutletTable.fromJson(result.data!);
  }

  /// Create a new outlet table
  Future<OutletTable?> createTable(OutletTable table) async {
    debugPrint('📤 OutletTableRepository: Creating table ${table.tableNumber}');
    debugPrint('   📍 Table outlet_id: ${table.outletId}');
    debugPrint('   📍 Table room_name: ${table.roomName}');

    // Exclude id when creating - Supabase will auto-generate it
    final json = table.toJson(includeId: false);
    debugPrint('   📦 JSON being sent: $json');
    
    final result = await SupabaseService.insert('outlet_tables', json);

    if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
      debugPrint('❌ Failed to create table: ${result.error}');
      return null;
    }

    final created = OutletTable.fromJson(result.data!.first);
    debugPrint('✅ Table created: ${created.id}');
    debugPrint('   📍 Created outlet_id: ${created.outletId}');
    return created;
  }

  /// Update an existing outlet table
  Future<OutletTable?> updateTable(OutletTable table) async {
    debugPrint('🔄 OutletTableRepository: Updating table ${table.id}');

    final result = await SupabaseService.update(
      'outlet_tables',
      table.toJson(),
      filters: {'id': table.id},
    );

    if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
      debugPrint('❌ Failed to update table: ${result.error}');
      return null;
    }

    final updated = OutletTable.fromJson(result.data!.first);
    debugPrint('✅ Table updated: ${updated.id}');
    return updated;
  }

  /// Delete a table (soft delete by setting active=false)
  Future<bool> deleteTable(String tableId) async {
    debugPrint('🗑️ OutletTableRepository: Deleting table $tableId');

    final result = await SupabaseService.update(
      'outlet_tables',
      {'active': false, 'updated_at': DateTime.now().toIso8601String()},
      filters: {'id': tableId},
    );

    if (!result.isSuccess) {
      debugPrint('❌ Failed to delete table: ${result.error}');
      return false;
    }

    debugPrint('✅ Table deleted (soft)');
    return true;
  }

  /// Get all tables grouped by room for an outlet
  Future<Map<String, List<OutletTable>>> getTablesGroupedByRoom(String outletId) async {
    final tables = await getActiveTablesForOutlet(outletId);
    final grouped = <String, List<OutletTable>>{};

    for (final table in tables) {
      grouped.putIfAbsent(table.roomName, () => []).add(table);
    }

    return grouped;
  }

  /// Get distinct list of room names for an outlet
  Future<List<String>> getRoomsForOutlet(String outletId) async {
    debugPrint('📥 OutletTableRepository: Fetching rooms for outlet $outletId');

    final result = await SupabaseService.select(
      'outlet_tables',
      filters: {'outlet_id': outletId, 'active': true},
      orderBy: 'room_name',
      ascending: true,
    );

    if (!result.isSuccess || result.data == null) {
      debugPrint('❌ Failed to fetch rooms: ${result.error}');
      return [];
    }

    final rooms = result.data!
        .map((json) => json['room_name'] as String)
        .toSet()
        .toList();

    debugPrint('✅ Found ${rooms.length} distinct rooms');
    return rooms;
  }

  /// Get all tables for a specific outlet and room
  Future<List<OutletTable>> getTablesForOutletAndRoom(String outletId, String roomName) async {
    debugPrint('📥 OutletTableRepository: Fetching tables for outlet $outletId, room $roomName');

    final result = await SupabaseService.select(
      'outlet_tables',
      filters: {'outlet_id': outletId, 'room_name': roomName, 'active': true},
      orderBy: 'sort_order',
      ascending: true,
    );

    if (!result.isSuccess || result.data == null) {
      debugPrint('❌ Failed to fetch tables: ${result.error}');
      return [];
    }

    final tables = result.data!.map((json) => OutletTable.fromJson(json)).toList();
    debugPrint('✅ Fetched ${tables.length} active tables for room $roomName');
    return tables;
  }

  /// Update table position (for drag-and-drop layout)
  Future<bool> updateTablePosition(String tableId, double x, double y) async {
    debugPrint('🔄 OutletTableRepository: Updating position for table $tableId to ($x, $y)');

    final result = await SupabaseService.update(
      'outlet_tables',
      {
        'pos_x': x,
        'pos_y': y,
        'updated_at': DateTime.now().toIso8601String(),
      },
      filters: {'id': tableId},
    );

    if (!result.isSuccess) {
      debugPrint('❌ Failed to update table position: ${result.error}');
      return false;
    }

    debugPrint('✅ Table position updated');
    return true;
  }

  /// Reset all table positions for a room
  Future<bool> resetTablePositions(String outletId, String roomName) async {
    debugPrint('🔄 OutletTableRepository: Resetting positions for room $roomName');

    final tables = await getTablesForOutletAndRoom(outletId, roomName);

    for (final table in tables) {
      final result = await SupabaseService.update(
        'outlet_tables',
        {
          'pos_x': null,
          'pos_y': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        filters: {'id': table.id},
      );

      if (!result.isSuccess) {
        debugPrint('❌ Failed to reset position for table ${table.id}');
        return false;
      }
    }

    debugPrint('✅ All table positions reset');
    return true;
  }

  /// Delete a room by soft-deleting all its tables
  Future<bool> deleteRoom(String outletId, String roomName) async {
    debugPrint('🗑️ OutletTableRepository: Deleting room $roomName');

    final result = await SupabaseService.update(
      'outlet_tables',
      {'active': false, 'updated_at': DateTime.now().toIso8601String()},
      filters: {'outlet_id': outletId, 'room_name': roomName},
    );

    if (!result.isSuccess) {
      debugPrint('❌ Failed to delete room: ${result.error}');
      return false;
    }

    debugPrint('✅ Room deleted (all tables soft-deleted)');
    return true;
  }
}
