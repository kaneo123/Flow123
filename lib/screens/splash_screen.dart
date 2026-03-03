import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flowtill/services/version_service.dart';
import 'package:flowtill/models/app_version.dart';
import 'package:flowtill/main.dart' show splashShown;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _versionService = VersionService();
  String _statusMessage = 'Checking for updates...';
  bool _showRetry = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  
  static const String _apkDownloadUrl = 'https://rvfrqptzupzupkiojbcy.supabase.co/storage/v1/object/public/app_releases/app-debug.apk';

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 SplashScreen: initState called');
    _performVersionCheck();
  }

  Future<void> _performVersionCheck() async {
    debugPrint('🚀 SplashScreen: Starting version check on app load');
    if (!mounted) return;
    
    setState(() {
      _statusMessage = 'Checking for updates...';
      _showRetry = false;
    });

    try {
      // Always check version on initial app load
      debugPrint('🚀 SplashScreen: Performing version check...');
      final result = await _versionService.checkVersion();
      debugPrint('🚀 SplashScreen: Version check result - upToDate: ${result.isUpToDate}, requiresUpdate: ${result.requiresUpdate}');

      if (!mounted) return; // Check mounted after async call

      if (result.requiresUpdate) {
        // FORCED UPDATE - block app usage
        debugPrint('⚠️ SplashScreen: FORCED UPDATE REQUIRED');
        _showForceUpdateDialog(result);
      } else if (!result.isUpToDate) {
        // OPTIONAL UPDATE - show dialog but allow skip
        debugPrint('ℹ️ SplashScreen: Optional update available');
        _showOptionalUpdateDialog(result);
      } else {
        // UP TO DATE - proceed to login
        debugPrint('✅ SplashScreen: App is up to date, proceeding to login');
        _proceedToLogin();
      }
    } catch (e) {
      // On error, show retry option
      debugPrint('❌ SplashScreen: Error during version check: $e');
      if (!mounted) return; // Check mounted before setState
      
      setState(() {
        _statusMessage = 'Unable to check for updates';
        _showRetry = true;
      });
    }
  }

  void _showForceUpdateDialog(VersionCheckResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('Update Required'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A new version (${result.latestVersion}) is available and required to continue.'),
              if (result.releaseNotes != null && result.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('What\'s New:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(result.releaseNotes!, style: const TextStyle(fontSize: 14)),
              ],
              if (_isDownloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _downloadProgress),
                const SizedBox(height: 8),
                Text('Downloading... ${(_downloadProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: _isDownloading ? null : () => _handleUpdateDownload(setState),
              icon: _isDownloading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
              label: Text(_isDownloading ? 'Downloading...' : 'Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionalUpdateDialog(VersionCheckResult result) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 28),
              SizedBox(width: 8),
              Text('Update Available'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A new version (${result.latestVersion}) is available.'),
              if (result.releaseNotes != null && result.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('What\'s New:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(result.releaseNotes!, style: const TextStyle(fontSize: 14)),
              ],
              if (_isDownloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _downloadProgress),
                const SizedBox(height: 8),
                Text('Downloading... ${(_downloadProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
          actions: [
            if (!_isDownloading)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _proceedToLogin();
                },
                child: const Text('Later'),
              ),
            ElevatedButton.icon(
              onPressed: _isDownloading ? null : () => _handleUpdateDownload(setState),
              icon: _isDownloading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
              label: Text(_isDownloading ? 'Downloading...' : 'Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpdateDownload(StateSetter dialogSetState) async {
    if (!kIsWeb && Platform.isAndroid) {
      await _downloadAndInstallApk(dialogSetState);
    } else {
      // For non-Android platforms, show a message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please visit flowtill.com to download the latest version')),
      );
    }
  }

  Future<void> _downloadAndInstallApk(StateSetter dialogSetState) async {
    try {
      debugPrint('📥 Starting APK download from: $_apkDownloadUrl');
      
      dialogSetState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });
      
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      // Get the downloads directory
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/flowtill_update.apk';
      
      debugPrint('📁 Download path: $filePath');

      // Download the APK
      final dio = Dio();
      await dio.download(
        _apkDownloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            debugPrint('📥 Download progress: ${(progress * 100).toStringAsFixed(0)}%');
            dialogSetState(() => _downloadProgress = progress);
            if (mounted) {
              setState(() => _downloadProgress = progress);
            }
          }
        },
      );

      debugPrint('✅ Download completed. Opening APK installer...');
      
      // Open the APK file to trigger installation
      final result = await OpenFilex.open(filePath);
      debugPrint('📦 Install result: ${result.message}');
      
      if (result.type != ResultType.done) {
        throw Exception('Failed to open installer: ${result.message}');
      }

    } catch (e) {
      debugPrint('❌ Error downloading/installing APK: $e');
      if (!mounted) return;
      
      dialogSetState(() => _isDownloading = false);
      setState(() => _isDownloading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  void _proceedToLogin() {
    if (!mounted) return;
    
    debugPrint('➡️ SplashScreen: Proceeding to login screen');
    setState(() => _statusMessage = 'Loading...');
    
    // Mark splash as shown for this session
    splashShown = true;
    
    // Use postFrameCallback to ensure navigation happens after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint('➡️ SplashScreen: Navigating to /login');
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white, // White background
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo / Icon
              SizedBox(
                width: 140,
                height: 140,
                child: Image.asset(
                  'assets/images/flowicon.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              
              // App Name
              const Text(
                'FlowTill',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Point of Sale System',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 48),
              
              // Loading Indicator
              if (!_showRetry) ...[
                const CircularProgressIndicator(color: Color(0xFF40E0D0)),
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ] else ...[
                Icon(Icons.cloud_off, color: Colors.grey[400], size: 48),
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _performVersionCheck,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _proceedToLogin,
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF40E0D0)),
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
