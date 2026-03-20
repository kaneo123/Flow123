import 'package:flutter/foundation.dart';
import 'package:flowtill/models/packaged_deal.dart';
import 'package:flowtill/models/packaged_deal_component.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/config/sync_config.dart';

class PackagedDealService {
  final _supabase = SupabaseConfig.client;
  final AppDatabase _db = AppDatabase.instance;
  final ConnectionService _connectionService = ConnectionService();

  List<PackagedDeal> _cachedDeals = [];
  Map<String, List<PackagedDealComponent>> _dealComponents = {}; // dealId -> [components]

  /// Check if we should use local-only mode (native + offline)
  bool get _shouldUseLocalOnly => !kIsWeb && !_connectionService.isOnline;

  /// Load all active packaged deals for the given outlet (local-first when flag enabled)
  Future<void> loadActiveDeals(String outletId) async {
    try {
      debugPrint('📦 PackagedDealService: Loading packaged deals for outlet $outletId');

      List<dynamic> dealsData = [];
      List<dynamic> componentsData = [];
      bool usedLocal = false;

      // Step 3: LOCAL MIRROR FIRST (when feature flag is enabled)
      if (kUseLocalMirrorReads && !kIsWeb) {
        debugPrint('[LOCAL_MIRROR] PackagedDealService: Trying local mirror first');
        
        final localResult = await _loadDealsFromLocalMirror(outletId);
        if (localResult != null) {
          dealsData = localResult['deals']!;
          componentsData = localResult['components']!;
          usedLocal = true;
          debugPrint('[LOCAL_MIRROR] ✅ Using local data for packaged_deals (${dealsData.length} deals, ${componentsData.length} components, source=local)');
        } else if (_shouldUseLocalOnly) {
          // Offline on native: Do NOT fall back to Supabase
          debugPrint('[LOCAL_MIRROR] ⚠️ Offline mode - local data empty, returning empty result (no Supabase fallback)');
          dealsData = [];
          componentsData = [];
          usedLocal = true;
        } else {
          debugPrint('[LOCAL_MIRROR] Local data unavailable, falling back to Supabase for packaged_deals');
        }
      }

      // Load from Supabase if not using local
      if (!usedLocal) {
        // First, check ALL deals in the database to help diagnose outlet mismatches
        final allDealsInDb = await _supabase
            .from('packaged_deals')
            .select()
            .eq('active', true);
        debugPrint('   📊 Total active deals in database (all outlets): ${allDealsInDb.length} (source=supabase)');
        if (allDealsInDb.isNotEmpty) {
          for (final dealData in allDealsInDb) {
            final deal = dealData as Map<String, dynamic>;
            debugPrint('      - "${deal['name']}" @ £${deal['price']} | Outlet: ${deal['outlet_id']}');
          }
        }

        // ⚡ PARALLEL FETCH: Load all deal data simultaneously
        final results = await Future.wait([
          _supabase
              .from('packaged_deals')
              .select()
              .eq('outlet_id', outletId)
              .eq('active', true),
          _supabase
              .from('packaged_deal_components')
              .select(),
        ]);

        dealsData = results[0] as List<dynamic>;
        componentsData = results[1] as List<dynamic>;
      }

      _cachedDeals = dealsData
          .map((json) => PackagedDeal.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('   Loaded ${_cachedDeals.length} active packaged deals');
      for (final deal in _cachedDeals) {
        debugPrint('      - ${deal.name} @ £${deal.price.toStringAsFixed(2)} (ID: ${deal.id})');
      }

      // Build deal components mapping
      _dealComponents.clear();
      for (final row in componentsData) {
        final component = PackagedDealComponent.fromJson(row as Map<String, dynamic>);
        _dealComponents.putIfAbsent(component.packagedDealId, () => []).add(component);
      }

      debugPrint('   Loaded components for ${_dealComponents.length} deals');
      _dealComponents.forEach((dealId, components) {
        final deal = getDealById(dealId);
        debugPrint('      Deal: ${deal?.name ?? dealId}');
        for (int i = 0; i < components.length; i++) {
          final comp = components[i];
          debugPrint('        [$i] ${comp.componentName}: ${comp.quantity} items from ${comp.productIds.length} product options');
        }
      });
    } catch (e, stackTrace) {
      debugPrint('❌ PackagedDealService: Failed to load packaged deals: $e');
      debugPrint('Stack: $stackTrace');
      _cachedDeals = [];
      _dealComponents.clear();
    }
  }

  /// Load packaged deals from local mirror tables
  Future<Map<String, List<dynamic>>?> _loadDealsFromLocalMirror(String outletId) async {
    debugPrint('  📂 Reading from local mirror tables: packaged_deals, packaged_deal_components');

    try {
      final db = await _db.database;

      // Load packaged_deals
      final dealsResults = await db.query(
        'packaged_deals',
        where: 'outlet_id = ? AND active = ?',
        whereArgs: [outletId, 1],
      );

      // Load packaged_deal_components (all components, will filter by deal)
      final componentsResults = await db.query('packaged_deal_components');

      // If deals empty, return null to trigger fallback
      if (dealsResults.isEmpty) {
        debugPrint('  ⚠️ Local mirror table empty: packaged_deals');
        return null;
      }

      debugPrint('  ✅ Local mirror has ${dealsResults.length} deals, ${componentsResults.length} components');

      return {
        'deals': dealsResults,
        'components': componentsResults,
      };
    } catch (e) {
      debugPrint('  ❌ Failed to read from local mirror: $e');
      return null;
    }
  }

  /// Get all packaged deals that are available right now (considering date/time and day of week)
  List<PackagedDeal> getAvailableDealsForNow() {
    final now = DateTime.now();
    debugPrint('📦 PackagedDealService: Checking deal availability at ${now.toString()}');
    debugPrint('   Current day of week: ${now.weekday} (${_getDayName(now.weekday)})');
    debugPrint('   Current time: ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
    debugPrint('   Total cached deals: ${_cachedDeals.length}');
    
    final availableNow = <PackagedDeal>[];
    final unavailableDeals = <String>[];
    
    for (final deal in _cachedDeals) {
      final isAvailable = deal.isAvailableAt(now);
      if (isAvailable) {
        availableNow.add(deal);
        debugPrint('   ✅ ${deal.name} @ £${deal.price.toStringAsFixed(2)} - AVAILABLE');
        if (deal.availableDays != null) {
          debugPrint('      Days: ${deal.availableDays}');
        }
        if (deal.startTime != null || deal.endTime != null) {
          debugPrint('      Time: ${deal.startTime ?? "00:00"} - ${deal.endTime ?? "23:59"}');
        }
      } else {
        unavailableDeals.add('${deal.name} (${_getUnavailableReason(deal, now)})');
      }
    }
    
    if (unavailableDeals.isNotEmpty) {
      debugPrint('   ❌ Unavailable deals:');
      for (final reason in unavailableDeals) {
        debugPrint('      - $reason');
      }
    }
    
    debugPrint('   📊 Result: ${availableNow.length}/${_cachedDeals.length} deals available now');
    return availableNow;
  }
  
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Unknown';
    }
  }
  
  String _getUnavailableReason(PackagedDeal deal, DateTime now) {
    if (!deal.active) return 'inactive';
    
    if (deal.startDate != null && now.isBefore(deal.startDate!)) {
      return 'not started yet';
    }
    if (deal.endDate != null && now.isAfter(deal.endDate!.add(const Duration(days: 1)))) {
      return 'expired';
    }
    
    if (deal.availableDays != null && deal.availableDays!.isNotEmpty) {
      final dayOfWeek = now.weekday % 7;
      if (!deal.availableDays!.contains(dayOfWeek)) {
        return 'wrong day (${_getDayName(now.weekday)})';
      }
    }
    
    if (deal.startTime != null || deal.endTime != null) {
      final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      if (deal.startTime != null && currentTime.compareTo(deal.startTime!) < 0) {
        return 'too early (starts at ${deal.startTime})';
      }
      if (deal.endTime != null && currentTime.compareTo(deal.endTime!) > 0) {
        return 'too late (ends at ${deal.endTime})';
      }
    }
    
    return 'unknown reason';
  }

  /// Get all active packaged deals (regardless of time restrictions)
  List<PackagedDeal> getAllActiveDeals() => List.unmodifiable(_cachedDeals);

  /// Get components for a specific packaged deal
  List<PackagedDealComponent> getComponentsForDeal(String dealId) {
    return _dealComponents[dealId] ?? [];
  }

  /// Get a specific packaged deal by ID
  PackagedDeal? getDealById(String dealId) {
    try {
      return _cachedDeals.firstWhere((d) => d.id == dealId);
    } catch (e) {
      return null;
    }
  }

  /// Check if a product is part of any component in a deal
  bool isDealProductInComponent(String dealId, String productId) {
    final components = getComponentsForDeal(dealId);
    return components.any((c) => c.includesProduct(productId));
  }

  /// Get all packaged deals that include a specific product
  List<PackagedDeal> getDealsContainingProduct(String productId) {
    final dealsWithProduct = <PackagedDeal>[];
    
    for (final deal in _cachedDeals) {
      final components = getComponentsForDeal(deal.id);
      if (components.any((c) => c.includesProduct(productId))) {
        dealsWithProduct.add(deal);
      }
    }
    
    return dealsWithProduct;
  }

  /// Validate if a deal can be fulfilled with the given product selections
  /// Returns true if all component requirements are met
  bool validateDealSelection(String dealId, Map<String, int> selectedProducts) {
    final components = getComponentsForDeal(dealId);
    
    for (final component in components) {
      int totalQuantity = 0;
      
      // Sum up quantities for all products in this component
      for (final productId in component.productIds) {
        totalQuantity += selectedProducts[productId] ?? 0;
      }
      
      // Check if component quantity requirement is met
      if (totalQuantity < component.quantity) {
        debugPrint('   Component "${component.componentName}" requires ${component.quantity} but only has $totalQuantity');
        return false;
      }
    }
    
    return true;
  }

  /// Clear cached data
  void clearCache() {
    _cachedDeals.clear();
    _dealComponents.clear();
    debugPrint('📦 PackagedDealService: Cache cleared');
  }
}
