import 'package:flutter/foundation.dart';
import 'package:flowtill/models/product.dart' as models;
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/services/outlet_service.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/supabase/supabase_config.dart';

class ProductService {
  final AppDatabase _db = AppDatabase.instance;
  final ConnectionService _connectionService = ConnectionService();

  /// Convert Supabase JSON to Model Product
  models.Product _fromSupabaseJson(Map<String, dynamic> json) {
    return models.Product(
      id: json['id'] as String? ?? '',
      outletId: json['outlet_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      categoryId: json['category_id'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      active: json['active'] as bool? ?? true,
      taxRateId: json['tax_rate_id'] as String?,
      course: json['course'] as String?,
      printerId: json['printer_id'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      trackStock: json['track_stock'] as bool? ?? false,
      autoHideWhenOutOfStock: json['auto_hide_when_out_of_stock'] as bool? ?? false,
      linkedInventoryItemId: json['linked_inventory_item_id'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      isCarvery: json['is_carvery'] as bool? ?? false,
    );
  }

  /// Convert database map to Model Product
  models.Product _mapToModel(Map<String, dynamic> map) {
    return models.Product(
      id: map['id'] as String,
      outletId: '', // Outlet ID is not stored in local DB
      name: map['name'] as String,
      categoryId: map['category_id'] as String,
      price: (map['price'] as num).toDouble(),
      active: (map['is_active'] as int) == 1,
      taxRateId: map['tax_rate_id'] as String?,
      sortOrder: map['sort_order'] as int,
      trackStock: (map['has_stock'] as int) == 1,
      autoHideWhenOutOfStock: false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      isCarvery: (map['is_carvery'] as int?) == 1,
      printerId: map['printer_id'] as String?,
      course: map['course'] as String?,
      plu: map['plu'] as String?,
    );
  }

  Future<ServiceResult<List<models.Product>>> getProductsForOutlet(String outletId) async {
    // Online-first (with special handling for web)
    if (kIsWeb || _connectionService.isOnline) {
      try {
        final response = await SupabaseConfig.client
            .from('products')
            .select()
            .eq('outlet_id', outletId)
            .order('sort_order');

        final products = (response as List).map((json) => _fromSupabaseJson(json)).toList();
        
        // Cache to local DB for offline access (on mobile/desktop only)
        if (!kIsWeb) {
          try {
            final productMaps = products.map((p) => {
              'id': p.id,
              'name': p.name,
              'category_id': p.categoryId,
              'price': p.price,
              'is_active': p.active ? 1 : 0,
              'sort_order': p.sortOrder,
              'has_stock': p.trackStock ? 1 : 0,
              'stock_quantity': 0.0,
              'tax_rate_id': p.taxRateId,
              'image_url': null,
              'color': null,
              'is_carvery': p.isCarvery ? 1 : 0,
              'printer_id': p.printerId,
              'course': p.course,
              'plu': p.plu,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            }).toList();
            await _db.insertProducts(productMaps);
          } catch (e) {
            // Cache failure is non-fatal
          }
        }
        
        return ServiceResult.success(products);
      } catch (e) {
        // Fall back to local DB if Supabase fails
      }
    }

    // Offline mode: use local SQLite
    try {
      final results = await _db.getAllProducts();
      final products = results.map(_mapToModel).toList();
      return ServiceResult.success(products);
    } catch (e) {
      return ServiceResult.failure('Failed to fetch products: ${e.toString()}');
    }
  }

  Future<ServiceResult<List<models.Product>>> getProductsByCategory(String categoryId) async {
    // Online-first (with special handling for web)
    if (kIsWeb || _connectionService.isOnline) {
      try {
        final response = await SupabaseConfig.client
            .from('products')
            .select()
            .eq('category_id', categoryId)
            .order('sort_order');

        final products = (response as List).map((json) => _fromSupabaseJson(json)).toList();
        return ServiceResult.success(products);
      } catch (e) {
        // Fall back to local DB if Supabase fails
      }
    }

    // Offline mode: use local SQLite
    try {
      final results = await _db.getProductsByCategory(categoryId);
      final products = results.map(_mapToModel).toList();
      return ServiceResult.success(products);
    } catch (e) {
      return ServiceResult.failure('Failed to fetch products: ${e.toString()}');
    }
  }

  Future<ServiceResult<models.Product>> getProductById(String id) async {
    // Online-first (with special handling for web)
    if (kIsWeb || _connectionService.isOnline) {
      try {
        final response = await SupabaseConfig.client
            .from('products')
            .select()
            .eq('id', id)
            .maybeSingle();

        if (response != null) {
          return ServiceResult.success(_fromSupabaseJson(response));
        }
      } catch (e) {
        // Fall back to local DB
      }
    }

    // Offline mode or fallback: use local SQLite
    try {
      final db = await _db.database;
      final results = await db.query('products', where: 'id = ?', whereArgs: [id]);
      
      if (results.isEmpty) {
        return ServiceResult.failure('Product not found');
      }
      
      return ServiceResult.success(_mapToModel(results.first));
    } catch (e) {
      return ServiceResult.failure('Failed to fetch product: ${e.toString()}');
    }
  }

  Future<ServiceResult<List<models.Product>>> searchProducts(String query, [String? outletId]) async {
    if (query.trim().isEmpty) {
      return getProductsForOutlet(outletId ?? '');
    }

    // Online-first (with special handling for web)
    if (kIsWeb || _connectionService.isOnline) {
      try {
        var queryBuilder = SupabaseConfig.client
            .from('products')
            .select()
            .eq('active', true)
            .ilike('name', '%$query%');

        if (outletId != null && outletId.isNotEmpty) {
          queryBuilder = queryBuilder.eq('outlet_id', outletId);
        }

        final response = await queryBuilder.order('sort_order');
        final products = (response as List).map((json) => _fromSupabaseJson(json)).toList();
        return ServiceResult.success(products);
      } catch (e) {
        // Fall back to local DB
      }
    }

    // Offline mode: use local SQLite
    try {
      final db = await _db.database;
      final results = await db.query(
        'products',
        where: 'is_active = 1 AND name LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: 'sort_order ASC, name ASC',
      );
      final products = results.map(_mapToModel).toList();
      return ServiceResult.success(products);
    } catch (e) {
      return ServiceResult.failure('Failed to search products: ${e.toString()}');
    }
  }

  // Note: Create/Update/Delete methods are not used by Till - these are BackOffice operations

  Future<ServiceResult<models.Product>> createProduct({
    required String name,
    required String outletId,
    required String categoryId,
    required double price,
    String? imageUrl,
  }) async {
    return ServiceResult.failure('Product creation is not supported in Till mode. Use BackOffice.');
  }

  Future<ServiceResult<models.Product>> updateProduct(String id, Map<String, dynamic> updates) async {
    return ServiceResult.failure('Product updates are not supported in Till mode. Use BackOffice.');
  }

  Future<ServiceResult<void>> deleteProduct(String id) async {
    return ServiceResult.failure('Product deletion is not supported in Till mode. Use BackOffice.');
  }
}
