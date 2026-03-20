import 'package:flutter/foundation.dart';
import 'package:flowtill/models/outlet.dart';
import 'package:flowtill/models/outlet_settings.dart';
import 'package:flowtill/services/outlet_service.dart';
import 'package:flowtill/services/outlet_settings_service.dart';
import 'package:flowtill/services/sync_service.dart';
import 'package:flowtill/services/local_storage_service.dart';
import 'package:flowtill/services/outlet_availability_service.dart';
import 'package:flowtill/services/mirror_content_sync_service.dart';
import 'package:flowtill/services/startup_content_sync_orchestrator.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/config/sync_config.dart';

/// Provider for outlet state management with comprehensive error handling
class OutletProvider with ChangeNotifier {
  final OutletService _outletService = OutletService();
  final OutletSettingsService _settingsService = OutletSettingsService();
  final OutletAvailabilityService _availabilityService = OutletAvailabilityService();
  final MirrorContentSyncService _mirrorSync = MirrorContentSyncService();
  final StartupContentSyncOrchestrator _syncOrchestrator = StartupContentSyncOrchestrator();
  final ConnectionService _connectionService = ConnectionService();
  
  List<Outlet> _outlets = [];
  Outlet? _currentOutlet;
  OutletSettings? _currentSettings;
  bool _isLoading = false;
  bool _isSwitching = false;
  String? _errorMessage;

  // Getters
  List<Outlet> get outlets => _outlets;
  Outlet? get currentOutlet => _currentOutlet;
  OutletSettings? get currentSettings => _currentSettings;
  bool get isLoading => _isLoading;
  bool get isSwitching => _isSwitching;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  bool get hasOutlets => _outlets.isNotEmpty;

  /// Load all outlets from Supabase
  /// Always transitions through: loading → (success | error)
  Future<void> loadOutlets() async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
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
        
        debugPrint('✅ OutletProvider: Loaded ${_outlets.length} outlets');
        
        // Auto-select outlet if none selected
        // CRITICAL: Respect last selected outlet from startup sync to prevent mismatch
        if (_outlets.isNotEmpty && _currentOutlet == null) {
          final lastSelectedId = LocalStorageService().getLastSelectedOutletId();
          
          if (lastSelectedId != null) {
            // Find the outlet that matches the last selected ID (from startup sync)
            final matchedOutlet = _outlets.where((o) => o.id == lastSelectedId).firstOrNull;
            
            if (matchedOutlet != null) {
              debugPrint('🏪 OutletProvider: Restoring last selected outlet from startup sync');
              debugPrint('   Outlet ID: $lastSelectedId');
              debugPrint('   Outlet Name: ${matchedOutlet.name}');
              await setCurrentOutlet(matchedOutlet);
            } else {
              // Last selected outlet not found in list, fall back to first
              debugPrint('⚠️ OutletProvider: Last selected outlet ($lastSelectedId) not found in loaded outlets');
              debugPrint('   Falling back to first outlet: ${_outlets.first.name}');
              await setCurrentOutlet(_outlets.first);
            }
          } else {
            // No last selected outlet, use first
            debugPrint('🏪 OutletProvider: No last selected outlet, using first: ${_outlets.first.name}');
            await setCurrentOutlet(_outlets.first);
          }
        } else if (_currentOutlet != null) {
          debugPrint('🏪 OutletProvider: Outlet already selected: ${_currentOutlet!.name}');
        }
        
        debugPrint('═══════════════════════════════════════════════════════════');
        debugPrint('');
      } else {
        // Failure: show error
        _outlets = [];
        _currentOutlet = null;
        _errorMessage = result.error ?? 'Failed to load outlets';
        
        debugPrint('❌ OutletProvider: Error loading outlets: $_errorMessage');
        debugPrint('═══════════════════════════════════════════════════════════');
        debugPrint('');
      }
    } catch (e) {
      // Unexpected error
      _outlets = [];
      _currentOutlet = null;
      _errorMessage = 'Unexpected error: ${e.toString()}';
      
      debugPrint('❌ OutletProvider: Unexpected error: $e');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');
    } finally {
      // Always clear loading state
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set the current outlet with proper validation and sync
  /// This is the GUARDED version that checks availability and syncs if needed
  /// Returns true if outlet was switched successfully, false if blocked
  /// 
  /// [onReloadComplete] callback is triggered after successful switch to reload providers
  Future<bool> setCurrentOutletWithValidation(
    Outlet? outlet, {
    Function()? onReloadComplete,
  }) async {
    if (outlet == null) {
      debugPrint('⚠️ OutletProvider: Cannot switch - outlet is null');
      return false;
    }
    
    // Don't switch if already on this outlet
    if (_currentOutlet?.id == outlet.id) {
      debugPrint('🏪 OutletProvider: Already on outlet ${outlet.name}');
      return true;
    }

    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🏪 OutletProvider: OUTLET SWITCH REQUESTED');
    debugPrint('   From: ${_currentOutlet?.name ?? "None"} (${_currentOutlet?.id ?? "null"})');
    debugPrint('   To: ${outlet.name} (${outlet.id})');
    debugPrint('═══════════════════════════════════════════════════════════');

    _isSwitching = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: Validate the switch
      debugPrint('');
      debugPrint('📋 STEP 1: Validating outlet switch...');
      final validation = await _availabilityService.validateOutletSwitch(
        _currentOutlet?.id ?? '',
        outlet.id,
      );

      debugPrint('   Can switch: ${validation.canSwitch}');
      debugPrint('   Requires sync: ${validation.requiresSync}');
      debugPrint('   Reason: ${validation.reason}');

      if (!validation.canSwitch) {
        // Switch blocked (offline and outlet not available)
        _errorMessage = validation.reason;
        _isSwitching = false;
        notifyListeners();
        
        debugPrint('');
        debugPrint('❌ OUTLET SWITCH BLOCKED: ${validation.reason}');
        debugPrint('═══════════════════════════════════════════════════════════');
        debugPrint('');
        return false;
      }

      // Step 2: Prepare outlet if sync required (online mode)
      if (validation.requiresSync) {
        debugPrint('');
        debugPrint('🔄 STEP 2: Preparing outlet (full mirror sync + validation)...');
        debugPrint('   This mirrors the SAME flow used during startup sync');
        
        if (!kIsWeb) {
          final syncSuccess = await _syncOrchestrator.prepareOutletForUse(
            outlet.id,
            context: 'OUTLET_SWITCH',
          );
          
          if (!syncSuccess) {
            _errorMessage = 'Failed to prepare outlet for use. Please check your connection and try again.';
            _isSwitching = false;
            notifyListeners();
            
            debugPrint('');
            debugPrint('❌ OUTLET PREPARATION FAILED - SWITCH ABORTED');
            debugPrint('═══════════════════════════════════════════════════════════');
            debugPrint('');
            return false;
          }
          
          debugPrint('');
          debugPrint('✅ STEP 2 COMPLETE: Outlet fully prepared and validated');
        }
      } else {
        debugPrint('');
        debugPrint('ℹ️ STEP 2: Skipped (outlet already available locally)');
      }

      // Step 3: Commit the switch (only after successful preparation)
      debugPrint('');
      debugPrint('💾 STEP 3: Committing outlet switch...');
      await _commitOutletSwitch(outlet, onReloadComplete: onReloadComplete);
      
      debugPrint('');
      debugPrint('✅ OUTLET SWITCH COMPLETED SUCCESSFULLY');
      debugPrint('   New outlet: ${outlet.name} (${outlet.id})');
      debugPrint('   Providers will now reload from local mirror');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');
      return true;

    } catch (e, stackTrace) {
      _errorMessage = 'Failed to switch outlet: $e';
      debugPrint('');
      debugPrint('❌ OUTLET SWITCH EXCEPTION: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');
      return false;
    } finally {
      _isSwitching = false;
      notifyListeners();
    }
  }

  /// Internal method to commit the outlet switch after validation and sync
  Future<void> _commitOutletSwitch(Outlet outlet, {Function()? onReloadComplete}) async {
    _currentOutlet = outlet;
    
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🏪 OutletProvider: Committing outlet switch');
    debugPrint('   Outlet ID: ${outlet.id}');
    debugPrint('   Outlet Name: ${outlet.name}');
    debugPrint('   Service Charge Enabled: ${outlet.enableServiceCharge}');
    debugPrint('   Service Charge Percent: ${outlet.serviceChargePercent}%');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('');
    
    // Save last selected outlet for startup content sync
    await LocalStorageService().saveLastSelectedOutletId(outlet.id);
    
    // Load settings for this outlet
    await loadSettingsForCurrentOutlet();
    
    notifyListeners();
    
    // Trigger provider reload callback if provided
    if (onReloadComplete != null) {
      debugPrint('🔄 OutletProvider: Triggering provider reload for outlet switch');
      onReloadComplete();
    }
  }

  /// Legacy method for backward compatibility (used during initial load)
  /// Does NOT perform validation or sync - only use during app startup
  @Deprecated('Use setCurrentOutletWithValidation for outlet switching')
  Future<void> setCurrentOutlet(Outlet? outlet) async {
    if (outlet != null) {
      await _commitOutletSwitch(outlet);
    }
  }

  /// Load settings for the current outlet
  Future<void> loadSettingsForCurrentOutlet() async {
    if (_currentOutlet == null) {
      debugPrint('⚠️ OutletProvider: Cannot load settings, no current outlet');
      return;
    }

    debugPrint('⚙️ OutletProvider: Loading settings');
    debugPrint('   Outlet ID: ${_currentOutlet!.id}');
    debugPrint('   Outlet Name: ${_currentOutlet!.name}');
    
    final result = await _settingsService.getSettingsForOutlet(_currentOutlet!.id);
    
    if (result.isSuccess && result.data != null) {
      _currentSettings = result.data;
      debugPrint('✅ OutletProvider: Settings loaded successfully for ${_currentOutlet!.name}');
    } else {
      debugPrint('⚠️ OutletProvider: Failed to load settings for ${_currentOutlet!.name}: ${result.error}');
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
