import 'package:flutter/foundation.dart';
import 'package:flowtill/models/outlet_settings.dart';
import 'package:flowtill/services/outlet_service.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/config/sync_config.dart';

/// Service for outlet settings operations
class OutletSettingsService {
  final AppDatabase _db = AppDatabase.instance;

  /// Get settings for a specific outlet (local-first when flag enabled)
  Future<ServiceResult<OutletSettings>> getSettingsForOutlet(String outletId) async {
    debugPrint('⚙️ OutletSettingsService: Fetching settings for outlet: $outletId');

    // Step 3: LOCAL MIRROR FIRST (when feature flag is enabled)
    if (kUseLocalMirrorReads && !kIsWeb) {
      debugPrint('[LOCAL_MIRROR] OutletSettingsService: Trying local mirror first');
      
      final localResult = await _getSettingsFromLocalMirror(outletId);
      if (localResult.isSuccess) {
        debugPrint('[LOCAL_MIRROR] ✅ Using local data for outlet_settings (source=local)');
        return localResult;
      }
      
      debugPrint('[LOCAL_MIRROR] Local data unavailable, falling back to Supabase for outlet_settings');
    }

    // Original Supabase logic
    final result = await SupabaseService.selectSingle(
      'outlet_settings',
      filters: {'outlet_id': outletId},
    );

    if (!result.isSuccess) {
      // If settings don't exist, create default settings
      if (result.error?.contains('No data found') == true || result.data == null) {
        debugPrint('⚙️ OutletSettingsService: No settings found, creating defaults (source=supabase)');
        return await createDefaultSettings(outletId);
      }
      return ServiceResult.failure(result.error ?? 'Unknown error');
    }

    try {
      final settings = OutletSettings.fromJson(result.data!);
      debugPrint('✅ OutletSettingsService: Settings loaded successfully (source=supabase)');
      return ServiceResult.success(settings);
    } catch (e) {
      debugPrint('❌ OutletSettingsService: Failed to parse settings: $e');
      return ServiceResult.failure('Failed to parse settings: ${e.toString()}');
    }
  }

  /// Get settings from local mirror table
  Future<ServiceResult<OutletSettings>> _getSettingsFromLocalMirror(String outletId) async {
    debugPrint('  📂 Reading from local mirror table: outlet_settings');

    try {
      final db = await _db.database;
      final results = await db.query(
        'outlet_settings',
        where: 'outlet_id = ?',
        whereArgs: [outletId],
        limit: 1,
      );

      if (results.isEmpty) {
        debugPrint('  ⚠️ Local mirror table empty for outlet_id: $outletId');
        return ServiceResult.failure('Local mirror table empty');
      }

      final json = results.first;
      final settings = OutletSettings.fromJson(json);
      debugPrint('  ✅ Local mirror has outlet_settings');
      return ServiceResult.success(settings);
    } catch (e) {
      debugPrint('  ❌ Failed to read from local mirror: $e');
      return ServiceResult.failure('Failed to read local mirror: ${e.toString()}');
    }
  }

  /// Create default settings for an outlet
  Future<ServiceResult<OutletSettings>> createDefaultSettings(String outletId) async {
    debugPrint('⚙️ OutletSettingsService: Creating default settings for outlet: $outletId');

    final data = {
      'outlet_id': outletId,
      'print_order_tickets_on_order_away': true,
      'order_ticket_copies': 1,
    };

    final result = await SupabaseService.insert('outlet_settings', data);

    if (!result.isSuccess) {
      return ServiceResult.failure(result.error ?? 'Failed to create settings');
    }

    if (result.data == null || result.data!.isEmpty) {
      return ServiceResult.failure('No data returned after creating settings');
    }

    try {
      final settings = OutletSettings.fromJson(result.data!.first);
      debugPrint('✅ OutletSettingsService: Default settings created');
      return ServiceResult.success(settings);
    } catch (e) {
      return ServiceResult.failure('Failed to parse created settings: ${e.toString()}');
    }
  }

  /// Update outlet settings (uses UPSERT logic)
  Future<ServiceResult<OutletSettings>> updateSettings(
    String outletId,
    Map<String, dynamic> updates,
  ) async {
    debugPrint('⚙️ OutletSettingsService: Updating settings for outlet: $outletId');

    // Clamp order_ticket_copies if present
    if (updates.containsKey('order_ticket_copies')) {
      final copies = updates['order_ticket_copies'];
      if (copies is int) {
        updates['order_ticket_copies'] = copies.clamp(1, 5);
      }
    }

    // Fetch current settings first to avoid overwriting unspecified fields
    final currentResult = await getSettingsForOutlet(outletId);
    
    // If no current settings exist, create defaults first
    if (!currentResult.isSuccess || currentResult.data == null) {
      debugPrint('⚠️ OutletSettingsService: No existing settings found, creating defaults first');
      await createDefaultSettings(outletId);
    }

    try {
      // Update only the specified fields, ensuring updated_at is set
      final updateData = Map<String, dynamic>.from(updates);
      updateData['updated_at'] = DateTime.now().toIso8601String();
      
      final response = await SupabaseConfig.client
          .from('outlet_settings')
          .update(updateData)
          .eq('outlet_id', outletId)
          .select()
          .single();

      final settings = OutletSettings.fromJson(response);
      debugPrint('✅ OutletSettingsService: Settings updated successfully');
      return ServiceResult.success(settings);
    } catch (e) {
      debugPrint('❌ OutletSettingsService: Failed to update settings: $e');
      return ServiceResult.failure('Failed to update settings: ${e.toString()}');
    }
  }

}
