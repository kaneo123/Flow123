import 'package:flutter/foundation.dart';
import 'package:flowtill/models/modifier_group.dart';
import 'package:flowtill/models/modifier_option.dart';
import 'package:flowtill/models/product_modifier_group_link.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/config/sync_config.dart';
import 'package:flowtill/services/outlet_service.dart';

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
  final AppDatabase _db = AppDatabase.instance;
  final ConnectionService _connectionService = ConnectionService();

  // Cache maps
  final Map<String, ProductModifierGroupLink> _linksByProductId = {};
  final Map<String, List<ProductModifierGroupLink>> _linksGroupedByProduct = {};
  final Map<String, ModifierGroup> _groupsById = {};
  final Map<String, List<ModifierOption>> _optionsByGroupId = {};
  
  bool _isLoaded = false;

  /// Check if we should use local-only mode (native + offline)
  bool get _shouldUseLocalOnly => !kIsWeb && !_connectionService.isOnline;

  /// Load all modifier data for an outlet (local-first when flag enabled)
  Future<bool> loadModifiersForOutlet(String outletId) async {
    try {
      debugPrint('🔧 ModifierService: Loading modifiers for outlet $outletId');

      List<ProductModifierGroupLink> links = [];
      List<ModifierGroup> groups = [];
      List<ModifierOption> options = [];
      bool usedLocal = false;

      // Step 3: LOCAL MIRROR FIRST (when feature flag is enabled)
      if (kUseLocalMirrorReads && !kIsWeb) {
        debugPrint('[LOCAL_MIRROR] ModifierService: Trying local mirror first');
        
        final localResult = await _loadModifiersFromLocalMirror(outletId);
        if (localResult != null) {
          links = localResult['links'] as List<ProductModifierGroupLink>;
          groups = localResult['groups'] as List<ModifierGroup>;
          options = localResult['options'] as List<ModifierOption>;
          usedLocal = true;
          debugPrint('[LOCAL_MIRROR] ✅ Using local data for modifiers (links=${links.length}, groups=${groups.length}, options=${options.length}, source=local)');
        } else if (_shouldUseLocalOnly) {
          // Offline on native: Do NOT fall back to Supabase
          debugPrint('[LOCAL_MIRROR] ⚠️ Offline mode - local data empty, returning empty result (no Supabase fallback)');
          links = [];
          groups = [];
          options = [];
          usedLocal = true;
        } else {
          debugPrint('[LOCAL_MIRROR] Local data unavailable, falling back to Supabase for modifiers');
        }
      }

      // Load from Supabase if not using local
      if (!usedLocal) {
        // 1. Load product_modifier_groups links
        debugPrint('   📋 Querying product_modifier_groups with outlet_id: $outletId (source=supabase)');
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

        links = linksResult.data!
            .map((json) => ProductModifierGroupLink.fromJson(json))
            .toList();

        debugPrint('   ✅ Loaded ${links.length} product modifier links');

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

        groups = groupsResult.data!
            .map((json) => ModifierGroup.fromJson(json))
            .toList();

        debugPrint('   Loaded ${groups.length} modifier groups');

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

        options = optionsResult.data!
            .map((json) => ModifierOption.fromJson(json))
            .toList();

        debugPrint('   Loaded ${options.length} modifier options');
      }

      // Build cache maps from loaded data
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
      }

      _groupsById.clear();
      for (final group in groups) {
        _groupsById[group.id] = group;
      }

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

  /// Load modifiers from local mirror tables
  Future<Map<String, List<dynamic>>?> _loadModifiersFromLocalMirror(String outletId) async {
    debugPrint('  📂 Reading from local mirror tables: modifier_groups, modifier_options, product_modifier_groups');

    try {
      final db = await _db.database;

      // Load product_modifier_groups links
      final linksResults = await db.query(
        'product_modifier_groups',
        where: 'outlet_id = ? AND active = ?',
        whereArgs: [outletId, 1],
        orderBy: 'sort_order',
      );

      // Load modifier_groups
      final groupsResults = await db.query(
        'modifier_groups',
        where: 'outlet_id = ? AND active = ?',
        whereArgs: [outletId, 1],
        orderBy: 'sort_order',
      );

      // Load modifier_options
      final optionsResults = await db.query(
        'modifier_options',
        where: 'outlet_id = ? AND active = ?',
        whereArgs: [outletId, 1],
        orderBy: 'sort_order',
      );

      // If all empty, return null to trigger fallback
      if (linksResults.isEmpty && groupsResults.isEmpty && optionsResults.isEmpty) {
        debugPrint('  ⚠️ Local mirror tables empty for modifiers');
        return null;
      }

      // Parse results
      final links = linksResults.map((json) => ProductModifierGroupLink.fromJson(json)).toList();
      final groups = groupsResults.map((json) => ModifierGroup.fromJson(json)).toList();
      final options = optionsResults.map((json) => ModifierOption.fromJson(json)).toList();

      debugPrint('  ✅ Local mirror has ${links.length} links, ${groups.length} groups, ${options.length} options');

      return {
        'links': links,
        'groups': groups,
        'options': options,
      };
    } catch (e) {
      debugPrint('  ❌ Failed to read from local mirror: $e');
      return null;
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
