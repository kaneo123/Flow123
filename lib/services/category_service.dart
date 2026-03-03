import 'package:flutter/foundation.dart';
import 'package:flowtill/models/category.dart' as models;
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/services/outlet_service.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/supabase/supabase_config.dart';

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
    // Online-first (with special handling for web)
    if (kIsWeb || _connectionService.isOnline) {
      debugPrint('📂 CategoryService: Fetching categories for outlet: $outletId (from Supabase - ${kIsWeb ? "Web" : "ONLINE"})');
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
            final categoryMaps = categories.map((c) => {
              'id': c.id,
              'name': c.name,
              'sort_order': c.sortOrder,
              'color': null,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            }).toList();
            await _db.insertCategories(categoryMaps);
            debugPrint('💾 CategoryService: Cached ${categories.length} categories to local DB for offline access');
          } catch (e) {
            debugPrint('⚠️ CategoryService: Failed to cache categories (non-fatal): $e');
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
}
