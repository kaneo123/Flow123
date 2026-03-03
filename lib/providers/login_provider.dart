import 'package:flutter/foundation.dart';
import 'package:flowtill/services/staff_service.dart';
import 'package:flowtill/models/staff.dart';

/// ViewModel for staff login screen with PIN entry
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

  /// Login with PIN - called automatically when 4 digits entered
  Future<bool> loginWithPin(String outletId) async {
    if (_pin.length != 4) {
      _errorMessage = 'PIN must be exactly 4 digits';
      _triggerShake();
      return false;
    }

    _isLoading = true;
    _errorMessage = '';
    _authenticatedStaff = null;
    notifyListeners();

    try {
      debugPrint('🔐 LoginProvider: Authenticating PIN: $_pin for outlet: $outletId');
      
      final result = await _staffService.authenticateStaff(_pin, outletId);
      
      _isLoading = false;
      
      if (result.isSuccess && result.data != null) {
        // Success - store authenticated staff
        _authenticatedStaff = result.data;
        debugPrint('✅ LoginProvider: Authentication successful for ${_authenticatedStaff!.fullName}');
        notifyListeners();
        return true;
      } else {
        // Invalid PIN - clear PIN and show error
        debugPrint('❌ LoginProvider: Authentication failed - ${result.error}');
        _errorMessage = 'Incorrect PIN, please try again';
        _pin = ''; // Clear PIN buffer
        _triggerShake();
        return false;
      }
    } catch (e) {
      debugPrint('❌ LoginProvider: Error validating PIN: $e');
      _isLoading = false;
      _errorMessage = 'Error validating PIN. Please try again.';
      _pin = ''; // Clear PIN buffer
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

  /// Set error message manually
  void setError(String message) {
    _errorMessage = message;
    _triggerShake();
  }
}
