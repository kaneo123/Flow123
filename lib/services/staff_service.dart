import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
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
          // Get local staff table columns to filter data safely
          final db = await _db.database;
          final localColumns = await _getLocalTableColumns(db, 'staff');
          
          // Prepare staff data for caching
          final staffData = {
            'id': staff.id,
            'full_name': staff.fullName,
            'pin_code': staff.pinCode,
            'active': staff.active ? 1 : 0,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
            'associated_outlets': associatedOutletIds.join(','),
            'role_id': roleId,
            'permission_level': permissionLevel,
            'outlet_id': outletId, // For legacy compatibility
          };
          
          // Filter to only include columns that exist in local table
          final filteredData = <String, dynamic>{};
          for (final entry in staffData.entries) {
            if (localColumns.contains(entry.key)) {
              filteredData[entry.key] = entry.value;
            } else {
              debugPrint('   ℹ️ Skipping column ${entry.key} (not in local staff table)');
            }
          }
          
          await _db.insertStaffList([filteredData]);
          debugPrint('💾 StaffService: Cached staff authentication data (${filteredData.length} columns)');
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
  /// Uses staff_outlets junction table for association-based auth
  /// Falls back to legacy staff.outlet_id for compatibility
  Future<ServiceResult<models.Staff>> _authenticateStaffOffline(String pin, String outletId) async {
    debugPrint('[OFFLINE_AUTH] entered outlet: $outletId');
    
    try {
      // Step A: Query local staff by PIN and active flag
      final staffRow = await _db.getStaffByPin(pin);
      
      if (staffRow == null) {
        debugPrint('[OFFLINE_AUTH] final result = failure (invalid PIN)');
        return ServiceResult.failure('Invalid PIN');
      }

      final staffId = staffRow['id'] as String;
      final fullName = staffRow['full_name'] as String;
      final pinCode = staffRow['pin_code'] as String;
      final active = (staffRow['active'] as int? ?? 0) == 1;
      
      debugPrint('[OFFLINE_AUTH] matched local staff: $fullName / $staffId');
      
      if (!active) {
        debugPrint('[OFFLINE_AUTH] final result = failure (staff inactive)');
        return ServiceResult.failure('Staff member is inactive');
      }

      // Step B: Query local staff_outlets for association
      final staffOutletRow = await _db.getStaffOutletByStaffAndOutlet(staffId, outletId);
      
      debugPrint('[OFFLINE_AUTH] local staff_outlets rows found: ${staffOutletRow != null ? 1 : 0}');
      
      if (staffOutletRow != null) {
        // Association found - use staff_outlets.role_id
        debugPrint('[OFFLINE_AUTH] association match found');
        
        final roleId = staffOutletRow['role_id'] as String?;
        debugPrint('[OFFLINE_AUTH] role source = staff_outlets.role_id');
        
        final staff = models.Staff(
          id: staffId,
          fullName: fullName,
          pinCode: pinCode,
          active: active,
          outletId: outletId,
          roleId: roleId,
          createdAt: DateTime.now(),
          associatedOutletIds: [outletId],
        );
        
        debugPrint('[OFFLINE_AUTH] final result = success (via staff_outlets)');
        return ServiceResult.success(staff);
      }
      
      // Step C: Fallback to legacy staff.outlet_id for compatibility
      debugPrint('[OFFLINE_AUTH] falling back to legacy staff.outlet_id');
      
      final legacyOutletId = staffRow['outlet_id'] as String?;
      
      if (legacyOutletId != null && legacyOutletId == outletId) {
        debugPrint('[OFFLINE_AUTH] legacy match success');
        
        final roleId = staffRow['role_id'] as String?;
        debugPrint('[OFFLINE_AUTH] role source = staff.role_id');
        
        final staff = models.Staff(
          id: staffId,
          fullName: fullName,
          pinCode: pinCode,
          active: active,
          outletId: outletId,
          roleId: roleId,
          createdAt: DateTime.now(),
          associatedOutletIds: [outletId],
        );
        
        debugPrint('[OFFLINE_AUTH] final result = success (via legacy staff.outlet_id)');
        return ServiceResult.success(staff);
      }
      
      // Step D: No association found
      debugPrint('[OFFLINE_AUTH] legacy match failure');
      debugPrint('[OFFLINE_AUTH] final result = failure (no outlet access)');
      return ServiceResult.failure('No offline access for this outlet');
      
    } catch (e, stackTrace) {
      debugPrint('[OFFLINE_AUTH] final result = failure (exception)');
      debugPrint('❌ StaffService: Offline authentication error: $e');
      debugPrint('Stack: $stackTrace');
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

  /// Get list of column names for a local table (for safe schema-agnostic inserts)
  Future<Set<String>> _getLocalTableColumns(Database db, String tableName) async {
    try {
      final result = await db.rawQuery('PRAGMA table_info($tableName)');
      final columns = <String>{};
      for (final row in result) {
        final columnName = row['name'] as String;
        columns.add(columnName);
      }
      return columns;
    } catch (e) {
      debugPrint('⚠️ StaffService: Failed to get columns for $tableName: $e');
      return {};
    }
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
