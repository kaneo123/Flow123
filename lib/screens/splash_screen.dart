import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flowtill/services/version_service.dart';
import 'package:flowtill/services/local_storage_service.dart';
import 'package:flowtill/services/startup_content_sync_orchestrator.dart';
import 'package:flowtill/services/outlet_service.dart';
import 'package:flowtill/models/app_version.dart';
import 'package:flowtill/models/startup_sync_progress.dart';
import 'package:flowtill/main.dart' show splashShown;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _versionService = VersionService();
  final _startupSyncOrchestrator = StartupContentSyncOrchestrator();
  StreamSubscription<StartupSyncProgress>? _syncProgressSubscription;
  
  String _statusMessage = 'Checking for updates...';
  bool _showRetry = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  
  // Startup content sync state
  bool _isContentSyncing = false;
  StartupSyncProgress? _syncProgress;
  
  static const String _apkDownloadUrl = 'https://rvfrqptzupzupkiojbcy.supabase.co/storage/v1/object/public/app_releases/app-debug.apk';

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 SplashScreen: initState called');
    _performVersionCheck();
  }

  @override
  void dispose() {
    _syncProgressSubscription?.cancel();
    super.dispose();
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

  void _proceedToLogin() async {
    if (!mounted) return;
    
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[STARTUP_SYNC] DETERMINING STARTUP OUTLET');
    debugPrint('═══════════════════════════════════════════════════════════');
    
    // WEB GUARD: Skip mirror sync on web platform (SQLite not available)
    if (kIsWeb) {
      debugPrint('[STARTUP_SYNC] 🌐 WEB PLATFORM DETECTED');
      debugPrint('[STARTUP_SYNC] Skipping mirror content sync (web uses direct Supabase access)');
      debugPrint('[STARTUP_SYNC] Proceeding directly to login');
      _navigateToLogin();
      return;
    }
    
    // STEP 1: Check for saved outlet ID
    String? startupOutletId = LocalStorageService().getLastSelectedOutletId();
    
    if (startupOutletId != null) {
      debugPrint('[STARTUP_SYNC] ✅ Last outlet ID found in LocalStorage');
      debugPrint('[STARTUP_SYNC]    Outlet ID: $startupOutletId');
    } else {
      debugPrint('[STARTUP_SYNC] ℹ️ No saved outlet, need to resolve startup outlet');
      
      // STEP 2: Ensure outlets are available (fetch and cache if needed)
      setState(() {
        _statusMessage = 'Loading outlets...';
      });
      
      startupOutletId = await _ensureOutletsAndGetStartupOutlet();
      
      if (startupOutletId == null) {
        debugPrint('[STARTUP_SYNC] ❌ No outlets available, cannot proceed with content sync');
        debugPrint('[STARTUP_SYNC] Proceeding to login without content sync');
        _navigateToLogin();
        return;
      }
      
      debugPrint('[STARTUP_SYNC] ✅ Startup outlet resolved');
      debugPrint('[STARTUP_SYNC]    Outlet ID: $startupOutletId');
      
      // STEP 3: Save this outlet for future launches
      await LocalStorageService().saveLastSelectedOutletId(startupOutletId);
      debugPrint('[STARTUP_SYNC] ℹ️ Saved startup outlet for future launches');
    }
    
    // STEP 4: Run automatic content sync
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[STARTUP_SYNC] STARTING AUTOMATIC CONTENT MIRROR SYNC');
    debugPrint('[STARTUP_SYNC] Startup Outlet ID: $startupOutletId');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('');
    await _performStartupContentSync(startupOutletId);
  }
  
  /// Ensure outlets are available and return a startup outlet ID
  /// Fetches from Supabase if local mirror is empty
  Future<String?> _ensureOutletsAndGetStartupOutlet() async {
    debugPrint('[STARTUP_SYNC] Ensuring outlets are available...');
    
    try {
      // Import needed for OutletService
      final outletService = OutletService();
      
      // Try to get outlets (will check local mirror first if flag enabled)
      final result = await outletService.getAllOutlets();
      
      if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
        debugPrint('[STARTUP_SYNC] ❌ Failed to fetch outlets: ${result.error}');
        return null;
      }
      
      final outlets = result.data!;
      debugPrint('[STARTUP_SYNC] ✅ ${outlets.length} outlets available');
      
      // Return first outlet ID
      final firstOutlet = outlets.first;
      debugPrint('[STARTUP_SYNC] Selected startup outlet: ${firstOutlet.name} (${firstOutlet.id})');
      return firstOutlet.id;
      
    } catch (e, stackTrace) {
      debugPrint('[STARTUP_SYNC] ❌ Error ensuring outlets: $e');
      debugPrint('Stack: $stackTrace');
      return null;
    }
  }

  Future<void> _performStartupContentSync(String outletId) async {
    if (!mounted) return;
    
    setState(() {
      _isContentSyncing = true;
      _statusMessage = 'Preparing content sync...';
      _syncProgress = StartupSyncProgress.initial();
    });

    // Listen to sync progress
    _syncProgressSubscription = _startupSyncOrchestrator.progressStream.listen((progress) {
      if (!mounted) return;
      setState(() {
        _syncProgress = progress;
        _statusMessage = progress.currentStepLabel;
      });
    });

    try {
      // Run startup content sync using the universal prepareOutletForUse method
      final success = await _startupSyncOrchestrator.prepareOutletForUse(
        outletId,
        context: 'STARTUP_SYNC',
      );
      
      if (!mounted) return;
      
      if (success) {
        debugPrint('✅ SplashScreen: Startup content sync completed successfully');
        _navigateToLogin();
      } else {
        debugPrint('⚠️ SplashScreen: Startup content sync failed, but proceeding to login');
        // Show error briefly but still proceed
        setState(() {
          _statusMessage = 'Sync incomplete, continuing...';
          _showRetry = false;
        });
        await Future.delayed(const Duration(seconds: 1));
        _navigateToLogin();
      }
    } catch (e) {
      debugPrint('❌ SplashScreen: Error during startup content sync: $e');
      if (!mounted) return;
      
      // Show error with retry option
      setState(() {
        _statusMessage = 'Content sync failed';
        _showRetry = true;
        _isContentSyncing = false;
      });
    } finally {
      _syncProgressSubscription?.cancel();
    }
  }

  void _navigateToLogin() {
    if (!mounted) return;
    
    debugPrint('➡️ SplashScreen: Navigating to login screen');
    setState(() {
      _statusMessage = 'Loading...';
      _isContentSyncing = false;
    });
    
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
                // Show progress bar if content syncing
                if (_isContentSyncing && _syncProgress != null) ...[
                  Container(
                    width: 300,
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _syncProgress!.percentComplete / 100,
                          backgroundColor: Colors.grey[300],
                          color: const Color(0xFF40E0D0),
                          minHeight: 6,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${_syncProgress!.percentComplete}%',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const CircularProgressIndicator(color: Color(0xFF40E0D0)),
                ],
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
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
