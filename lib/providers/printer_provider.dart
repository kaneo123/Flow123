import 'package:flutter/foundation.dart';

/// Provider for managing printer state (deprecated - use PrinterService.instance instead)
/// Kept for backward compatibility to avoid breaking existing provider registrations
class PrinterProvider extends ChangeNotifier {
  // This provider is no longer used.
  // All printer functionality has been moved to PrinterService.instance
  // which loads printers from Supabase and manages them directly.
  
  PrinterProvider() {
    debugPrint('⚠️ PrinterProvider is deprecated. Use PrinterService.instance instead.');
  }
}
