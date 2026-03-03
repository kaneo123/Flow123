import 'package:flutter/foundation.dart';
import 'package:flowtill/models/staff.dart' as models;
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/services/outlet_service.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/supabase/supabase_config.dart';

class StaffService {
  final AppDatabase _db = AppDatabase.instance;

  /// Convert Supabase JSON to Model Staff
  models.Staff _fromSupabaseJson(Map<String, dynamic> json) {
    return models.Staff(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      fullName: json['full_name'] as String,
      pinCode: json['pin_code'] as String,
      active: json['active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert database map to Model Staff
  models.Staff _mapToModel(Map<String, dynamic> map) {
    final associatedOutlets = map['associated_outlets'] as String?;
    final outletIds = associatedOutlets?.split(',').where((s) => s.isNotEmpty).toList();
    
    return models.Staff(
      id: map['id'] as String,
      outletId: outletIds?.firstOrNull ?? '', // Use first associated outlet as default
      fullName: map['name'] as String,
      pinCode: map['pin'] as String,
      active: (map['active'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      associatedOutletIds: outletIds,
      roleId: map['role_id'] as String?,
      permissionLevel: map['permission_level'] as int?,
    );
  }

  Future<ServiceResult<List<models.Staff>>> getActiveStaff(String outletId) async {
    // On web, always use Supabase (web apps are typically always online)
    if (kIsWeb) {
      debugPrint('👤 StaffService: Fetching active staff for outlet: $outletId (from Supabase - Web)');
      try {
        final response = await SupabaseConfig.client
            .from('staff')
            .select()
            .eq('outlet_id', outletId)
            .eq('active', true);

        final staff = (response as List).map((json) => _fromSupabaseJson(json)).toList();
        debugPrint('✅ StaffService: ${staff.length} active staff loaded from Supabase');
        return ServiceResult.success(staff);
      } catch (e) {
        debugPrint('❌ StaffService error: $e');
        return ServiceResult.failure('Failed to fetch staff: ${e.toString()}');
      }
    }

    // On mobile/desktop: Try Supabase first if online, fall back to local DB if offline
    final connectionService = ConnectionService();
    final isOnline = connectionService.isOnline;

    if (isOnline) {
      debugPrint('👤 StaffService: Device is ONLINE - Fetching staff from Supabase (source of truth)');
      try {
        final response = await SupabaseConfig.client
            .from('staff')
            .select()
            .eq('outlet_id', outletId)
            .eq('active', true);

        final staff = (response as List).map((json) => _fromSupabaseJson(json)).toList();
        
        // Cache to local DB for offline access (on mobile/desktop only)
        try {
          final staffMaps = staff.map((s) => {
            'id': s.id,
            'name': s.fullName,
            'pin': s.pinCode,
            'active': s.active ? 1 : 0,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          }).toList();
          await _db.insertStaffList(staffMaps);
          debugPrint('💾 StaffService: Cached ${staff.length} staff to local DB for offline access');
        } catch (e) {
          debugPrint('⚠️ StaffService: Failed to cache staff (non-fatal): $e');
        }
        
        debugPrint('✅ StaffService: ${staff.length} active staff loaded from Supabase');
        return ServiceResult.success(staff);
      } catch (e) {
        debugPrint('⚠️ StaffService: Supabase fetch failed, falling back to local DB: $e');
        // Fall through to local DB check below
      }
    }

    // Offline mode OR Supabase failed: Use local SQLite
    debugPrint('👤 StaffService: Fetching active staff from local DB (offline mode)');
    try {
      final results = await _db.getAllActiveStaff();
      final staff = results.map(_mapToModel).toList();
      
      debugPrint('✅ StaffService: ${staff.length} active staff loaded from local DB');
      return ServiceResult.success(staff);
    } catch (e) {
      debugPrint('❌ StaffService error: $e');
      return ServiceResult.failure('Failed to fetch staff: ${e.toString()}');
    }
  }

  Future<ServiceResult<models.Staff>> verifyPin(String pin) async {
    // On web, always use Supabase
    if (kIsWeb) {
      debugPrint('🔐 StaffService: Verifying PIN (from Supabase - Web)');
      try {
        final response = await SupabaseConfig.client
            .from('staff')
            .select()
            .eq('pin_code', pin)
            .eq('active', true)
            .maybeSingle();

        if (response == null) {
          debugPrint('❌ StaffService: Invalid PIN');
          return ServiceResult.failure('Invalid PIN');
        }

        final staff = _fromSupabaseJson(response);
        debugPrint('✅ StaffService: PIN verified for ${staff.fullName}');
        return ServiceResult.success(staff);
      } catch (e) {
        debugPrint('❌ StaffService error: $e');
        return ServiceResult.failure('Failed to verify PIN: ${e.toString()}');
      }
    }

    // On mobile/desktop: Try Supabase first if online, fall back to local DB if offline
    final connectionService = ConnectionService();
    final isOnline = connectionService.isOnline;

    if (isOnline) {
      debugPrint('🔐 StaffService: Device is ONLINE - Verifying PIN from Supabase (source of truth)');
      try {
        final response = await SupabaseConfig.client
            .from('staff')
            .select()
            .eq('pin_code', pin)
            .eq('active', true)
            .maybeSingle();

        if (response == null) {
          debugPrint('❌ StaffService: Invalid PIN (checked Supabase)');
          return ServiceResult.failure('Invalid PIN');
        }

        final staff = _fromSupabaseJson(response);
        
        // Cache to local DB for offline access (on mobile/desktop only)
        try {
          await _db.insertStaffList([{
            'id': staff.id,
            'name': staff.fullName,
            'pin': staff.pinCode,
            'active': staff.active ? 1 : 0,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          }]);
          debugPrint('💾 StaffService: Cached staff to local DB for offline access');
        } catch (e) {
          debugPrint('⚠️ StaffService: Failed to cache staff (non-fatal): $e');
        }
        
        debugPrint('✅ StaffService: PIN verified for ${staff.fullName} (from Supabase)');
        return ServiceResult.success(staff);
      } catch (e) {
        debugPrint('⚠️ StaffService: Supabase verification failed, falling back to local DB: $e');
        // Fall through to local DB check below
      }
    }

    // Offline mode OR Supabase failed: Use local SQLite
    debugPrint('🔐 StaffService: Verifying PIN from local DB (offline mode)');
    try {
      final result = await _db.getStaffByPin(pin);
      
      if (result == null) {
        debugPrint('❌ StaffService: Invalid PIN');
        return ServiceResult.failure('Invalid PIN');
      }
      
      final staff = _mapToModel(result);
      
      if (!staff.active) {
        debugPrint('❌ StaffService: Staff member is inactive');
        return ServiceResult.failure('Staff member is inactive');
      }
      
      debugPrint('✅ StaffService: PIN verified for ${staff.fullName} (from local DB)');
      return ServiceResult.success(staff);
    } catch (e) {
      debugPrint('❌ StaffService error: $e');
      return ServiceResult.failure('Failed to verify PIN: ${e.toString()}');
    }
  }

  // Backwards compatibility methods for providers
  Future<ServiceResult<List<models.Staff>>> getStaffByOutlet(String outletId) async {
    return getActiveStaff(outletId);
  }

  /// Authenticate staff with PIN and validate outlet association
  /// This is the SECURE method that checks staff_outlets table
  Future<ServiceResult<models.Staff>> authenticateStaff(String pin, String outletId) async {
    // On web, always use Supabase
    if (kIsWeb) {
      return _authenticateStaffOnline(pin, outletId);
    }

    // On mobile/desktop: Try Supabase first if online, fall back to local DB if offline
    final connectionService = ConnectionService();
    final isOnline = connectionService.isOnline;

    if (isOnline) {
      return _authenticateStaffOnline(pin, outletId);
    } else {
      return _authenticateStaffOffline(pin, outletId);
    }
  }

  /// Online authentication: Verify PIN + outlet association using Edge Function
  /// Edge Function uses service role to bypass RLS policies
  Future<ServiceResult<models.Staff>> _authenticateStaffOnline(String pin, String outletId) async {
    debugPrint('🔐 StaffService: Authenticating staff with PIN for outlet: $outletId (ONLINE via Edge Function)');
    
    try {
      // Call the authenticate-staff edge function
      final response = await SupabaseConfig.client.functions.invoke(
        'authenticate-staff',
        body: {
          'pin': pin,
          'outletId': outletId,
        },
      );

      // Check for HTTP errors
      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['message'] as String? ?? 'Authentication failed';
        debugPrint('❌ StaffService: Edge function error (${response.status}): $errorMessage');
        return ServiceResult.failure(errorMessage);
      }

      // Parse response
      final data = response.data as Map<String, dynamic>;
      final success = data['success'] as bool? ?? false;

      if (!success) {
        final errorMessage = data['message'] as String? ?? 'Authentication failed';
        debugPrint('❌ StaffService: $errorMessage');
        return ServiceResult.failure(errorMessage);
      }

      // Extract staff data from response
      final staffData = data['staff'] as Map<String, dynamic>;
      final staffId = staffData['id'] as String;
      final staffName = staffData['name'] as String;
      final associatedOutletIds = (staffData['associatedOutletIds'] as List).cast<String>();
      final roleId = staffData['roleId'] as String?;
      final permissionLevel = staffData['permissionLevel'] as int? ?? 1;

      debugPrint('✅ StaffService: Authentication successful for $staffName');
      debugPrint('   - Permission Level: $permissionLevel');
      debugPrint('   - Associated Outlets: ${associatedOutletIds.length}');

      // Create Staff object with all data
      final staff = models.Staff(
        id: staffId,
        fullName: staffName,
        roleId: roleId,
        permissionLevel: permissionLevel,
        pinCode: pin,
        outletId: outletId,
        active: true,
        createdAt: DateTime.now(), // Use current time since edge function doesn't return created_at
        associatedOutletIds: associatedOutletIds,
      );

      // Cache to local DB for offline access (on mobile/desktop only)
      if (!kIsWeb) {
        try {
          await _db.insertStaffList([{
            'id': staff.id,
            'name': staff.fullName,
            'pin': staff.pinCode,
            'active': staff.active ? 1 : 0,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
            'associated_outlets': associatedOutletIds.join(','),
            'role_id': roleId,
            'permission_level': permissionLevel,
          }]);
          debugPrint('💾 StaffService: Cached staff authentication data for offline access');
        } catch (e) {
          debugPrint('⚠️ StaffService: Failed to cache staff (non-fatal): $e');
        }
      }

      return ServiceResult.success(staff);
      
    } catch (e) {
      debugPrint('❌ StaffService authentication error: $e');
      return ServiceResult.failure('Authentication failed: ${e.toString()}');
    }
  }

  /// Offline authentication: Verify PIN + outlet association from local DB
  Future<ServiceResult<models.Staff>> _authenticateStaffOffline(String pin, String outletId) async {
    debugPrint('🔐 StaffService: Authenticating staff with PIN for outlet: $outletId (OFFLINE)');
    
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
      debugPrint('❌ StaffService offline authentication error: $e');
      return ServiceResult.failure('Authentication failed: ${e.toString()}');
    }
  }

  // Note: Create/Update/Delete methods are not used by Till - these are BackOffice operations

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
