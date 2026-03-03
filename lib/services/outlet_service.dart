import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flowtill/models/outlet.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/services/connection_service.dart';

/// Service for outlet data operations
class OutletService {
  final AppDatabase _db = AppDatabase.instance;
  final ConnectionService _connectionService = ConnectionService();

  /// Get all active outlets (online-first: checks connectivity, not platform)
  /// Returns a result with outlets or error message
  /// Falls back to local DB when offline or if Supabase fails
  Future<ServiceResult<List<Outlet>>> getAllOutlets() async {
    // Web platform: Always try Supabase (connectivity check is unreliable on web)
    // Mobile/Desktop: Check connectivity before attempting Supabase
    if (kIsWeb || _connectionService.isOnline) {
      debugPrint('🌐 ${kIsWeb ? "Web platform" : "Online"} - fetching outlets from Supabase');
      final supabaseResult = await _getAllOutletsFromSupabase();
      
      // If successful and not on web, sync to local DB for offline use
      if (supabaseResult.isSuccess && !kIsWeb) {
        debugPrint('🔄 Triggering background sync to populate local DB');
        _syncOutletsToLocalDB(supabaseResult.data!).catchError((e) {
          debugPrint('⚠️ Background sync failed: $e');
        });
      }
      
      // If Supabase succeeds, return immediately
      if (supabaseResult.isSuccess) {
        return supabaseResult;
      }
      
      // On web, if Supabase fails, return the error directly (no local DB fallback)
      if (kIsWeb) {
        return supabaseResult;
      }
      
      debugPrint('⚠️ Supabase failed, falling back to local DB');
    }
    
    // Offline mode or Supabase failed: use local DB (only on mobile/desktop)
    if (!kIsWeb) {
      return _getAllOutletsFromLocalDB();
    }
    
    // Web and offline: cannot use local DB
    return ServiceResult.failure('No internet connection. Please check your network.');
  }

  /// Get all active outlets from Supabase (when online)
  Future<ServiceResult<List<Outlet>>> _getAllOutletsFromSupabase() async {
    debugPrint('🏪 OutletService: Fetching all outlets (from Supabase - ONLINE)');

    final result = await SupabaseService.select(
      'outlets',
      filters: {'active': true},
      orderBy: 'name',
    );

    if (!result.isSuccess) {
      debugPrint('❌ OutletService: Failed to fetch outlets');
      return ServiceResult.failure(result.error ?? 'Unknown error');
    }

    if (result.data == null || result.data!.isEmpty) {
      debugPrint('⚠️ OutletService: No active outlets found');
      return ServiceResult.failure('No active outlets found. Please add outlets via Supabase panel.');
    }

    try {
      final outlets = <Outlet>[];
      for (var i = 0; i < result.data!.length; i++) {
        try {
          final json = result.data![i];
          debugPrint('   Parsing outlet $i: ${json['name'] ?? 'Unknown'}');
          final outlet = Outlet.fromJson(json);
          outlets.add(outlet);
        } catch (e) {
          debugPrint('⚠️ OutletService: Skipping invalid outlet at index $i: $e');
          debugPrint('   Raw JSON: ${result.data![i]}');
          // Continue parsing other outlets instead of failing completely
        }
      }
      
      if (outlets.isEmpty && result.data!.isNotEmpty) {
        return ServiceResult.failure('All outlet records failed to parse. Check logs for details.');
      }
      
      debugPrint('✅ OutletService: ${outlets.length} outlets loaded successfully');
      return ServiceResult.success(outlets);
    } catch (e) {
      debugPrint('❌ OutletService: Failed to parse outlet data: $e');
      return ServiceResult.failure('Failed to parse outlet data: ${e.toString()}');
    }
  }

  /// Get all active outlets from local database (when offline)
  Future<ServiceResult<List<Outlet>>> _getAllOutletsFromLocalDB() async {
    debugPrint('🏪 OutletService: Fetching all outlets (from local DB - OFFLINE)');

    try {
      final localOutlets = await _db.getAllOutlets();

      if (localOutlets.isEmpty) {
        debugPrint('⚠️ OutletService: No active outlets found in local DB');
        return ServiceResult.failure('No outlets found. Please sync data when online.');
      }

      final outlets = localOutlets.map((json) {
        // Parse settings from JSON string if needed
        Map<String, dynamic>? settings;
        if (json['settings'] != null) {
          final settingsStr = json['settings'] as String;
          try {
            settings = Map<String, dynamic>.from(jsonDecode(settingsStr) as Map);
          } catch (e) {
            debugPrint('⚠️ Failed to parse outlet settings: $e');
          }
        }

        // Reconstruct the full outlet JSON from local DB format
        return Outlet(
          id: json['id'] as String,
          name: json['name'] as String,
          code: json['code'] as String?,
          active: (json['active'] as int) == 1,
          settings: settings,
          enableServiceCharge: (json['enable_service_charge'] as int) == 1,
          serviceChargePercent: (json['service_charge_percent'] as num).toDouble(),
          createdAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
        );
      }).toList();

      debugPrint('✅ OutletService: ${outlets.length} outlets loaded from local DB');
      return ServiceResult.success(outlets);
    } catch (e) {
      debugPrint('❌ OutletService: Failed to load outlets from local DB: $e');
      return ServiceResult.failure('Failed to load outlets: ${e.toString()}');
    }
  }

  /// Sync outlets to local database (background task)
  Future<void> _syncOutletsToLocalDB(List<Outlet> outlets) async {
    try {
      debugPrint('💾 Syncing ${outlets.length} outlets to local DB');
      final db = await _db.database;
      final batch = db.batch();
      
      for (final outlet in outlets) {
        batch.insert(
          'outlets',
          {
            'id': outlet.id,
            'name': outlet.name,
            'code': outlet.code,
            'active': outlet.active ? 1 : 0,
            'settings': outlet.settings != null ? jsonEncode(outlet.settings) : null,
            'enable_service_charge': outlet.enableServiceCharge ? 1 : 0,
            'service_charge_percent': outlet.serviceChargePercent,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit(noResult: true);
      debugPrint('✅ Outlets synced to local DB successfully');
    } catch (e) {
      debugPrint('❌ Failed to sync outlets to local DB: $e');
      rethrow;
    }
  }

  /// Get outlet by ID
  Future<ServiceResult<Outlet>> getOutletById(String id) async {
    debugPrint('🏪 OutletService: Fetching outlet by id: $id');

    final result = await SupabaseService.selectSingle(
      'outlets',
      filters: {'id': id},
    );

    if (!result.isSuccess) {
      return ServiceResult.failure(result.error ?? 'Unknown error');
    }

    if (result.data == null) {
      return ServiceResult.failure('Outlet not found');
    }

    try {
      final outlet = Outlet.fromJson(result.data!);
      return ServiceResult.success(outlet);
    } catch (e) {
      return ServiceResult.failure('Failed to parse outlet: ${e.toString()}');
    }
  }

  /// Create a new outlet
  Future<ServiceResult<Outlet>> createOutlet({
    required String name,
    String? code,
    String? addressLine1,
    String? addressLine2,
    String? town,
    String? postcode,
    String? phone,
    Map<String, dynamic>? settings,
  }) async {
    debugPrint('🏪 OutletService: Creating outlet: $name');

    final data = <String, dynamic>{
      'name': name,
      'active': true,
    };
    
    // Only add optional fields if they're not null
    if (code != null) data['code'] = code;
    if (addressLine1 != null) data['address_line1'] = addressLine1;
    if (addressLine2 != null) data['address_line2'] = addressLine2;
    if (town != null) data['town'] = town;
    if (postcode != null) data['postcode'] = postcode;
    if (phone != null) data['phone'] = phone;
    if (settings != null) data['settings'] = settings;

    final result = await SupabaseService.insert('outlets', data);

    if (!result.isSuccess) {
      return ServiceResult.failure(result.error ?? 'Failed to create outlet');
    }

    if (result.data == null || result.data!.isEmpty) {
      return ServiceResult.failure('No data returned after creating outlet');
    }

    try {
      final outlet = Outlet.fromJson(result.data!.first);
      debugPrint('✅ OutletService: Outlet created successfully');
      return ServiceResult.success(outlet);
    } catch (e) {
      return ServiceResult.failure('Failed to parse created outlet: ${e.toString()}');
    }
  }

  /// Update an existing outlet
  Future<ServiceResult<Outlet>> updateOutlet(
    String id,
    Map<String, dynamic> updates,
  ) async {
    debugPrint('🏪 OutletService: Updating outlet: $id');
    debugPrint('   Updates to apply: $updates');

    final result = await SupabaseService.update(
      'outlets',
      updates,
      filters: {'id': id},
    );

    debugPrint('   Supabase result isSuccess: ${result.isSuccess}');
    debugPrint('   Supabase result data: ${result.data}');
    debugPrint('   Supabase result error: ${result.error}');

    if (!result.isSuccess) {
      debugPrint('   ❌ Update failed: ${result.error}');
      return ServiceResult.failure(result.error ?? 'Failed to update outlet');
    }

    if (result.data == null || result.data!.isEmpty) {
      debugPrint('   ❌ No data returned from update');
      return ServiceResult.failure('Outlet not found or no changes made');
    }

    try {
      debugPrint('   📝 Parsing updated outlet from response...');
      final outlet = Outlet.fromJson(result.data!.first);
      debugPrint('✅ OutletService: Outlet updated successfully');
      debugPrint('   Updated outlet enableServiceCharge: ${outlet.enableServiceCharge}');
      debugPrint('   Updated outlet serviceChargePercent: ${outlet.serviceChargePercent}');
      return ServiceResult.success(outlet);
    } catch (e) {
      debugPrint('   ❌ Failed to parse: $e');
      return ServiceResult.failure('Failed to parse updated outlet: ${e.toString()}');
    }
  }

  /// Delete an outlet (soft delete by setting is_active to false)
  Future<ServiceResult<void>> deleteOutlet(String id) async {
    debugPrint('🏪 OutletService: Deleting outlet: $id');

    final result = await SupabaseService.update(
      'outlets',
      {'active': false},
      filters: {'id': id},
    );

    if (!result.isSuccess) {
      return ServiceResult.failure(result.error ?? 'Failed to delete outlet');
    }

    debugPrint('✅ OutletService: Outlet deleted successfully');
    return ServiceResult.success(null);
  }
}

/// Result wrapper for service operations
class ServiceResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ServiceResult.success(this.data)
      : error = null,
        isSuccess = true;

  ServiceResult.failure(this.error)
      : data = null,
        isSuccess = false;
}
