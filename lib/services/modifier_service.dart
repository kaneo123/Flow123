import 'package:flutter/foundation.dart';
import 'package:flowtill/models/modifier_group.dart';
import 'package:flowtill/models/modifier_option.dart';
import 'package:flowtill/models/product_modifier_group_link.dart';
import 'package:flowtill/supabase/supabase_config.dart';

/// Rules for a specific modifier group with overrides applied
class ModifierGroupRules {
  final ModifierGroup group;
  final bool isRequired;
  final int? minSelect;
  final int? maxSelect;
  final int linkSortOrder;

  ModifierGroupRules({
    required this.group,
    required this.isRequired,
    required this.minSelect,
    required this.maxSelect,
    required this.linkSortOrder,
  });

  String get displayRules {
    if (group.selectionType == 'single') {
      return isRequired ? 'Choose 1 (Required)' : 'Choose 1';
    } else {
      // Multiple selection
      final min = minSelect ?? 0;
      final max = maxSelect;
      
      if (max != null) {
        final required = isRequired ? ' (Required)' : '';
        return 'Choose $min–$max$required';
      } else if (min > 0) {
        return 'Choose at least $min';
      } else {
        return 'Optional';
      }
    }
  }
}

/// Service for managing product modifiers
class ModifierService {
  // Cache maps
  final Map<String, ProductModifierGroupLink> _linksByProductId = {};
  final Map<String, List<ProductModifierGroupLink>> _linksGroupedByProduct = {};
  final Map<String, ModifierGroup> _groupsById = {};
  final Map<String, List<ModifierOption>> _optionsByGroupId = {};
  
  bool _isLoaded = false;

  /// Load all modifier data for an outlet
  Future<bool> loadModifiersForOutlet(String outletId) async {
    try {
      debugPrint('🔧 ModifierService: Loading modifiers for outlet $outletId');

      // 1. Load product_modifier_groups links
      debugPrint('   📋 Querying product_modifier_groups with outlet_id: $outletId');
      final linksResult = await SupabaseService.select(
        'product_modifier_groups',
        filters: {'outlet_id': outletId, 'active': true},
        orderBy: 'sort_order',
        ascending: true,
      );

      if (!linksResult.isSuccess) {
        debugPrint('❌ Failed to load product modifier links: ${linksResult.error}');
        return false;
      }

      final links = linksResult.data!
          .map((json) => ProductModifierGroupLink.fromJson(json))
          .toList();

      debugPrint('   ✅ Loaded ${links.length} product modifier links');
      
      if (links.isEmpty) {
        debugPrint('   ⚠️ WARNING: No product modifier links found for outlet $outletId');
        debugPrint('   ⚠️ Check if your product_modifier_groups table has records with this outlet_id');
      }

      // Build maps
      _linksGroupedByProduct.clear();
      for (final link in links) {
        _linksByProductId[link.id] = link;
        _linksGroupedByProduct.putIfAbsent(link.productId, () => []).add(link);
      }

      // Log sample of product IDs that have modifiers
      if (_linksGroupedByProduct.isNotEmpty) {
        final sampleProducts = _linksGroupedByProduct.keys.take(3).toList();
        debugPrint('   🔍 Sample product IDs with modifiers: $sampleProducts');
        debugPrint('   🔍 Total products with modifiers: ${_linksGroupedByProduct.length}');
        
        // Check for test product specifically
        final testProductId = 'd6f42c99-16c8-4010-9b22-7c897265d2d3';
        if (_linksGroupedByProduct.containsKey(testProductId)) {
          final testLinks = _linksGroupedByProduct[testProductId]!;
          debugPrint('   ✅ Test product $testProductId found with ${testLinks.length} modifier links');
        } else {
          debugPrint('   ❌ Test product $testProductId NOT found in loaded links');
        }
      }

      // 2. Load modifier_groups
      final groupsResult = await SupabaseService.select(
        'modifier_groups',
        filters: {'outlet_id': outletId, 'active': true},
        orderBy: 'sort_order',
        ascending: true,
      );

      if (!groupsResult.isSuccess) {
        debugPrint('❌ Failed to load modifier groups: ${groupsResult.error}');
        return false;
      }

      final groups = groupsResult.data!
          .map((json) => ModifierGroup.fromJson(json))
          .toList();

      debugPrint('   Loaded ${groups.length} modifier groups');

      _groupsById.clear();
      for (final group in groups) {
        _groupsById[group.id] = group;
      }

      // 3. Load modifier_options
      final optionsResult = await SupabaseService.select(
        'modifier_options',
        filters: {'outlet_id': outletId, 'active': true},
        orderBy: 'sort_order',
        ascending: true,
      );

      if (!optionsResult.isSuccess) {
        debugPrint('❌ Failed to load modifier options: ${optionsResult.error}');
        return false;
      }

      final options = optionsResult.data!
          .map((json) => ModifierOption.fromJson(json))
          .toList();

      debugPrint('   Loaded ${options.length} modifier options');

      _optionsByGroupId.clear();
      for (final option in options) {
        _optionsByGroupId.putIfAbsent(option.groupId, () => []).add(option);
      }

      _isLoaded = true;
      debugPrint('✅ ModifierService: All modifiers loaded successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ ModifierService: Error loading modifiers: $e');
      debugPrint('Stack: $stackTrace');
      return false;
    }
  }

  /// Check if modifiers are loaded
  bool get isLoaded => _isLoaded;

  /// Check if a product has modifier groups
  bool hasModifiers(String productId) {
    return _linksGroupedByProduct.containsKey(productId) && 
           _linksGroupedByProduct[productId]!.isNotEmpty;
  }

  /// Get links for a product
  List<ProductModifierGroupLink> getLinksForProduct(String productId) {
    return _linksGroupedByProduct[productId] ?? [];
  }

  /// Get groups for a product (with effective rules applied)
  List<ModifierGroupRules> getGroupsForProduct(String productId) {
    final links = getLinksForProduct(productId);
    final result = <ModifierGroupRules>[];

    for (final link in links) {
      final group = _groupsById[link.groupId];
      if (group == null) continue;

      // Apply overrides
      final effectiveRules = ModifierGroupRules(
        group: group,
        isRequired: link.requiredOverride ?? group.isRequired,
        minSelect: link.minSelectOverride ?? group.minSelect,
        maxSelect: link.maxSelectOverride ?? group.maxSelect,
        linkSortOrder: link.sortOrder,
      );

      result.add(effectiveRules);
    }

    // Sort by link sort_order (already sorted, but ensure)
    result.sort((a, b) => a.linkSortOrder.compareTo(b.linkSortOrder));

    return result;
  }

  /// Get options for a group
  List<ModifierOption> getOptionsForGroup(String groupId) {
    return _optionsByGroupId[groupId] ?? [];
  }

  /// Get default selections for a group
  List<ModifierOption> getDefaultSelections(String groupId, String selectionType) {
    final options = getOptionsForGroup(groupId);
    final defaults = options.where((opt) => opt.isDefault).toList();

    if (defaults.isEmpty) return [];

    // For single selection, return only the first default
    if (selectionType == 'single') {
      return [defaults.first];
    }

    // For multiple, return all defaults
    return defaults;
  }

  /// Get a modifier group by ID
  ModifierGroup? getGroup(String groupId) {
    return _groupsById[groupId];
  }

  /// Get a modifier option by ID
  ModifierOption? getOption(String optionId) {
    for (final options in _optionsByGroupId.values) {
      final option = options.firstWhere(
        (opt) => opt.id == optionId,
        orElse: () => options.first, // Dummy return
      );
      if (option.id == optionId) return option;
    }
    return null;
  }

  /// Clear all cached data
  void clear() {
    _linksByProductId.clear();
    _linksGroupedByProduct.clear();
    _groupsById.clear();
    _optionsByGroupId.clear();
    _isLoaded = false;
    debugPrint('🧹 ModifierService: Cache cleared');
  }
}
