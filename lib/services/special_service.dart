import 'package:flutter/foundation.dart';
import 'package:flowtill/models/special_group.dart';
import 'package:flowtill/models/special_group_item.dart';
import 'package:flowtill/supabase/supabase_config.dart';

class ServiceResult<T> {
  final bool isSuccess;
  final T? data;
  final String? error;

  ServiceResult.success(this.data) : isSuccess = true, error = null;
  ServiceResult.error(this.error) : isSuccess = false, data = null;
}

class SpecialService {
  final _supabase = SupabaseConfig.client;

  /// Fetch all active special groups for an outlet that should show on till
  Future<ServiceResult<List<SpecialGroup>>> getSpecialGroupsForOutlet(String outletId) async {
    try {
      debugPrint('🌟 SpecialService: Fetching special groups for outlet: $outletId');
      
      final response = await _supabase
          .from('special_groups')
          .select()
          .eq('outlet_id', outletId)
          .eq('active', true)
          .eq('show_on_till', true)
          .order('sort_order', ascending: true);

      final groups = (response as List<dynamic>)
          .map((json) => SpecialGroup.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('✅ SpecialService: Loaded ${groups.length} special groups');
      return ServiceResult.success(groups);
    } catch (e, stackTrace) {
      debugPrint('❌ SpecialService: Failed to fetch special groups');
      debugPrint('   Error: $e');
      debugPrint('   Stack: $stackTrace');
      return ServiceResult.error('Failed to load specials: ${e.toString()}');
    }
  }

  /// Fetch all active special group items for given special group IDs
  Future<ServiceResult<List<SpecialGroupItem>>> getSpecialGroupItems(List<String> groupIds) async {
    if (groupIds.isEmpty) {
      return ServiceResult.success([]);
    }

    try {
      debugPrint('🌟 SpecialService: Fetching items for ${groupIds.length} special groups');
      
      final response = await _supabase
          .from('special_group_items')
          .select()
          .inFilter('special_group_id', groupIds)
          .eq('active', true)
          .order('sort_order', ascending: true);

      final items = (response as List<dynamic>)
          .map((json) => SpecialGroupItem.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('✅ SpecialService: Loaded ${items.length} special group items');
      return ServiceResult.success(items);
    } catch (e, stackTrace) {
      debugPrint('❌ SpecialService: Failed to fetch special group items');
      debugPrint('   Error: $e');
      debugPrint('   Stack: $stackTrace');
      return ServiceResult.error('Failed to load special items: ${e.toString()}');
    }
  }
}
