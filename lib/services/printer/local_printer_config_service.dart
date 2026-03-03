import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flowtill/services/local_storage_service.dart';
import 'package:flowtill/services/device_identification_service.dart';

/// Device-specific hardware configuration for a printer
/// This is stored locally on each device and never synced to Supabase
class LocalPrinterHardwareConfig {
  final String printerId;        // Links to the logical printer in Supabase
  final String connectionType;   // 'usb' | 'bluetooth' | 'network'
  final String? ipAddress;
  final int? port;
  final String? hardwareVendorId;
  final String? hardwareProductId;
  final String? hardwareAddress;
  final String? hardwareName;
  final DateTime configuredAt;

  LocalPrinterHardwareConfig({
    required this.printerId,
    required this.connectionType,
    this.ipAddress,
    this.port,
    this.hardwareVendorId,
    this.hardwareProductId,
    this.hardwareAddress,
    this.hardwareName,
    DateTime? configuredAt,
  }) : configuredAt = configuredAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'printer_id': printerId,
    'connection_type': connectionType,
    if (ipAddress != null) 'ip_address': ipAddress,
    if (port != null) 'port': port,
    if (hardwareVendorId != null) 'hardware_vendor_id': hardwareVendorId,
    if (hardwareProductId != null) 'hardware_product_id': hardwareProductId,
    if (hardwareAddress != null) 'hardware_address': hardwareAddress,
    if (hardwareName != null) 'hardware_name': hardwareName,
    'configured_at': configuredAt.toIso8601String(),
  };

  factory LocalPrinterHardwareConfig.fromJson(Map<String, dynamic> json) => LocalPrinterHardwareConfig(
    printerId: json['printer_id'] as String,
    connectionType: json['connection_type'] as String,
    ipAddress: json['ip_address'] as String?,
    port: json['port'] as int?,
    hardwareVendorId: json['hardware_vendor_id'] as String?,
    hardwareProductId: json['hardware_product_id'] as String?,
    hardwareAddress: json['hardware_address'] as String?,
    hardwareName: json['hardware_name'] as String?,
    configuredAt: json['configured_at'] != null 
        ? DateTime.parse(json['configured_at'] as String)
        : DateTime.now(),
  );
}

/// Service for managing device-specific printer hardware configurations
/// Each device stores its own hardware mappings locally
class LocalPrinterConfigService {
  LocalPrinterConfigService._();
  static final LocalPrinterConfigService instance = LocalPrinterConfigService._();

  final LocalStorageService _storage = LocalStorageService();
  final DeviceIdentificationService _deviceService = DeviceIdentificationService.instance;

  // Cache of configurations (printerId -> config)
  Map<String, LocalPrinterHardwareConfig> _configCache = {};
  bool _isLoaded = false;

  /// Get the storage key for printer configurations
  Future<String> _getStorageKey() async {
    final deviceId = await _deviceService.getDeviceId();
    return 'printer_hardware_configs_$deviceId';
  }

  /// Load all hardware configurations for this device
  Future<void> loadConfigurations() async {
    try {
      final key = await _getStorageKey();
      final json = _storage.getString(key);
      
      if (json == null || json.isEmpty) {
        debugPrint('🖨️ No local printer configs found for this device');
        _configCache = {};
        _isLoaded = true;
        return;
      }

      final data = jsonDecode(json) as Map<String, dynamic>;
      _configCache = data.map(
        (printerId, configJson) => MapEntry(
          printerId,
          LocalPrinterHardwareConfig.fromJson(configJson as Map<String, dynamic>),
        ),
      );

      debugPrint('🖨️ Loaded ${_configCache.length} local printer configs');
      _isLoaded = true;
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to load printer configs: $e');
      debugPrint('Stack: $stackTrace');
      _configCache = {};
      _isLoaded = true;
    }
  }

  /// Ensure configurations are loaded
  Future<void> _ensureLoaded() async {
    if (!_isLoaded) {
      await loadConfigurations();
    }
  }

  /// Get hardware configuration for a specific printer on this device
  Future<LocalPrinterHardwareConfig?> getConfig(String printerId) async {
    await _ensureLoaded();
    return _configCache[printerId];
  }

  /// Check if a printer has hardware configuration on this device
  Future<bool> hasConfig(String printerId) async {
    await _ensureLoaded();
    return _configCache.containsKey(printerId);
  }

  /// Save hardware configuration for a printer on this device
  Future<void> saveConfig(LocalPrinterHardwareConfig config) async {
    await _ensureLoaded();
    
    _configCache[config.printerId] = config;
    await _persistConfigs();
    
    debugPrint('✅ Saved hardware config for printer ${config.printerId}');
    debugPrint('   Connection: ${config.connectionType}');
    debugPrint('   Hardware: ${config.hardwareName ?? config.ipAddress ?? 'Unknown'}');
  }

  /// Remove hardware configuration for a printer on this device
  Future<void> removeConfig(String printerId) async {
    await _ensureLoaded();
    
    if (_configCache.remove(printerId) != null) {
      await _persistConfigs();
      debugPrint('✅ Removed hardware config for printer $printerId');
    }
  }

  /// Get all configured printers on this device
  Future<List<LocalPrinterHardwareConfig>> getAllConfigs() async {
    await _ensureLoaded();
    return _configCache.values.toList();
  }

  /// Clear all hardware configurations on this device
  Future<void> clearAllConfigs() async {
    _configCache = {};
    await _persistConfigs();
    debugPrint('✅ Cleared all local printer configs');
  }

  /// Persist configurations to local storage
  Future<void> _persistConfigs() async {
    try {
      final key = await _getStorageKey();
      final data = _configCache.map(
        (printerId, config) => MapEntry(printerId, config.toJson()),
      );
      final json = jsonEncode(data);
      await _storage.saveString(key, json);
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to persist printer configs: $e');
      debugPrint('Stack: $stackTrace');
    }
  }

  /// Migrate hardware configs from Supabase to local storage
  /// This is a one-time migration for existing installations
  Future<void> migrateFromSupabase(List<Map<String, dynamic>> supabasePrinters) async {
    await _ensureLoaded();
    
    int migrated = 0;
    for (final printerData in supabasePrinters) {
      final printerId = printerData['id'] as String?;
      final connectionType = printerData['connection_type'] as String?;
      
      if (printerId == null || connectionType == null) continue;
      
      // Skip if already configured locally
      if (_configCache.containsKey(printerId)) {
        debugPrint('   Printer $printerId already has local config, skipping');
        continue;
      }

      // Check if this printer has hardware info in Supabase
      final hasHardwareInfo = 
          (printerData['hardware_name'] != null && (printerData['hardware_name'] as String).isNotEmpty) ||
          (printerData['ip_address'] != null && (printerData['ip_address'] as String).isNotEmpty);

      if (!hasHardwareInfo) {
        debugPrint('   Printer $printerId has no hardware info in Supabase, skipping');
        continue;
      }

      // Migrate to local config
      final config = LocalPrinterHardwareConfig(
        printerId: printerId,
        connectionType: connectionType,
        ipAddress: printerData['ip_address'] as String?,
        port: printerData['port'] as int?,
        hardwareVendorId: printerData['hardware_vendor_id'] as String?,
        hardwareProductId: printerData['hardware_product_id'] as String?,
        hardwareAddress: printerData['hardware_address'] as String?,
        hardwareName: printerData['hardware_name'] as String?,
      );

      _configCache[printerId] = config;
      migrated++;
      debugPrint('   ✓ Migrated printer $printerId');
    }

    if (migrated > 0) {
      await _persistConfigs();
      debugPrint('✅ Migrated $migrated printer configs from Supabase to local storage');
    }
  }

  /// Get device name for display
  Future<String> getDeviceName() async {
    return await _deviceService.getDeviceName();
  }

  /// Get device ID
  Future<String> getDeviceId() async {
    return await _deviceService.getDeviceId();
  }
}
