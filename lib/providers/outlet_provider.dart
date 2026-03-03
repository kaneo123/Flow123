import 'package:flutter/foundation.dart';
import 'package:flowtill/models/outlet.dart';
import 'package:flowtill/models/outlet_settings.dart';
import 'package:flowtill/services/outlet_service.dart';
import 'package:flowtill/services/outlet_settings_service.dart';
import 'package:flowtill/services/sync_service.dart';

/// Provider for outlet state management with comprehensive error handling
class OutletProvider with ChangeNotifier {
  final OutletService _outletService = OutletService();
  final OutletSettingsService _settingsService = OutletSettingsService();
  
  List<Outlet> _outlets = [];
  Outlet? _currentOutlet;
  OutletSettings? _currentSettings;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Outlet> get outlets => _outlets;
  Outlet? get currentOutlet => _currentOutlet;
  OutletSettings? get currentSettings => _currentSettings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  bool get hasOutlets => _outlets.isNotEmpty;

  /// Load all outlets from Supabase
  /// Always transitions through: loading → (success | error)
  Future<void> loadOutlets() async {
    debugPrint('🏪 OutletProvider: Starting to load outlets');
    
    // Set loading state
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _outletService.getAllOutlets();

      if (result.isSuccess && result.data != null) {
        // Success: outlets loaded
        _outlets = result.data!;
        _errorMessage = null;
        
        // Auto-select first outlet if none selected
        if (_outlets.isNotEmpty && _currentOutlet == null) {
          await setCurrentOutlet(_outlets.first);
        }
        
        debugPrint('✅ OutletProvider: Loaded ${_outlets.length} outlets');
      } else {
        // Failure: show error
        _outlets = [];
        _currentOutlet = null;
        _errorMessage = result.error ?? 'Failed to load outlets';
        
        debugPrint('❌ OutletProvider: Error loading outlets: $_errorMessage');
      }
    } catch (e) {
      // Unexpected error
      _outlets = [];
      _currentOutlet = null;
      _errorMessage = 'Unexpected error: ${e.toString()}';
      
      debugPrint('❌ OutletProvider: Unexpected error: $e');
    } finally {
      // Always clear loading state
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set the current outlet and load its settings
  Future<void> setCurrentOutlet(Outlet? outlet) async {
    if (outlet != null) {
      _currentOutlet = outlet;
      debugPrint('🏪 OutletProvider: Current outlet set to: ${outlet.name}');
      debugPrint('   Outlet ID: ${outlet.id}');
      debugPrint('   Service Charge Enabled: ${outlet.enableServiceCharge}');
      debugPrint('   Service Charge Percent: ${outlet.serviceChargePercent}%');
      
      // Load settings for this outlet
      await loadSettingsForCurrentOutlet();
      
      // Trigger sync for this outlet (lazy loading: critical data first, then background sync)
      debugPrint('🔄 OutletProvider: Triggering sync for outlet ${outlet.id}');
      SyncService().syncCriticalData(outlet.id);
      
      notifyListeners();
    }
  }

  /// Load settings for the current outlet
  Future<void> loadSettingsForCurrentOutlet() async {
    if (_currentOutlet == null) {
      debugPrint('⚠️ OutletProvider: Cannot load settings, no current outlet');
      return;
    }

    debugPrint('⚙️ OutletProvider: Loading settings for outlet: ${_currentOutlet!.name}');
    
    final result = await _settingsService.getSettingsForOutlet(_currentOutlet!.id);
    
    if (result.isSuccess && result.data != null) {
      _currentSettings = result.data;
      debugPrint('✅ OutletProvider: Settings loaded successfully');
    } else {
      debugPrint('⚠️ OutletProvider: Failed to load settings: ${result.error}');
      // Use default settings if loading fails
      _currentSettings = OutletSettings(
        outletId: _currentOutlet!.id,
        printOrderTicketsOnOrderAway: true,
        orderTicketCopies: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    
    notifyListeners();
  }

  /// Update outlet settings
  Future<bool> updateSettings(Map<String, dynamic> updates) async {
    if (_currentOutlet == null) {
      debugPrint('⚠️ OutletProvider: Cannot update settings, no current outlet');
      return false;
    }

    debugPrint('⚙️ OutletProvider: Updating settings for outlet: ${_currentOutlet!.name}');
    
    final result = await _settingsService.updateSettings(_currentOutlet!.id, updates);
    
    if (result.isSuccess && result.data != null) {
      _currentSettings = result.data;
      debugPrint('✅ OutletProvider: Settings updated successfully');
      notifyListeners();
      return true;
    } else {
      debugPrint('❌ OutletProvider: Failed to update settings: ${result.error}');
      return false;
    }
  }

  /// Create a new outlet
  Future<bool> createOutlet({
    required String name,
    String? code,
    String? addressLine1,
    String? addressLine2,
    String? town,
    String? postcode,
    String? phone,
    Map<String, dynamic>? settings,
  }) async {
    debugPrint('🏪 OutletProvider: Creating new outlet: $name');
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _outletService.createOutlet(
        name: name,
        code: code,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        town: town,
        postcode: postcode,
        phone: phone,
        settings: settings,
      );

      if (result.isSuccess && result.data != null) {
        // Add to list and set as current
        _outlets.add(result.data!);
        _currentOutlet = result.data;
        _errorMessage = null;
        
        debugPrint('✅ OutletProvider: Outlet created successfully');
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.error ?? 'Failed to create outlet';
        
        debugPrint('❌ OutletProvider: Failed to create outlet: $_errorMessage');
        
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Unexpected error: ${e.toString()}';
      
      debugPrint('❌ OutletProvider: Unexpected error creating outlet: $e');
      
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update an existing outlet
  Future<bool> updateOutlet(String id, Map<String, dynamic> updates) async {
    debugPrint('🏪 OutletProvider: Updating outlet: $id');
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _outletService.updateOutlet(id, updates);

      if (result.isSuccess && result.data != null) {
        // Update in list
        final index = _outlets.indexWhere((o) => o.id == id);
        if (index != -1) {
          _outlets[index] = result.data!;
          
          // Update current if it's the one being updated
          if (_currentOutlet?.id == id) {
            _currentOutlet = result.data;
          }
        }
        
        _errorMessage = null;
        
        debugPrint('✅ OutletProvider: Outlet updated successfully');
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.error ?? 'Failed to update outlet';
        
        debugPrint('❌ OutletProvider: Failed to update outlet: $_errorMessage');
        
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Unexpected error: ${e.toString()}';
      
      debugPrint('❌ OutletProvider: Unexpected error updating outlet: $e');
      
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete an outlet
  Future<bool> deleteOutlet(String id) async {
    debugPrint('🏪 OutletProvider: Deleting outlet: $id');
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _outletService.deleteOutlet(id);

      if (result.isSuccess) {
        // Remove from list
        _outlets.removeWhere((o) => o.id == id);
        
        // Clear current if it was deleted
        if (_currentOutlet?.id == id) {
          _currentOutlet = _outlets.isNotEmpty ? _outlets.first : null;
        }
        
        _errorMessage = null;
        
        debugPrint('✅ OutletProvider: Outlet deleted successfully');
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.error ?? 'Failed to delete outlet';
        
        debugPrint('❌ OutletProvider: Failed to delete outlet: $_errorMessage');
        
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Unexpected error: ${e.toString()}';
      
      debugPrint('❌ OutletProvider: Unexpected error deleting outlet: $e');
      
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Refresh outlets (reload from database)
  Future<void> refresh() => loadOutlets();

  /// Get table mode enabled status from current outlet settings
  bool get tableModeEnabled {
    if (_currentOutlet?.settings == null) return false;
    return _currentOutlet!.settings!['table_mode_enabled'] == true;
  }

  /// Get restaurant mode status from current outlet settings
  bool get restaurantMode {
    if (_currentOutlet?.settings == null) return false;
    return _currentOutlet!.settings!['restaurantMode'] == true;
  }

  /// Get table view mode from current outlet settings
  String get tableViewMode {
    if (_currentOutlet?.settings == null) return 'grid';
    return _currentOutlet!.settings!['tableViewMode'] as String? ?? 'grid';
  }

  /// Get quantity watch enabled status from current outlet settings
  bool get quantityWatchEnabled {
    if (_currentOutlet?.settings == null) return false;
    return _currentOutlet!.settings!['quantity_watch_enabled'] == true;
  }

  /// Get outlet settings (from outlet_settings table)
  OutletSettings? get outletSettings => _currentSettings;

  /// Update outlet setting
  Future<bool> updateOutletSetting(String key, dynamic value) async {
    if (_currentOutlet == null) return false;

    final updatedSettings = Map<String, dynamic>.from(_currentOutlet!.settings ?? {});
    updatedSettings[key] = value;

    return await updateOutlet(_currentOutlet!.id, {'settings': updatedSettings});
  }
}
