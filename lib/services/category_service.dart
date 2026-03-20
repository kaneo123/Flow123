import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flowtill/models/category.dart' as models;
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/services/outlet_service.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:flowtill/config/sync_config.dart';

class CategoryService {
  final AppDatabase _db = AppDatabase.instance;
  final ConnectionService _connectionService = ConnectionService();

  /// Convert Supabase JSON to Model Category
  models.Category _fromSupabaseJson(Map<String, dynamic> json) {
    return models.Category(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      parentId: json['parent_id'] as String?,
    );
  }

  /// Convert database map to Model Category
  models.Category _mapToModel(Map<String, dynamic> map) {
    return models.Category(
      id: map['id'] as String,
      outletId: '', // Outlet ID is not stored in local DB
      name: map['name'] as String,
      description: null,
      sortOrder: map['sort_order'] as int,
      active: (map['updated_at'] as int) > 0, // Active if has update time
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Future<ServiceResult<List<models.Category>>> getCategoriesForOutlet(String outletId) async {
    // Step 3: LOCAL MIRROR FIRST (when feature flag is enabled)
    if (kUseLocalMirrorReads && !kIsWeb) {
      debugPrint('[LOCAL_MIRROR] CategoryService: Trying local mirror first for outlet: $outletId');
      
      final localResult = await _getCategoriesFromLocalMirror(outletId);
      if (localResult.isSuccess && localResult.data != null && localResult.data!.isNotEmpty) {
        debugPrint('[LOCAL_MIRROR] ✅ Using local data for categories (${localResult.data!.length} records, source=local)');
        return localResult;
      }
      
      // Check if offline - if so, don't fall back to Supabase
      if (!_connectionService.isOnline) {
        debugPrint('[LOCAL_MIRROR] ⚠️ Offline mode - local data empty, returning empty result (no Supabase fallback)');
        return ServiceResult.success([]);
      }
      
      debugPrint('[LOCAL_MIRROR] Local data unavailable, falling back to Supabase for categories');
    }

    // Original online-first logic (with special handling for web)
    if (kIsWeb || _connectionService.isOnline) {
      debugPrint('📂 CategoryService: Fetching categories for outlet: $outletId (from Supabase - ${kIsWeb ? "Web" : "ONLINE"}, source=supabase)');
      try {
        final response = await SupabaseConfig.client
            .from('categories')
            .select()
            .eq('outlet_id', outletId)
            .order('sort_order');

        final categories = (response as List).map((json) => _fromSupabaseJson(json)).toList();
        
        // Cache to local DB for offline access (on mobile/desktop only)
        if (!kIsWeb) {
          try {
            // Get local table columns to ensure we only write what exists
            final db = await _db.database;
            final localColumns = await _getLocalTableColumns(db, 'categories');
            debugPrint('📋 Local categories table has ${localColumns.length} columns: ${localColumns.join(", ")}');
            
            final categoryMaps = categories.map((c) {
              final data = <String, dynamic>{
                'id': c.id,
                'outlet_id': c.outletId,
                'name': c.name,
                'description': c.description,
                'sort_order': c.sortOrder,
                'active': c.active ? 1 : 0,
                'created_at': (c.createdAt ?? DateTime.now()).millisecondsSinceEpoch,
                'parent_id': c.parentId,
              };
              
              // Filter to only include columns that exist in local table
              final filteredData = <String, dynamic>{};
              for (final entry in data.entries) {
                if (localColumns.contains(entry.key)) {
                  filteredData[entry.key] = entry.value;
                }
              }
              
              return filteredData;
            }).toList();
            
            await _db.insertCategories(categoryMaps);
            debugPrint('💾 CategoryService: Cached ${categories.length} categories to local DB for offline access');
          } catch (e, stackTrace) {
            debugPrint('⚠️ CategoryService: Failed to cache categories (non-fatal): $e');
            debugPrint('Stack: $stackTrace');
          }
        }
        
        debugPrint('✅ CategoryService: ${categories.length} categories loaded from Supabase');
        return ServiceResult.success(categories);
      } catch (e) {
        debugPrint('❌ CategoryService Supabase error: $e, falling back to local DB');
        // Fall back to local DB if Supabase fails
      }
    }

    // Offline mode: use local SQLite
    debugPrint('📂 CategoryService: Fetching categories (from local DB - OFFLINE)');
    try {
      final results = await _db.getActiveCategoriesWithProducts();
      final categories = results.map(_mapToModel).toList();
      
      debugPrint('✅ CategoryService: ${categories.length} categories loaded from local DB');
      return ServiceResult.success(categories);
    } catch (e) {
      debugPrint('❌ CategoryService error: $e');
      return ServiceResult.failure('Failed to fetch categories: ${e.toString()}');
    }
  }

  /// Get categories from local mirror table
  Future<ServiceResult<List<models.Category>>> _getCategoriesFromLocalMirror(String outletId) async {
    debugPrint('  📂 Reading from local mirror table: categories');

    try {
      final db = await _db.database;
      final results = await db.query(
        'categories',
        where: 'outlet_id = ?',
        whereArgs: [outletId],
        orderBy: 'sort_order',
      );

      if (results.isEmpty) {
        debugPrint('  ⚠️ Local mirror table empty: categories');
        return ServiceResult.failure('Local mirror table empty');
      }

      final categories = <models.Category>[];
      for (final json in results) {
        try {
          debugPrint('  📦 Parsing category from local mirror: ${json['name']}');
          debugPrint('     Available columns: ${json.keys.join(", ")}');
          
          final category = models.Category.fromJson(json);
          categories.add(category);
        } catch (e, stackTrace) {
          debugPrint('  ❌ Failed to parse category from local mirror: $e');
          debugPrint('     Row data: $json');
          debugPrint('     Stack: $stackTrace');
          // Continue parsing other categories
        }
      }

      debugPrint('  ✅ Local mirror has ${categories.length} categories');
      return ServiceResult.success(categories);
    } catch (e) {
      debugPrint('  ❌ Failed to read from local mirror: $e');
      return ServiceResult.failure('Failed to read local mirror: ${e.toString()}');
    }
  }
  
  Future<ServiceResult<List<models.Category>>> getCategoriesByOutlet(String outletId) async {
    return getCategoriesForOutlet(outletId);
  }

  Future<ServiceResult<models.Category>> getCategoryById(String id) async {
    // Online-first (with special handling for web)
    if (kIsWeb || _connectionService.isOnline) {
      try {
        final response = await SupabaseConfig.client
            .from('categories')
            .select()
            .eq('id', id)
            .maybeSingle();

        if (response != null) {
          return ServiceResult.success(_fromSupabaseJson(response));
        }
      } catch (e) {
        debugPrint('❌ CategoryService Supabase error: $e, falling back to local DB');
      }
    }

    // Offline mode or fallback: use local SQLite
    try {
      final db = await _db.database;
      final results = await db.query('categories', where: 'id = ?', whereArgs: [id]);
      
      if (results.isEmpty) {
        return ServiceResult.failure('Category not found');
      }
      
      return ServiceResult.success(_mapToModel(results.first));
    } catch (e) {
      debugPrint('❌ CategoryService error: $e');
      return ServiceResult.failure('Failed to fetch category: ${e.toString()}');
    }
  }

  // Note: Create/Update/Delete methods are not used by Till - these are BackOffice operations
  // They are kept here for compatibility but should not be called from Till

  Future<ServiceResult<models.Category>> createCategory({
    required String name,
    required String outletId,
    String color = '#64748B',
    int displayOrder = 0,
  }) async {
    return ServiceResult.failure('Category creation is not supported in Till mode. Use BackOffice.');
  }

  Future<ServiceResult<models.Category>> updateCategory(String id, Map<String, dynamic> updates) async {
    return ServiceResult.failure('Category updates are not supported in Till mode. Use BackOffice.');
  }

  Future<ServiceResult<void>> deleteCategory(String id) async {
    return ServiceResult.failure('Category deletion is not supported in Till mode. Use BackOffice.');
  }
  
  /// Get list of column names for a local table
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
      debugPrint('⚠️ Failed to get columns for $tableName: $e');
      return {};
    }
  }
}
