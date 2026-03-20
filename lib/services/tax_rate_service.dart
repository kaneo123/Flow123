import 'package:flutter/foundation.dart';
import 'package:flowtill/models/tax_rate.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:flowtill/services/outlet_service.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/config/sync_config.dart';

class TaxRateService {
  final AppDatabase _db = AppDatabase.instance;
  final ConnectionService _connectionService = ConnectionService();

  /// Check if we should use local-only mode (native + offline)
  bool get _shouldUseLocalOnly => !kIsWeb && !_connectionService.isOnline;

  Future<ServiceResult<List<TaxRate>>> getAllTaxRates() async {
    debugPrint('💰 TaxRateService: Fetching all tax rates');

    // Step 3: LOCAL MIRROR FIRST (when feature flag is enabled)
    if (kUseLocalMirrorReads && !kIsWeb) {
      debugPrint('[LOCAL_MIRROR] TaxRateService: Trying local mirror first');
      
      final localResult = await _getTaxRatesFromLocalMirror();
      if (localResult.isSuccess && localResult.data != null && localResult.data!.isNotEmpty) {
        debugPrint('[LOCAL_MIRROR] ✅ Using local data for tax_rates (${localResult.data!.length} records, source=local)');
        return localResult;
      }
      
      if (_shouldUseLocalOnly) {
        // Offline on native: Return empty list instead of Supabase fallback
        debugPrint('[LOCAL_MIRROR] ⚠️ Offline mode - local data empty, returning empty list (no Supabase fallback)');
        return ServiceResult.success([]);
      }
      
      debugPrint('[LOCAL_MIRROR] Local data unavailable, falling back to Supabase for tax_rates');
    }

    // Original Supabase logic (online or web)
    final result = await SupabaseService.select('tax_rates', orderBy: 'name');

    if (!result.isSuccess) {
      return ServiceResult.failure(result.error ?? 'Failed to fetch tax rates');
    }

    if (result.data == null) {
      return ServiceResult.success([]);
    }

    try {
      final taxRates = result.data!.map((json) => TaxRate.fromJson(json)).toList();
      debugPrint('✅ TaxRateService: ${taxRates.length} tax rates loaded (source=supabase)');
      return ServiceResult.success(taxRates);
    } catch (e) {
      return ServiceResult.failure('Failed to parse tax rates: ${e.toString()}');
    }
  }

  /// Get tax rates from local mirror table
  Future<ServiceResult<List<TaxRate>>> _getTaxRatesFromLocalMirror() async {
    debugPrint('  📂 Reading from local mirror table: tax_rates');

    try {
      final db = await _db.database;
      final results = await db.query('tax_rates', orderBy: 'name');

      if (results.isEmpty) {
        debugPrint('  ⚠️ Local mirror table empty: tax_rates');
        return ServiceResult.failure('Local mirror table empty');
      }

      final taxRates = results.map((json) => TaxRate.fromJson(json)).toList();
      debugPrint('  ✅ Local mirror has ${taxRates.length} tax rates');
      return ServiceResult.success(taxRates);
    } catch (e) {
      debugPrint('  ❌ Failed to read from local mirror: $e');
      return ServiceResult.failure('Failed to read local mirror: ${e.toString()}');
    }
  }

  Future<ServiceResult<TaxRate>> getTaxRateById(String id) async {
    final result = await SupabaseService.selectSingle('tax_rates', filters: {'id': id});

    if (!result.isSuccess) {
      return ServiceResult.failure(result.error ?? 'Failed to fetch tax rate');
    }

    if (result.data == null) {
      return ServiceResult.failure('Tax rate not found');
    }

    try {
      final taxRate = TaxRate.fromJson(result.data!);
      return ServiceResult.success(taxRate);
    } catch (e) {
      return ServiceResult.failure('Failed to parse tax rate: ${e.toString()}');
    }
  }

  Future<ServiceResult<TaxRate>> getDefaultTaxRate() async {
    final result = await SupabaseService.selectSingle('tax_rates', filters: {'is_default': true});

    if (result.isSuccess && result.data != null) {
      try {
        return ServiceResult.success(TaxRate.fromJson(result.data!));
      } catch (e) {
        return ServiceResult.failure('Failed to parse tax rate: ${e.toString()}');
      }
    }

    // If no default, get first available
    final allRates = await getAllTaxRates();
    if (allRates.isSuccess && allRates.data != null && allRates.data!.isNotEmpty) {
      return ServiceResult.success(allRates.data!.first);
    }

    return ServiceResult.failure('No tax rates available');
  }

  Future<ServiceResult<TaxRate>> createTaxRate({
    required String name,
    required double rate,
    bool isDefault = false,
  }) async {
    final result = await SupabaseService.insert('tax_rates', {
      'name': name,
      'rate': rate,
      'is_default': isDefault,
    });

    if (!result.isSuccess) {
      return ServiceResult.failure(result.error ?? 'Failed to create tax rate');
    }

    if (result.data == null || result.data!.isEmpty) {
      return ServiceResult.failure('No data returned');
    }

    try {
      final taxRate = TaxRate.fromJson(result.data!.first);
      return ServiceResult.success(taxRate);
    } catch (e) {
      return ServiceResult.failure('Failed to parse created tax rate: ${e.toString()}');
    }
  }

  Future<ServiceResult<TaxRate>> updateTaxRate(String id, Map<String, dynamic> updates) async {
    final result = await SupabaseService.update('tax_rates', updates, filters: {'id': id});

    if (!result.isSuccess) {
      return ServiceResult.failure(result.error ?? 'Failed to update tax rate');
    }

    if (result.data == null || result.data!.isEmpty) {
      return ServiceResult.failure('Tax rate not found');
    }

    try {
      final taxRate = TaxRate.fromJson(result.data!.first);
      return ServiceResult.success(taxRate);
    } catch (e) {
      return ServiceResult.failure('Failed to parse updated tax rate: ${e.toString()}');
    }
  }

  Future<ServiceResult<void>> deleteTaxRate(String id) async {
    final result = await SupabaseService.delete('tax_rates', filters: {'id': id});
    
    if (!result.isSuccess) {
      return ServiceResult.failure(result.error ?? 'Failed to delete tax rate');
    }

    return ServiceResult.success(null);
  }
}
