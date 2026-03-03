import 'package:flutter/foundation.dart';
import 'package:flowtill/models/staff.dart';
import 'package:flowtill/services/staff_service.dart';

class StaffProvider with ChangeNotifier {
  final StaffService _staffService = StaffService();
  
  Staff? _currentStaff;
  bool _isLoading = false;

  Staff? get currentStaff => _currentStaff;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentStaff != null;
  
  /// Check if current staff can perform refunds
  /// Staff with permission level 2 or above can refund
  bool get canRefund {
    if (_currentStaff == null) return false;
    try {
      return _currentStaff!.permissionLevel >= 2;
    } catch (e) {
      debugPrint('⚠️ StaffProvider: Error checking permission level: $e');
      debugPrint('   Staff: ${_currentStaff!.fullName}, roleId: ${_currentStaff!.roleId}');
      return false; // Default to no permission if there's an error
    }
  }

  Future<void> loadStaffForOutlet(String outletId) async {
    // Staff data is now loaded from Supabase, no need to seed sample data
    await _staffService.getStaffByOutlet(outletId);
  }

  Future<bool> login(String pinCode, String outletId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _staffService.authenticateStaff(pinCode, outletId);
      if (result.isSuccess && result.data != null) {
        _currentStaff = result.data;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        debugPrint('Login failed: ${result.error}');
      }
    } catch (e) {
      debugPrint('Error during staff login: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Set the current staff directly (useful after PIN authentication)
  void setCurrentStaff(Staff staff) {
    _currentStaff = staff;
    debugPrint('✅ StaffProvider: Current staff set to ${staff.fullName}');
    notifyListeners();
  }

  void logout({Function(String staffId)? onParkOrder}) {
    if (_currentStaff != null) {
      debugPrint('👋 StaffProvider: Logging out ${_currentStaff!.fullName}');
      
      // Call the callback to park the current order for this staff
      if (onParkOrder != null) {
        onParkOrder(_currentStaff!.id);
      }
      
      _currentStaff = null;
      debugPrint('✅ StaffProvider: Logout complete');
    }
    notifyListeners();
  }
}
