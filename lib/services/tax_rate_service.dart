import 'package:flutter/foundation.dart';
import 'package:flowtill/models/tax_rate.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:flowtill/services/outlet_service.dart';

class TaxRateService {
  Future<ServiceResult<List<TaxRate>>> getAllTaxRates() async {
    debugPrint('💰 TaxRateService: Fetching all tax rates');

    final result = await SupabaseService.select('tax_rates', orderBy: 'name');

    if (!result.isSuccess) {
      return ServiceResult.failure(result.error ?? 'Failed to fetch tax rates');
    }

    if (result.data == null) {
      return ServiceResult.success([]);
    }

    try {
      final taxRates = result.data!.map((json) => TaxRate.fromJson(json)).toList();
      debugPrint('✅ TaxRateService: ${taxRates.length} tax rates loaded');
      return ServiceResult.success(taxRates);
    } catch (e) {
      return ServiceResult.failure('Failed to parse tax rates: ${e.toString()}');
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
