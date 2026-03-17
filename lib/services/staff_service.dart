import 'package:flutter/foundation.dart';
import 'package:flowtill/models/staff.dart' as models;
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/services/outlet_service.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/supabase/supabase_config.dart';

/// Service for staff authentication and management
/// Handles the new many-to-many staff-outlet relationship via staff_outlets table
class StaffService {
  final AppDatabase _db = AppDatabase.instance;

  /// Authenticate staff with PIN for a specific outlet
  /// ALWAYS requires an outletId to verify staff_outlets access
  Future<ServiceResult<models.Staff>> authenticateStaff(String pin, String outletId) async {
    debugPrint('🔐 StaffService: Authenticating staff for outlet: $outletId');
    
    if (kIsWeb) {
      return _authenticateStaffOnline(pin, outletId);
    }

    final connectionService = ConnectionService();
    final isOnline = connectionService.isOnline;

    if (isOnline) {
      return _authenticateStaffOnline(pin, outletId);
    } else {
      return _authenticateStaffOffline(pin, outletId);
    }
  }

  /// Online authentication with outlet verification
  Future<ServiceResult<models.Staff>> _authenticateStaffOnline(String pin, String outletId) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'authenticate-staff',
        body: {
          'pin': pin,
          'outletId': outletId,
        },
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['message'] as String? ?? 'Authentication failed';
        debugPrint('❌ StaffService: $errorMessage');
        return ServiceResult.failure(errorMessage);
      }

      final data = response.data as Map<String, dynamic>;
      final success = data['success'] as bool? ?? false;

      if (!success) {
        final errorMessage = data['message'] as String? ?? 'Authentication failed';
        debugPrint('❌ StaffService: $errorMessage');
        return ServiceResult.failure(errorMessage);
      }

      // Extract staff data
      final staffData = data['staff'] as Map<String, dynamic>;
      final staffId = staffData['id'] as String;
      final staffName = staffData['name'] as String;
      final associatedOutletIds = (staffData['associatedOutletIds'] as List).cast<String>();
      final roleId = staffData['roleId'] as String?;
      final permissionLevel = staffData['permissionLevel'] as int? ?? 1;

      debugPrint('✅ StaffService: Authentication successful for $staffName');
      debugPrint('   - Outlet: $outletId');
      debugPrint('   - Role ID: $roleId');
      debugPrint('   - Permission Level: $permissionLevel');

      // Create Staff object with outlet context
      final staff = models.Staff(
        id: staffId,
        fullName: staffName,
        roleId: roleId,
        permissionLevel: permissionLevel,
        pinCode: pin,
        outletId: outletId,
        active: true,
        createdAt: DateTime.now(),
        associatedOutletIds: associatedOutletIds,
      );

      // Cache to local DB for offline access (on mobile/desktop only)
      if (!kIsWeb) {
        try {
          await _db.insertStaffList([{
            'id': staff.id,
            'full_name': staff.fullName,
            'pin_code': staff.pinCode,
            'active': staff.active ? 1 : 0,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
            'associated_outlets': associatedOutletIds.join(','),
            'role_id': roleId,
            'permission_level': permissionLevel,
          }]);
          debugPrint('💾 StaffService: Cached staff authentication data');
        } catch (e) {
          debugPrint('⚠️ StaffService: Failed to cache staff (non-fatal): $e');
        }
      }

      return ServiceResult.success(staff);
    } catch (e) {
      debugPrint('❌ StaffService: Authentication error: $e');
      return ServiceResult.failure('Authentication failed: ${e.toString()}');
    }
  }

  /// Offline authentication from local cache
  Future<ServiceResult<models.Staff>> _authenticateStaffOffline(String pin, String outletId) async {
    try {
      final result = await _db.getStaffByPin(pin);
      
      if (result == null) {
        debugPrint('❌ StaffService: Invalid PIN (offline)');
        return ServiceResult.failure('Invalid PIN');
      }

      final staff = _mapToModel(result);
      
      if (!staff.active) {
        debugPrint('❌ StaffService: Staff member is inactive');
        return ServiceResult.failure('Staff member is inactive');
      }

      // Check outlet association from cached data
      final associatedOutlets = result['associated_outlets'] as String?;
      if (associatedOutlets == null || associatedOutlets.isEmpty) {
        debugPrint('⚠️ StaffService: No outlet associations cached (offline). Allowing access.');
        return ServiceResult.success(staff.copyWith(outletId: outletId));
      }

      final outletIds = associatedOutlets.split(',');
      if (!outletIds.contains(outletId)) {
        debugPrint('❌ StaffService: Staff member is not associated with this outlet (offline)');
        return ServiceResult.failure('You do not have access to this outlet');
      }

      debugPrint('✅ StaffService: Authentication successful (offline) for ${staff.fullName}');
      return ServiceResult.success(staff.copyWith(
        outletId: outletId,
        associatedOutletIds: outletIds,
        roleId: result['role_id'] as String?,
        permissionLevel: result['permission_level'] as int?,
      ));
    } catch (e) {
      debugPrint('❌ StaffService: Offline authentication error: $e');
      return ServiceResult.failure('Authentication failed: ${e.toString()}');
    }
  }

  /// Convert database map to Staff model
  models.Staff _mapToModel(Map<String, dynamic> map) {
    final associatedOutlets = map['associated_outlets'] as String?;
    final outletIds = associatedOutlets?.split(',').where((s) => s.isNotEmpty).toList();
    
    return models.Staff(
      id: map['id'] as String,
      outletId: outletIds?.firstOrNull,
      fullName: map['full_name'] as String,
      pinCode: map['pin_code'] as String,
      active: (map['active'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      associatedOutletIds: outletIds,
      roleId: map['role_id'] as String?,
      permissionLevel: map['permission_level'] as int?,
    );
  }

  // Backwards compatibility method (deprecated)
  @Deprecated('Use authenticateStaff instead')
  Future<ServiceResult<List<models.Staff>>> getActiveStaff(String outletId) async {
    return ServiceResult.failure('Method not supported. Use authenticateStaff instead.');
  }

  @Deprecated('Use authenticateStaff instead')
  Future<ServiceResult<List<models.Staff>>> getStaffByOutlet(String outletId) async {
    return ServiceResult.failure('Method not supported. Use authenticateStaff instead.');
  }

  // Not supported in Till mode
  Future<ServiceResult<models.Staff>> createStaff({
    required String name,
    required String pin,
    required String outletId,
  }) async {
    return ServiceResult.failure('Staff creation is not supported in Till mode. Use BackOffice.');
  }

  Future<ServiceResult<models.Staff>> updateStaff(String id, Map<String, dynamic> updates) async {
    return ServiceResult.failure('Staff updates are not supported in Till mode. Use BackOffice.');
  }

  Future<ServiceResult<void>> deleteStaff(String id) async {
    return ServiceResult.failure('Staff deletion is not supported in Till mode. Use BackOffice.');
  }
}
