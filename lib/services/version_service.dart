import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:flowtill/models/app_version.dart';

class VersionService {
  static const String _lastCheckKey = 'last_version_check';
  static const int _checkIntervalHours = 24;

  /// Get current platform string
  String getPlatform() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'windows';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'unknown';
  }

  /// Check if version check is needed (24-hour interval)
  Future<bool> shouldCheckVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString(_lastCheckKey);
      if (lastCheck == null) return true;

      final lastCheckTime = DateTime.parse(lastCheck);
      final hoursSinceCheck = DateTime.now().difference(lastCheckTime).inHours;
      return hoursSinceCheck >= _checkIntervalHours;
    } catch (e) {
      debugPrint('❌ VersionService: Error checking last version check: $e');
      return true; // Default to checking if there's an error
    }
  }

  /// Save last version check timestamp
  Future<void> saveLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('❌ VersionService: Error saving last check time: $e');
    }
  }

  /// Fetch version info from Supabase
  Future<AppVersion?> fetchVersionInfo() async {
    try {
      final platform = getPlatform();
      debugPrint('🔍 VersionService: Checking version for platform: $platform');

      final response = await SupabaseConfig.client
          .from('app_versions')
          .select()
          .eq('platform', platform)
          .maybeSingle();

      if (response == null) {
        debugPrint('⚠️ VersionService: No version info found for $platform');
        return null;
      }

      return AppVersion.fromJson(response);
    } catch (e) {
      debugPrint('❌ VersionService: Error fetching version info: $e');
      return null;
    }
  }

  /// Check if current version meets requirements
  Future<VersionCheckResult> checkVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = packageInfo.buildNumber;
      final currentFullVersion = '$currentVersion+$currentBuild';

      debugPrint('📱 VersionService: Current version: $currentFullVersion');

      final versionInfo = await fetchVersionInfo();
      if (versionInfo == null) {
        // No version info found - allow app to continue
        debugPrint('✅ VersionService: No version check available, allowing app to continue');
        return VersionCheckResult(isUpToDate: true, requiresUpdate: false);
      }

      final isUpToDate = _compareVersions(currentFullVersion, versionInfo.latestVersion) >= 0;
      final meetsMinimum = _compareVersions(currentFullVersion, versionInfo.minimumVersion) >= 0;

      debugPrint('📊 VersionService: Latest: ${versionInfo.latestVersion}, Minimum: ${versionInfo.minimumVersion}');
      debugPrint('📊 VersionService: Up to date: $isUpToDate, Meets minimum: $meetsMinimum');

      return VersionCheckResult(
        isUpToDate: isUpToDate,
        requiresUpdate: !meetsMinimum,
        latestVersion: versionInfo.latestVersion,
        releaseNotes: versionInfo.releaseNotes,
      );
    } catch (e) {
      debugPrint('❌ VersionService: Error checking version: $e');
      // On error, allow app to continue
      return VersionCheckResult(isUpToDate: true, requiresUpdate: false);
    }
  }

  /// Compare two version strings (format: "1.2.3+45")
  /// Returns: 1 if v1 > v2, -1 if v1 < v2, 0 if equal
  int _compareVersions(String v1, String v2) {
    try {
      debugPrint('🔍 VersionService: Comparing versions - v1: "$v1", v2: "$v2"');
      
      // Handle empty or null versions
      if (v1.isEmpty || v2.isEmpty) {
        debugPrint('⚠️ VersionService: Empty version string detected');
        return 0;
      }

      final v1Parts = v1.split('+');
      final v2Parts = v2.split('+');

      final v1Version = v1Parts[0].split('.');
      final v2Version = v2Parts[0].split('.');

      // Ensure we have at least 3 version parts (major.minor.patch)
      if (v1Version.length < 3 || v2Version.length < 3) {
        debugPrint('⚠️ VersionService: Invalid version format - v1 parts: ${v1Version.length}, v2 parts: ${v2Version.length}');
        return 0;
      }

      // Compare major.minor.patch
      for (int i = 0; i < 3; i++) {
        final v1Num = int.tryParse(v1Version[i]);
        final v2Num = int.tryParse(v2Version[i]);
        
        if (v1Num == null || v2Num == null) {
          debugPrint('⚠️ VersionService: Failed to parse version number at index $i');
          return 0;
        }
        
        if (v1Num > v2Num) {
          debugPrint('✅ VersionService: v1 ($v1) > v2 ($v2)');
          return 1;
        }
        if (v1Num < v2Num) {
          debugPrint('✅ VersionService: v1 ($v1) < v2 ($v2)');
          return -1;
        }
      }

      // If version parts are equal, compare build numbers
      // Treat missing or empty build numbers as 0
      final v1Build = (v1Parts.length > 1 && v1Parts[1].isNotEmpty) 
          ? int.tryParse(v1Parts[1]) ?? 0 
          : 0;
      final v2Build = (v2Parts.length > 1 && v2Parts[1].isNotEmpty) 
          ? int.tryParse(v2Parts[1]) ?? 0 
          : 0;
      
      debugPrint('🔍 VersionService: Build numbers - v1: $v1Build, v2: $v2Build');
      
      if (v1Build > v2Build) {
        debugPrint('✅ VersionService: v1 build ($v1Build) > v2 build ($v2Build)');
        return 1;
      }
      if (v1Build < v2Build) {
        debugPrint('✅ VersionService: v1 build ($v1Build) < v2 build ($v2Build)');
        return -1;
      }

      debugPrint('✅ VersionService: Versions are equal');
      return 0;
    } catch (e, stackTrace) {
      debugPrint('❌ VersionService: Error comparing versions: $e');
      debugPrint('Stack trace: $stackTrace');
      return 0;
    }
  }
}
