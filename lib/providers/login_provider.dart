import 'package:flutter/foundation.dart';
import 'package:flowtill/services/staff_service.dart';
import 'package:flowtill/models/staff.dart';

/// ViewModel for staff login screen with PIN entry
/// Handles single-step authentication with outlet context
class LoginProvider with ChangeNotifier {
  final StaffService _staffService = StaffService();
  
  String _pin = '';
  String _errorMessage = '';
  bool _isLoading = false;
  bool _shouldShake = false;
  Staff? _authenticatedStaff;
  
  String get pin => _pin;
  String get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get shouldShake => _shouldShake;
  int get pinLength => _pin.length;
  Staff? get authenticatedStaff => _authenticatedStaff;

  /// Add a digit to the PIN (max 4 digits)
  /// Clears error when user starts typing
  void addDigit(String digit) {
    if (_pin.length < 4) {
      _pin += digit;
      _errorMessage = '';
      _shouldShake = false;
      notifyListeners();
    }
  }

  /// Remove the last digit
  void backspace() {
    if (_pin.isNotEmpty) {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = '';
      notifyListeners();
    }
  }

  /// Clear all digits
  void clear() {
    _pin = '';
    _errorMessage = '';
    _shouldShake = false;
    notifyListeners();
  }

  /// Set error message manually
  void setError(String message) {
    _errorMessage = message;
    _pin = '';
    _triggerShake();
  }

  /// Authenticate staff with PIN for a specific outlet
  /// Always requires an outletId to be selected
  Future<bool> authenticateWithPin(String outletId) async {
    if (_pin.length != 4) {
      _errorMessage = 'PIN must be exactly 4 digits';
      _triggerShake();
      return false;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      debugPrint('🔐 LoginProvider: Authenticating staff for outlet: $outletId');
      
      final result = await _staffService.authenticateStaff(_pin, outletId);
      
      _isLoading = false;
      
      if (result.isSuccess && result.data != null) {
        _authenticatedStaff = result.data;
        debugPrint('✅ LoginProvider: Authentication successful');
        notifyListeners();
        return true;
      } else {
        debugPrint('❌ LoginProvider: Authentication failed - ${result.error}');
        _errorMessage = result.error ?? 'Authentication failed';
        _pin = '';
        _triggerShake();
        return false;
      }
    } catch (e) {
      debugPrint('❌ LoginProvider: Error authenticating: $e');
      _isLoading = false;
      _errorMessage = 'Authentication error. Please try again.';
      _pin = '';
      _triggerShake();
      return false;
    }
  }

  /// Trigger shake animation for error feedback
  void _triggerShake() {
    _shouldShake = true;
    notifyListeners();
    
    // Reset shake flag after animation
    Future.delayed(const Duration(milliseconds: 500), () {
      _shouldShake = false;
      notifyListeners();
    });
  }

  /// Reset error state
  void resetError() {
    _errorMessage = '';
    _shouldShake = false;
    notifyListeners();
  }

  /// Clear authenticated staff (logout)
  void clearAuthenticatedStaff() {
    _authenticatedStaff = null;
    _pin = '';
    _errorMessage = '';
    notifyListeners();
  }
}
