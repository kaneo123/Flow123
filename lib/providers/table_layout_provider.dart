import 'package:flutter/foundation.dart';
import 'package:flowtill/models/outlet_table.dart';
import 'package:flowtill/services/outlet_table_repository.dart';

/// Provider for managing table layout settings screen state
class TableLayoutProvider extends ChangeNotifier {
  final OutletTableRepository _repository = OutletTableRepository();

  String? _selectedRoomName;
  List<String> _rooms = [];
  List<OutletTable> _tablesForRoom = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedTableId;

  // Getters
  String? get selectedRoomName => _selectedRoomName;
  List<String> get rooms => _rooms;
  List<OutletTable> get tablesForRoom => _tablesForRoom;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedTableId => _selectedTableId;

  /// Load all rooms for an outlet
  Future<void> loadRoomsForOutlet(String outletId) async {
    debugPrint('🔄 TableLayoutProvider: Loading rooms for outlet $outletId');
    debugPrint('   Current state - isLoading: $_isLoading, rooms: ${_rooms.length}');
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    debugPrint('   ✓ Set isLoading=true, notified listeners');

    try {
      debugPrint('   🔍 Fetching rooms from repository...');
      final allRooms = await _repository.getRoomsForOutlet(outletId);
      debugPrint('   ✓ Repository returned ${allRooms.length} rooms: $allRooms');
      
      // Remove duplicates by converting to Set and back to List
      _rooms = allRooms.toSet().toList();
      
      debugPrint('✅ Loaded ${_rooms.length} unique rooms (${allRooms.length} total)');
      
      // Auto-select first room if available (without triggering another loading state)
      if (_rooms.isNotEmpty && _selectedRoomName == null) {
        _selectedRoomName = _rooms.first;
        debugPrint('   🔍 Auto-selecting first room: $_selectedRoomName');
        // Load tables for the selected room
        try {
          _tablesForRoom = await _repository.getTablesForOutletAndRoom(outletId, _rooms.first);
          debugPrint('✅ Auto-loaded ${_tablesForRoom.length} tables for room ${_rooms.first}');
        } catch (e) {
          debugPrint('❌ Error auto-loading tables: $e');
          _errorMessage = 'Failed to load tables: $e';
        }
      } else if (_rooms.isEmpty) {
        debugPrint('   ⚠️ No rooms found for outlet');
        _tablesForRoom = [];
      } else if (_selectedRoomName != null) {
        debugPrint('   ℹ️ Room already selected: $_selectedRoomName');
      }
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to load rooms: $e';
      debugPrint('❌ Error loading rooms: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      debugPrint('   🏁 Finally block: Setting isLoading=false');
      _isLoading = false;
      notifyListeners();
      debugPrint('   ✓ Set isLoading=false, notified listeners');
    }
  }

  /// Select a room and load its tables
  Future<void> selectRoom(String outletId, String roomName) async {
    debugPrint('🔄 TableLayoutProvider: Selecting room $roomName');
    _selectedRoomName = roomName;
    _isLoading = true;
    _errorMessage = null;
    _selectedTableId = null;
    notifyListeners();

    try {
      _tablesForRoom = await _repository.getTablesForOutletAndRoom(outletId, roomName);
      debugPrint('✅ Loaded ${_tablesForRoom.length} tables for room $roomName');
    } catch (e) {
      _errorMessage = 'Failed to load tables: $e';
      debugPrint('❌ Error loading tables: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new room (creates first table entry with room name)
  Future<void> addRoom(String outletId, String roomName, int? roomNumber) async {
    debugPrint('🔄 TableLayoutProvider: Adding room $roomName');
    debugPrint('   📍 Outlet ID: $outletId');
    debugPrint('   📍 Room Name: $roomName');
    debugPrint('   📍 Room Number: $roomNumber');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Create a placeholder table entry for the room
      final newTable = OutletTable(
        id: '',
        outletId: outletId,
        roomName: roomName,
        roomNumber: roomNumber,
        tableNumber: '1',
        active: true,
        sortOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      debugPrint('   📤 Creating table with outlet_id: ${newTable.outletId}');
      final created = await _repository.createTable(newTable);
      
      if (created != null) {
        debugPrint('   ✅ Table created with ID: ${created.id}');
        debugPrint('   ✅ Table outlet_id: ${created.outletId}');
        // Reload rooms
        await loadRoomsForOutlet(outletId);
        // Select the new room
        await selectRoom(outletId, roomName);
        debugPrint('✅ Room added successfully');
      } else {
        _errorMessage = 'Failed to create room';
        debugPrint('   ❌ Repository returned null');
      }
    } catch (e) {
      _errorMessage = 'Failed to add room: $e';
      debugPrint('❌ Error adding room: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add or update a table
  Future<void> addOrUpdateTable(OutletTable table, {bool isUpdate = false}) async {
    debugPrint('🔄 TableLayoutProvider: ${isUpdate ? 'Updating' : 'Adding'} table ${table.tableNumber}');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      OutletTable? result;
      if (isUpdate) {
        result = await _repository.updateTable(table);
      } else {
        result = await _repository.createTable(table);
      }

      if (result != null) {
        // Reload tables for current room
        await selectRoom(table.outletId, table.roomName);
        debugPrint('✅ Table ${isUpdate ? 'updated' : 'added'} successfully');
      } else {
        _errorMessage = 'Failed to ${isUpdate ? 'update' : 'create'} table';
      }
    } catch (e) {
      _errorMessage = 'Failed to save table: $e';
      debugPrint('❌ Error saving table: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a table
  Future<void> deleteTable(String outletId, String tableId, String roomName) async {
    debugPrint('🔄 TableLayoutProvider: Deleting table $tableId');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.deleteTable(tableId);
      
      if (success) {
        // Reload tables for current room
        await selectRoom(outletId, roomName);
        debugPrint('✅ Table deleted successfully');
      } else {
        _errorMessage = 'Failed to delete table';
      }
    } catch (e) {
      _errorMessage = 'Failed to delete table: $e';
      debugPrint('❌ Error deleting table: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a room (deletes all tables in the room)
  Future<void> deleteRoom(String outletId, String roomName) async {
    debugPrint('🔄 TableLayoutProvider: Deleting room $roomName');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.deleteRoom(outletId, roomName);
      
      if (success) {
        // Clear selected room if it's the one being deleted
        if (_selectedRoomName == roomName) {
          _selectedRoomName = null;
          _tablesForRoom = [];
        }
        // Reload rooms list
        await loadRoomsForOutlet(outletId);
        debugPrint('✅ Room deleted successfully');
      } else {
        _errorMessage = 'Failed to delete room';
      }
    } catch (e) {
      _errorMessage = 'Failed to delete room: $e';
      debugPrint('❌ Error deleting room: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update table position on drag end
  Future<void> updateTablePosition(String tableId, double x, double y) async {
    try {
      // Update local state immediately for responsive UI
      final index = _tablesForRoom.indexWhere((t) => t.id == tableId);
      if (index != -1) {
        _tablesForRoom[index] = _tablesForRoom[index].copyWith(posX: x, posY: y);
        notifyListeners();
      }

      // Update in database
      await _repository.updateTablePosition(tableId, x, y);
      debugPrint('✅ Table position updated: ($x, $y)');
    } catch (e) {
      debugPrint('❌ Error updating table position: $e');
    }
  }

  /// Reset all table positions in current room
  Future<void> resetTablePositions(String outletId) async {
    if (_selectedRoomName == null) return;

    debugPrint('🔄 TableLayoutProvider: Resetting layout for room $_selectedRoomName');
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _repository.resetTablePositions(outletId, _selectedRoomName!);
      
      if (success) {
        // Reload tables to reflect reset positions
        await selectRoom(outletId, _selectedRoomName!);
        debugPrint('✅ Layout reset successfully');
      } else {
        _errorMessage = 'Failed to reset layout';
      }
    } catch (e) {
      _errorMessage = 'Failed to reset layout: $e';
      debugPrint('❌ Error resetting layout: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Select a table (for highlighting)
  void selectTable(String? tableId) {
    _selectedTableId = tableId;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Reset provider state (useful when navigating to the screen)
  void reset() {
    debugPrint('🔄 TableLayoutProvider: Resetting state');
    _selectedRoomName = null;
    _rooms = [];
    _tablesForRoom = [];
    _isLoading = false;
    _errorMessage = null;
    _selectedTableId = null;
    notifyListeners();
  }
}
