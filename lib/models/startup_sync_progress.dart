/// Progress model for startup content sync orchestration
class StartupSyncProgress {
  final String currentStepLabel;
  final int percentComplete; // 0-100
  final bool isRunning;
  final bool isComplete;
  final String? errorMessage;

  const StartupSyncProgress({
    required this.currentStepLabel,
    required this.percentComplete,
    required this.isRunning,
    required this.isComplete,
    this.errorMessage,
  });

  /// Initial state
  factory StartupSyncProgress.initial() => const StartupSyncProgress(
    currentStepLabel: 'Preparing...',
    percentComplete: 0,
    isRunning: false,
    isComplete: false,
  );

  /// Copy with helper
  StartupSyncProgress copyWith({
    String? currentStepLabel,
    int? percentComplete,
    bool? isRunning,
    bool? isComplete,
    String? errorMessage,
  }) => StartupSyncProgress(
    currentStepLabel: currentStepLabel ?? this.currentStepLabel,
    percentComplete: percentComplete ?? this.percentComplete,
    isRunning: isRunning ?? this.isRunning,
    isComplete: isComplete ?? this.isComplete,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}
