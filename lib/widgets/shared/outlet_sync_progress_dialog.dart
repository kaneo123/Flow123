import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flowtill/models/startup_sync_progress.dart';
import 'package:flowtill/services/startup_content_sync_orchestrator.dart';

/// Shared dialog for showing outlet sync progress
/// This is a PASSIVE observer that subscribes to the sync orchestrator's progress stream
/// The actual sync is triggered by the caller (e.g., OutletProvider)
class OutletSyncProgressDialog extends StatefulWidget {
  final String title;

  const OutletSyncProgressDialog({
    super.key,
    this.title = 'Preparing Outlet',
  });

  @override
  State<OutletSyncProgressDialog> createState() => _OutletSyncProgressDialogState();
}

class _OutletSyncProgressDialogState extends State<OutletSyncProgressDialog> {
  final StartupContentSyncOrchestrator _syncOrchestrator = StartupContentSyncOrchestrator();
  
  StartupSyncProgress _progress = StartupSyncProgress.initial();
  StreamSubscription<StartupSyncProgress>? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToProgress();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToProgress() {
    // Listen to progress updates from the sync orchestrator
    _progressSubscription = _syncOrchestrator.progressStream.listen((progress) {
      if (!mounted) return;
      setState(() {
        _progress = progress;
      });

      // Auto-close dialog when sync completes (success or failure)
      if (progress.isComplete || progress.errorMessage != null) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.of(context).pop(progress.isComplete && progress.errorMessage == null);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _progress.errorMessage != null;
    
    return PopScope(
      canPop: false, // Prevent dismissal during sync
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Progress indicator
              SizedBox(
                width: 60,
                height: 60,
                child: hasError
                    ? Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Theme.of(context).colorScheme.error,
                      )
                    : _progress.isComplete
                        ? Icon(
                            Icons.check_circle_outline,
                            size: 60,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : CircularProgressIndicator(
                            value: _progress.percentComplete / 100,
                            strokeWidth: 4,
                          ),
              ),
              const SizedBox(height: 16),

              // Progress percentage
              if (!hasError && !_progress.isComplete)
                Text(
                  '${_progress.percentComplete}%',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 8),

              // Status message
              Text(
                hasError
                    ? (_progress.errorMessage ?? 'Sync failed')
                    : _progress.currentStepLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: hasError
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
