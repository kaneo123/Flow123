import 'package:flutter/foundation.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/supabase/supabase_config.dart';

/// Service for validating data completeness and quality after startup sync
/// Helps distinguish between sync failures and genuinely empty source tables
class StartupValidationService {
  final AppDatabase _db = AppDatabase.instance;

  /// Validate outlet data completeness and generate diagnostic summary
  /// Returns a summary of row counts and data quality issues
  Future<OutletValidationSummary> validateOutletData(String outletId) async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[VALIDATION] OUTLET DATA VALIDATION - START');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[VALIDATION] Outlet ID: $outletId');

    try {
      // Get local row counts
      final localCounts = await _getLocalRowCounts(outletId);
      
      // Get Supabase row counts for comparison
      final supabaseCounts = kIsWeb ? <String, int>{} : await _getSupabaseRowCounts(outletId);
      
      // Check category data quality
      final categoryIssues = await _checkCategoryDataQuality(outletId);
      
      // Check stock linkage issues
      final stockIssues = await _checkStockLinkageIssues(outletId);

      final summary = OutletValidationSummary(
        outletId: outletId,
        localRowCounts: localCounts,
        supabaseRowCounts: supabaseCounts,
        categoryQualityIssues: categoryIssues,
        stockLinkageIssues: stockIssues,
      );

      _logValidationSummary(summary);

      debugPrint('[VALIDATION] ✅ OUTLET DATA VALIDATION - COMPLETE');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');

      return summary;
    } catch (e, stackTrace) {
      debugPrint('[VALIDATION] ❌ VALIDATION FAILED: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');
      
      return OutletValidationSummary.error(outletId, e.toString());
    }
  }

  /// Get row counts from local SQLite mirror tables
  /// Filters by outlet_id for outlet-scoped tables
  Future<Map<String, int>> _getLocalRowCounts(String outletId) async {
    final counts = <String, int>{};
    
    // Outlet-scoped tables (have outlet_id column)
    final outletFilteredTables = [
      'categories',
      'products',
      'staff_outlets',
      'printers',
      'outlet_tables',
      'packaged_deals',
      'inventory_items',
      'modifier_groups',
      'modifier_options',
      'product_modifier_groups',
      'promotions',
    ];
    
    // Global tables (no outlet_id - shared across all outlets)
    final globalTables = [
      'tax_rates',
      'packaged_deal_components',
    ];

    final db = await _db.database;
    
    // Count outlet-scoped tables WITH outlet_id filter
    for (final table in outletFilteredTables) {
      try {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $table WHERE outlet_id = ?',
          [outletId],
        );
        counts[table] = result.first['count'] as int;
      } catch (e) {
        debugPrint('[VALIDATION] ⚠️ Could not count local $table: $e');
        counts[table] = -1; // -1 indicates table doesn't exist or query failed
      }
    }
    
    // Count global tables WITHOUT outlet_id filter
    for (final table in globalTables) {
      try {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        counts[table] = result.first['count'] as int;
      } catch (e) {
        debugPrint('[VALIDATION] ⚠️ Could not count local $table: $e');
        counts[table] = -1;
      }
    }

    return counts;
  }

  /// Get row counts from Supabase for comparison
  /// Filters by outlet_id for outlet-scoped tables
  Future<Map<String, int>> _getSupabaseRowCounts(String outletId) async {
    final counts = <String, int>{};
    
    // Outlet-scoped tables (have outlet_id column)
    final outletFilteredTables = [
      'categories',
      'products',
      'staff_outlets',
      'printers',
      'outlet_tables',
      'packaged_deals',
      'inventory_items',
      'modifier_groups',
      'modifier_options',
      'product_modifier_groups',
      'promotions',
    ];
    
    // Global tables (no outlet_id - shared across all outlets)
    final globalTables = [
      'tax_rates',
      'packaged_deal_components',
    ];

    try {
      // Count outlet-scoped tables WITH outlet_id filter
      for (final table in outletFilteredTables) {
        try {
          final response = await SupabaseConfig.client
              .from(table)
              .select('id')
              .eq('outlet_id', outletId);
          
          counts[table] = (response as List).length;
        } catch (e) {
          debugPrint('[VALIDATION] ⚠️ Could not count Supabase $table: $e');
          counts[table] = -1;
        }
      }
      
      // Count global tables WITHOUT outlet_id filter
      for (final table in globalTables) {
        try {
          final response = await SupabaseConfig.client
              .from(table)
              .select('id');
          
          counts[table] = (response as List).length;
        } catch (e) {
          debugPrint('[VALIDATION] ⚠️ Could not count Supabase $table: $e');
          counts[table] = -1;
        }
      }
    } catch (e) {
      debugPrint('[VALIDATION] ⚠️ Supabase count query failed: $e');
    }

    return counts;
  }

  /// Check category data quality issues
  Future<List<CategoryQualityIssue>> _checkCategoryDataQuality(String outletId) async {
    final issues = <CategoryQualityIssue>[];
    
    try {
      final db = await _db.database;
      // Filter categories by outlet to avoid false positives across outlets
      final result = await db.query(
        'categories',
        where: 'outlet_id = ?',
        whereArgs: [outletId],
      );
      
      if (result.isEmpty) {
        return issues;
      }

      // Build a map of category names (case-insensitive) to detect duplicates
      final nameMap = <String, List<Map<String, dynamic>>>{};
      
      for (final row in result) {
        final name = row['name'] as String;
        final nameLower = name.toLowerCase().trim();
        
        if (!nameMap.containsKey(nameLower)) {
          nameMap[nameLower] = [];
        }
        nameMap[nameLower]!.add(row);
      }

      // Detect exact duplicates only (case-insensitive)
      for (final entry in nameMap.entries) {
        final categories = entry.value;
        
        if (categories.length > 1) {
          // Multiple categories with same name (case-insensitive) within same outlet
          final names = categories.map((c) => c['name'] as String).toList();
          final ids = categories.map((c) => c['id'] as String).toList();
          
          issues.add(CategoryQualityIssue(
            type: 'duplicate_name',
            message: 'Duplicate category name detected: ${names.join(", ")}',
            categoryIds: ids,
            categoryNames: names,
          ));
        }
      }

      // REMOVED: Similar name detection - too noisy and flags legitimate variations like "Drinks" vs "Drink"

    } catch (e) {
      debugPrint('[VALIDATION] ⚠️ Could not check category quality: $e');
    }

    return issues;
  }

  /// Check if two category names are similar (likely spelling variants)
  bool _areNamesSimilar(String name1, String name2) {
    if (name1 == name2) return false; // Already exact match
    
    final n1 = name1.toLowerCase();
    final n2 = name2.toLowerCase();
    
    // Check if one contains the other (e.g., "Drink" vs "Drinks")
    if (n1.contains(n2) || n2.contains(n1)) {
      return true;
    }
    
    // Simple Levenshtein distance check (edit distance <= 2)
    return _levenshteinDistance(n1, n2) <= 2;
  }

  /// Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final costs = List<int>.generate(s2.length + 1, (i) => i);
    
    for (int i = 1; i <= s1.length; i++) {
      int lastValue = i;
      for (int j = 1; j <= s2.length; j++) {
        final newValue = costs[j];
        costs[j] = (s1[i - 1] == s2[j - 1])
            ? costs[j - 1]
            : 1 + [costs[j - 1], costs[j], lastValue].reduce((a, b) => a < b ? a : b);
        lastValue = newValue;
      }
    }
    
    return costs[s2.length];
  }

  /// Check stock linkage issues for products
  Future<List<StockLinkageIssue>> _checkStockLinkageIssues(String outletId) async {
    final issues = <StockLinkageIssue>[];
    
    try {
      final db = await _db.database;
      
      // Get all products that claim to track stock
      final products = await db.query(
        'products',
        where: 'track_stock = 1',
      );

      if (products.isEmpty) {
        return issues;
      }

      // Get all inventory items for lookup
      final inventoryItems = await db.query('inventory_items');
      final inventoryIds = inventoryItems.map((i) => i['id'] as String).toSet();

      for (final product in products) {
        final productId = product['id'] as String;
        final productName = product['name'] as String;
        final linkedInventoryItemId = product['linked_inventory_item_id'] as String?;

        if (linkedInventoryItemId == null) {
          // Product tracks stock but has no linked inventory item
          // This means it should be using recipe-based tracking (enhanced mode)
          issues.add(StockLinkageIssue(
            productId: productId,
            productName: productName,
            type: 'no_linked_inventory',
            message: 'Product "$productName" tracks stock but has no linked_inventory_item_id. Should use recipe-based tracking.',
          ));
        } else if (!inventoryIds.contains(linkedInventoryItemId)) {
          // Product has linked_inventory_item_id but that inventory item doesn't exist
          issues.add(StockLinkageIssue(
            productId: productId,
            productName: productName,
            type: 'linked_inventory_missing',
            message: 'Product "$productName" links to inventory item $linkedInventoryItemId which does not exist.',
            linkedInventoryItemId: linkedInventoryItemId,
          ));
        }
      }

    } catch (e) {
      debugPrint('[VALIDATION] ⚠️ Could not check stock linkage: $e');
    }

    return issues;
  }

  /// Log validation summary to console
  void _logValidationSummary(OutletValidationSummary summary) {
    debugPrint('');
    debugPrint('─────────────────────────────────────────────────────────');
    debugPrint('[VALIDATION] OUTLET DATA SUMMARY');
    debugPrint('─────────────────────────────────────────────────────────');
    debugPrint('[VALIDATION] Outlet ID: ${summary.outletId}');
    debugPrint('');
    
    // Row counts
    debugPrint('[VALIDATION] Row Counts:');
    final sortedTables = summary.localRowCounts.keys.toList()..sort();
    for (final table in sortedTables) {
      final localCount = summary.localRowCounts[table] ?? -1;
      final supabaseCount = summary.supabaseRowCounts[table] ?? -1;
      
      final localStr = localCount >= 0 ? localCount.toString() : 'N/A';
      final supabaseStr = supabaseCount >= 0 ? supabaseCount.toString() : 'N/A';
      
      // Flag mismatches
      final mismatch = localCount >= 0 && supabaseCount >= 0 && localCount != supabaseCount ? ' ⚠️ MISMATCH' : '';
      final empty = localCount == 0 && supabaseCount == 0 ? ' (empty in source)' : '';
      
      debugPrint('  $table: $localStr local / $supabaseStr source$mismatch$empty');
    }
    
    debugPrint('');
    
    // Category quality issues
    if (summary.categoryQualityIssues.isNotEmpty) {
      debugPrint('[VALIDATION] Category Quality Issues (${summary.categoryQualityIssues.length}):');
      for (final issue in summary.categoryQualityIssues) {
        debugPrint('  ${issue.type.toUpperCase()}: ${issue.message}');
      }
      debugPrint('');
    }
    
    // Stock linkage issues
    if (summary.stockLinkageIssues.isNotEmpty) {
      debugPrint('[VALIDATION] Stock Linkage Issues (${summary.stockLinkageIssues.length}):');
      for (final issue in summary.stockLinkageIssues) {
        debugPrint('  ${issue.type.toUpperCase()}: ${issue.message}');
      }
      debugPrint('');
    }
    
    debugPrint('─────────────────────────────────────────────────────────');
  }
}

/// Summary of outlet data validation results
class OutletValidationSummary {
  final String outletId;
  final Map<String, int> localRowCounts;
  final Map<String, int> supabaseRowCounts;
  final List<CategoryQualityIssue> categoryQualityIssues;
  final List<StockLinkageIssue> stockLinkageIssues;
  final String? error;

  OutletValidationSummary({
    required this.outletId,
    required this.localRowCounts,
    required this.supabaseRowCounts,
    required this.categoryQualityIssues,
    required this.stockLinkageIssues,
    this.error,
  });

  factory OutletValidationSummary.error(String outletId, String error) {
    return OutletValidationSummary(
      outletId: outletId,
      localRowCounts: {},
      supabaseRowCounts: {},
      categoryQualityIssues: [],
      stockLinkageIssues: [],
      error: error,
    );
  }

  bool get hasIssues =>
      categoryQualityIssues.isNotEmpty || stockLinkageIssues.isNotEmpty;
}

/// Category data quality issue
class CategoryQualityIssue {
  final String type; // 'duplicate_name', 'similar_name'
  final String message;
  final List<String> categoryIds;
  final List<String> categoryNames;

  CategoryQualityIssue({
    required this.type,
    required this.message,
    required this.categoryIds,
    required this.categoryNames,
  });
}

/// Stock linkage issue
class StockLinkageIssue {
  final String productId;
  final String productName;
  final String type; // 'no_linked_inventory', 'linked_inventory_missing', 'recipe_missing', 'recipe_components_missing'
  final String message;
  final String? linkedInventoryItemId;

  StockLinkageIssue({
    required this.productId,
    required this.productName,
    required this.type,
    required this.message,
    this.linkedInventoryItemId,
  });
}
