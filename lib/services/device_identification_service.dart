import 'package:flutter/foundation.dart';
import 'package:flowtill/services/local_storage_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:universal_io/io.dart';

/// Service for generating and managing unique device identifiers
/// Each device gets a unique ID that persists across app restarts
class DeviceIdentificationService {
  DeviceIdentificationService._();
  static final DeviceIdentificationService instance = DeviceIdentificationService._();

  final LocalStorageService _storage = LocalStorageService();
  static const String _deviceIdKey = 'device_unique_id';
  static const String _deviceNameKey = 'device_friendly_name';

  String? _cachedDeviceId;
  String? _cachedDeviceName;

  /// Get the unique device ID (generates one if it doesn't exist)
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    // Check if we already have a device ID stored
    final existingId = _storage.getString(_deviceIdKey);
    if (existingId != null && existingId.isNotEmpty) {
      _cachedDeviceId = existingId;
      debugPrint('📱 Device ID loaded: $_cachedDeviceId');
      return _cachedDeviceId!;
    }

    // Generate a new device ID
    final newId = await _generateDeviceId();
    await _storage.saveString(_deviceIdKey, newId);
    _cachedDeviceId = newId;
    
    debugPrint('📱 New device ID generated: $_cachedDeviceId');
    return _cachedDeviceId!;
  }

  /// Get a friendly device name (for display purposes)
  Future<String> getDeviceName() async {
    if (_cachedDeviceName != null) {
      return _cachedDeviceName!;
    }

    // Check if we have a stored device name
    final existingName = _storage.getString(_deviceNameKey);
    if (existingName != null && existingName.isNotEmpty) {
      _cachedDeviceName = existingName;
      return _cachedDeviceName!;
    }

    // Generate a device name based on platform
    final newName = await _generateDeviceName();
    await _storage.saveString(_deviceNameKey, newName);
    _cachedDeviceName = newName;
    
    debugPrint('📱 Device name: $_cachedDeviceName');
    return _cachedDeviceName!;
  }

  /// Set a custom friendly name for this device
  Future<void> setDeviceName(String name) async {
    await _storage.saveString(_deviceNameKey, name);
    _cachedDeviceName = name;
    debugPrint('📱 Device name updated: $name');
  }

  /// Generate a unique device ID using device information
  Future<String> _generateDeviceId() async {
    if (kIsWeb) {
      // For web, use a random UUID stored in local storage
      return 'web_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Use Android ID which is unique per device and app combination
        return 'android_${androidInfo.id}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Use identifierForVendor which is unique per device and vendor
        return 'ios_${iosInfo.identifierForVendor ?? _generateRandomString(16)}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        // Use computer name + machine ID
        return 'windows_${windowsInfo.computerName}_${windowsInfo.deviceId}';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        // Use machine ID
        return 'linux_${linuxInfo.machineId ?? _generateRandomString(16)}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        // Use system UUID
        return 'macos_${macInfo.systemGUID ?? _generateRandomString(16)}';
      }
    } catch (e) {
      debugPrint('⚠️ Failed to get device info: $e');
    }

    // Fallback: generate a random UUID
    return 'device_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(12)}';
  }

  /// Generate a friendly device name
  Future<String> _generateDeviceName() async {
    if (kIsWeb) {
      return 'Web Browser';
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} (${iosInfo.model})';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return windowsInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return linuxInfo.prettyName;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return macInfo.computerName;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to get device name: $e');
    }

    return 'Unknown Device';
  }

  /// Generate a random string for fallback IDs
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (index) {
      final seed = random + index;
      return chars[seed % chars.length];
    }).join();
  }

  /// Clear device ID (for testing purposes)
  Future<void> clearDeviceId() async {
    await _storage.prefs.remove(_deviceIdKey);
    await _storage.prefs.remove(_deviceNameKey);
    _cachedDeviceId = null;
    _cachedDeviceName = null;
    debugPrint('📱 Device ID cleared');
  }
}
