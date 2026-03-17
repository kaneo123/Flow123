import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flowtill/models/category.dart' as models;
import 'package:flowtill/models/product.dart';
import 'package:flowtill/models/product_stock_info.dart';
import 'package:flowtill/models/tax_rate.dart';
import 'package:flowtill/models/promotion.dart';
import 'package:flowtill/services/category_service.dart';
import 'package:flowtill/services/product_service.dart';
import 'package:flowtill/services/tax_rate_service.dart';
import 'package:flowtill/services/stock_service.dart';
import 'package:flowtill/services/promotion_service.dart';
import 'package:flowtill/services/packaged_deal_service.dart';
import 'package:flowtill/services/outlet_service.dart';

class CatalogProvider with ChangeNotifier {
  final CategoryService _categoryService = CategoryService();
  final ProductService _productService = ProductService();
  final TaxRateService _taxRateService = TaxRateService();
  final StockService _stockService = StockService();
  final PromotionService _promotionService = PromotionService();
  final PackagedDealService _packagedDealService = PackagedDealService();

  Timer? _periodicRefreshTimer;
  String? _currentOutletId;
  bool _isRefreshingStock = false;

  bool _isLoading = false;
  String? _errorMessage;
  List<models.Category> _categories = [];
  List<Product> _products = [];
  Map<String, List<Product>> _productsByCategory = {};
  List<TaxRate> _taxRates = [];
  String? _selectedCategoryId;
  String? _currentParentCategoryId; // Track when viewing sub-categories
  Set<String> _productIdsWithActivePromotions = {};
  static const String specialsCategoryId = '__specials__';
  static const String uncategorizedCategoryId = '__uncategorized__';
  bool _hasUncategorizedProducts = false;
  
  // 🗂️ Category navigation state (for drill-down UI)
  List<String> _categoryNavigationStack = []; // Stack of category IDs (breadcrumb trail)

  bool get isLoading => _isLoading;
  bool get isRefreshingStock => _isRefreshingStock;
  String? get errorMessage => _errorMessage;
  List<models.Category> get categories => _categories;
  List<Product> get products => _products;
  Map<String, List<Product>> get productsByCategory => _productsByCategory;
  List<TaxRate> get taxRates => _taxRates;
  String? get selectedCategoryId => _selectedCategoryId;
  String? get currentParentCategoryId => _currentParentCategoryId;
  bool get hasSpecials => _productIdsWithActivePromotions.isNotEmpty;
  bool get hasUncategorizedProducts => _hasUncategorizedProducts;
  List<String> get categoryNavigationStack => _categoryNavigationStack;

  List<Product> get currentProducts {
    if (_selectedCategoryId == null) return [];
    if (_selectedCategoryId == specialsCategoryId) {
      final specials = getSpecialProductsForToday();
      debugPrint('📋 CatalogProvider: currentProducts for Specials tab = ${specials.length} products');
      return specials;
    }
    if (_selectedCategoryId == uncategorizedCategoryId) {
      final uncategorized = _productsByCategory[uncategorizedCategoryId] ?? [];
      debugPrint('📋 CatalogProvider: currentProducts for Uncategorized tab = ${uncategorized.length} products');
      return uncategorized;
    }
    return _productsByCategory[_selectedCategoryId] ?? [];
  }
  
  /// Get stock info for a product
  ProductStockInfo? getStockInfo(String productId) => _stockService.getStockInfoForProduct(productId);

  /// Load complete catalog (categories + products with inventory) for an outlet
  Future<void> loadCatalog(String outletId) async {
    debugPrint('[CATALOG_PROVIDER] Loading catalog for outlet: $outletId');
    
    _currentOutletId = outletId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // ⚡ PARALLEL FETCH: Run all independent queries simultaneously
      late final ServiceResult<List<models.Category>> categoriesResult;
      late final ServiceResult<List<Product>> productsResult;
      late final ServiceResult<List<TaxRate>> taxRatesResult;

      debugPrint('[CATALOG_PROVIDER] Starting parallel data fetch for outlet $outletId...');
      
      await Future.wait([
        _categoryService.getCategoriesForOutlet(outletId).then((r) => categoriesResult = r),
        _productService.getProductsForOutlet(outletId).then((r) => productsResult = r),
        _taxRateService.getAllTaxRates().then((r) => taxRatesResult = r),
        _promotionService.loadActivePromotions(outletId),
        _packagedDealService.loadActiveDeals(outletId).catchError((e, stackTrace) {
          debugPrint('[CATALOG_PROVIDER] ❌ PackagedDealService.loadActiveDeals() threw error: $e');
          debugPrint('Stack: $stackTrace');
        }),
      ]);

      debugPrint('[CATALOG_PROVIDER] ✅ Parallel fetch complete');
      
      // Debug packaged deals
      final allDeals = _packagedDealService.getAllActiveDeals();
      debugPrint('[CATALOG_PROVIDER] Packaged deals: ${allDeals.length} total for this outlet');
      if (allDeals.isEmpty) {
        debugPrint('[CATALOG_PROVIDER] ⚠️ No deals found for outlet $outletId');
      }
      final availableNow = _packagedDealService.getAvailableDealsForNow();
      debugPrint('[CATALOG_PROVIDER] Available deals now: ${availableNow.length}');

      // Handle categories
      debugPrint('[CATALOG_PROVIDER] Processing categories result...');
      if (!categoriesResult.isSuccess) {
        _errorMessage = categoriesResult.error ?? 'Failed to load categories';
        debugPrint('[CATALOG_PROVIDER] ❌ ${_errorMessage}');
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Handle products
      debugPrint('[CATALOG_PROVIDER] Processing products result...');
      if (!productsResult.isSuccess) {
        _errorMessage = productsResult.error ?? 'Failed to load products';
        debugPrint('[CATALOG_PROVIDER] ❌ ${_errorMessage}');
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Handle tax rates
      debugPrint('[CATALOG_PROVIDER] Processing tax rates result...');
      debugPrint('[CATALOG_PROVIDER]   taxRatesResult.isSuccess: ${taxRatesResult.isSuccess}');
      debugPrint('[CATALOG_PROVIDER]   taxRatesResult.data: ${taxRatesResult.data}');
      debugPrint('[CATALOG_PROVIDER]   taxRatesResult.error: ${taxRatesResult.error}');
      
      if (!taxRatesResult.isSuccess) {
        debugPrint('[CATALOG_PROVIDER] ⚠️ Tax rates fetch failed: ${taxRatesResult.error}');
        debugPrint('[CATALOG_PROVIDER] Continuing with empty tax rates list');
      }

      _categories = categoriesResult.data ?? [];
      _products = productsResult.data ?? [];
      _taxRates = taxRatesResult.data ?? [];
      
      debugPrint('[CATALOG_PROVIDER] ✅ Data assigned:');
      debugPrint('[CATALOG_PROVIDER]   Categories: ${_categories.length}');
      debugPrint('[CATALOG_PROVIDER]   Products: ${_products.length}');
      debugPrint('[CATALOG_PROVIDER]   Tax Rates: ${_taxRates.length}');
      if (_taxRates.isNotEmpty) {
        for (final rate in _taxRates) {
          debugPrint('[CATALOG_PROVIDER]     - ${rate.name}: ${rate.rate}%');
        }
      }

      // 🔍 Enhanced debugging - Check parsed products
      debugPrint('🔍 CatalogProvider: Loaded ${_products.length} products');
      final carveryCount = _products.where((p) => p.isCarvery).length;
      debugPrint('🔍 CatalogProvider: Products with isCarvery=true: $carveryCount');
      
      if (carveryCount > 0) {
        debugPrint('🔍 CatalogProvider: Carvery products:');
        for (final p in _products.where((p) => p.isCarvery)) {
          debugPrint('   ✓ ${p.name} (${p.id})');
          debugPrint('     - categoryId: ${p.categoryId}');
          debugPrint('     - price: £${p.price.toStringAsFixed(2)}');
          debugPrint('     - trackStock: ${p.trackStock}');
        }
      } else {
        debugPrint('⚠️ CatalogProvider: NO CARVERY PRODUCTS FOUND after parsing!');
      }

      // Build set of products with active promotions (uses data from promotions already loaded)
      _buildProductsWithPromotionsSet();

      // ⚡ PARALLEL FETCH: Load stock and build product map simultaneously
      await Future.wait([
        _stockService.loadStockForOutlet(outletId, _products),
        Future.microtask(() => _buildProductsByCategory()),
      ]);
      
      // 🧾 Stock Diagnostics: Check products configured to track stock
      await _runStockDiagnostics(outletId);

      // Auto-select first top-level category
      if (_categories.isNotEmpty && _selectedCategoryId == null) {
        final topLevel = getTopLevelCategories();
        if (topLevel.isNotEmpty) {
          _selectedCategoryId = topLevel.first.id;
        }
      }

      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('[CATALOG_PROVIDER] ✅ CATALOG LOADED SUCCESSFULLY');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('[CATALOG_PROVIDER] Categories: ${_categories.length}');
      debugPrint('[CATALOG_PROVIDER] Products: ${_products.length}');
      debugPrint('[CATALOG_PROVIDER] Tax Rates: ${_taxRates.length}');
      debugPrint('[CATALOG_PROVIDER] Products with active promotions: ${_productIdsWithActivePromotions.length}');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');

      _isLoading = false;
      _errorMessage = null;
      
      // Start periodic refresh timer (every 20 minutes)
      _startPeriodicRefresh();
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Unexpected error loading catalog: ${e.toString()}';
      debugPrint('[CATALOG_PROVIDER] ❌ Error: ${_errorMessage}');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh stock levels only (optimized for speed)
  Future<void> refreshStockOnly() async {
    if (_currentOutletId == null || _products.isEmpty) {
      debugPrint('[CATALOG_PROVIDER] ⚠️ Cannot refresh stock - no catalog loaded');
      return;
    }

    debugPrint('[CATALOG_PROVIDER] 🔄 Refreshing stock levels only...');
    _isRefreshingStock = true;
    notifyListeners();

    try {
      // Only reload stock data (fastest operation)
      await _stockService.loadStockForOutlet(_currentOutletId!, _products);
      
      debugPrint('[CATALOG_PROVIDER] ✅ Stock levels refreshed successfully');
    } catch (e) {
      debugPrint('[CATALOG_PROVIDER] ❌ Error refreshing stock: $e');
    } finally {
      _isRefreshingStock = false;
      notifyListeners();
    }
  }

  /// Periodic background refresh (full catalog every 20 minutes)
  void _startPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    
    debugPrint('⏰ CatalogProvider: Starting periodic refresh (every 20 minutes)');
    
    _periodicRefreshTimer = Timer.periodic(const Duration(minutes: 20), (timer) async {
      if (_currentOutletId != null) {
        debugPrint('🔄 CatalogProvider: Auto-refreshing catalog (20-minute timer)');
        
        try {
          // Reload everything in background without showing loading indicator
          await Future.wait([
            _categoryService.getCategoriesForOutlet(_currentOutletId!),
            _productService.getProductsForOutlet(_currentOutletId!),
            _taxRateService.getAllTaxRates(),
            _promotionService.loadActivePromotions(_currentOutletId!),
            _packagedDealService.loadActiveDeals(_currentOutletId!),
          ]);
          
          // Reload stock
          await _stockService.loadStockForOutlet(_currentOutletId!, _products);
          
          // Rebuild product map and promotions
          _buildProductsByCategory();
          _buildProductsWithPromotionsSet();
          
          debugPrint('✅ CatalogProvider: Background refresh completed');
          notifyListeners();
        } catch (e) {
          debugPrint('❌ CatalogProvider: Background refresh failed - $e');
        }
      }
    });
  }

  /// Stop periodic refresh
  void stopPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = null;
    debugPrint('⏹️ CatalogProvider: Periodic refresh stopped');
  }

  /// Build productsByCategory map grouping products by category_id
  void _buildProductsByCategory() {
    _productsByCategory.clear();
    _hasUncategorizedProducts = false;

    debugPrint('📦 CatalogProvider._buildProductsByCategory: Grouping ${_products.length} products');
    
    for (final product in _products) {
      // Use special uncategorized ID for products without category
      final categoryId = product.categoryId ?? uncategorizedCategoryId;
      
      if (categoryId == uncategorizedCategoryId) {
        _hasUncategorizedProducts = true;
      }
      
      if (!_productsByCategory.containsKey(categoryId)) {
        _productsByCategory[categoryId] = [];
      }
      
      _productsByCategory[categoryId]!.add(product);
      
      // Debug carvery products
      if (product.isCarvery) {
        debugPrint('   🥩 Carvery product added: ${product.name} → category: $categoryId');
      }
    }

    // Sort products within each category by sort_order then name
    for (final list in _productsByCategory.values) {
      list.sort((a, b) {
        final sortCompare = a.sortOrder.compareTo(b.sortOrder);
        if (sortCompare != 0) return sortCompare;
        return a.name.compareTo(b.name);
      });
    }

    debugPrint('📦 CatalogProvider: Products grouped into ${_productsByCategory.length} categories');
    if (_hasUncategorizedProducts) {
      debugPrint('📦 CatalogProvider: Found ${_productsByCategory[uncategorizedCategoryId]?.length ?? 0} uncategorized products');
    }
  }

  /// Select a category and update UI
  void selectCategory(String categoryId) {
    if (_selectedCategoryId != categoryId) {
      _selectedCategoryId = categoryId;
      
      // Enhanced logging to track navigation issues
      final categoryName = categoryId == specialsCategoryId 
          ? "Today's Specials" 
          : categoryId == uncategorizedCategoryId 
              ? "Uncategorized" 
              : getCategoryById(categoryId)?.name ?? 'Unknown';
      
      debugPrint('🏷️ CatalogProvider: Category selected: $categoryName (ID: $categoryId)');
      debugPrint('   Navigation stack depth: ${_categoryNavigationStack.length}');
      debugPrint('   Current parent category: $_currentParentCategoryId');
      
      // Warn if stuck state might occur
      if ((categoryId == specialsCategoryId || categoryId == uncategorizedCategoryId) && 
          _categoryNavigationStack.isEmpty) {
        debugPrint('⚠️  Special/Uncategorized category selected with empty navigation stack');
        debugPrint('   Use Home button to reset if you get stuck!');
      }
      
      notifyListeners();
    }
  }

  /// Set current parent category when viewing sub-categories
  void setParentCategory(String? parentId) {
    _currentParentCategoryId = parentId;
    debugPrint('📂 CatalogProvider: Parent category set: $parentId');
    notifyListeners();
  }

  /// Get top-level categories (parent_id is null)
  List<models.Category> getTopLevelCategories() {
    return _categories.where((c) => c.parentId == null).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Get sub-categories for a parent category
  List<models.Category> getSubCategories(String parentId) {
    return _categories.where((c) => c.parentId == parentId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Check if a category has sub-categories
  bool hasSubCategories(String categoryId) {
    return _categories.any((c) => c.parentId == categoryId);
  }

  /// Get category by ID
  models.Category? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Recursively get all descendant category IDs (children, grandchildren, etc.)
  Set<String> getDescendantCategoryIds(String categoryId) {
    final descendants = <String>{};
    final directChildren = getSubCategories(categoryId);
    
    for (final child in directChildren) {
      descendants.add(child.id);
      // Recursively add all descendants of this child
      descendants.addAll(getDescendantCategoryIds(child.id));
    }
    
    return descendants;
  }

  /// Get the full path from root to a category (list of category IDs)
  List<String> getCategoryPath(String categoryId) {
    final path = <String>[];
    String? currentId = categoryId;
    
    // Walk up the tree from child to parent
    while (currentId != null) {
      path.insert(0, currentId); // Insert at beginning to build path from root
      final category = getCategoryById(currentId);
      currentId = category?.parentId;
    }
    
    return path;
  }

  /// Navigate into a category (drill down)
  void navigateToCategory(String categoryId) {
    _categoryNavigationStack.add(categoryId);
    _selectedCategoryId = categoryId;
    debugPrint('🗂️ CatalogProvider: Navigated to category: $categoryId');
    debugPrint('   Navigation stack: $_categoryNavigationStack');
    notifyListeners();
  }

  /// Navigate back one level (breadcrumb back)
  void navigateBack() {
    if (_categoryNavigationStack.isEmpty) {
      debugPrint('⚠️ CatalogProvider: Cannot navigate back - stack is empty');
      return;
    }
    
    final removedCategory = _categoryNavigationStack.last;
    _categoryNavigationStack.removeLast();
    
    if (_categoryNavigationStack.isEmpty) {
      _selectedCategoryId = null;
      debugPrint('🔙 CatalogProvider: Navigated back to root (showing top-level categories)');
    } else {
      _selectedCategoryId = _categoryNavigationStack.last;
      final categoryName = getCategoryById(_selectedCategoryId!)?.name ?? _selectedCategoryId;
      debugPrint('🔙 CatalogProvider: Navigated back to: $categoryName');
    }
    
    debugPrint('   Removed: ${getCategoryById(removedCategory)?.name ?? removedCategory}');
    debugPrint('   Navigation stack depth: ${_categoryNavigationStack.length}');
    notifyListeners();
  }

  /// Reset navigation to top level
  void resetNavigation() {
    debugPrint('🗂️ CatalogProvider: Resetting navigation');
    debugPrint('   Previous navigation stack: $_categoryNavigationStack');
    debugPrint('   Previous selected category: $_selectedCategoryId');
    
    _categoryNavigationStack.clear();
    _selectedCategoryId = null;
    
    debugPrint('✅ CatalogProvider: Navigation reset complete - now showing top-level categories');
    notifyListeners();
  }

  /// Get the current display mode (categories or products)
  /// Returns 'categories' if showing category buttons, 'products' if showing products
  String getCurrentDisplayMode() {
    if (_categoryNavigationStack.isEmpty) {
      return 'categories'; // Show top-level categories
    }
    
    final currentCategoryId = _categoryNavigationStack.last;
    final hasChildren = hasSubCategories(currentCategoryId);
    
    return hasChildren ? 'categories' : 'products';
  }

  /// Get categories to display in the current navigation level
  List<models.Category> getCurrentCategories() {
    if (_categoryNavigationStack.isEmpty) {
      // Show top-level categories
      final topLevel = getTopLevelCategories();
      
      // Add special pseudo-categories
      final result = List<models.Category>.from(topLevel);
      
      if (hasSpecials) {
        result.add(models.Category(
          id: specialsCategoryId,
          outletId: _currentOutletId ?? '',
          name: 'Specials',
          sortOrder: -1,
          createdAt: DateTime.now(),
        ));
      }
      
      if (hasUncategorizedProducts) {
        result.add(models.Category(
          id: uncategorizedCategoryId,
          outletId: _currentOutletId ?? '',
          name: 'Uncategorized',
          sortOrder: 999,
          createdAt: DateTime.now(),
        ));
      }
      
      return result..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    
    // Show sub-categories of current category
    final currentCategoryId = _categoryNavigationStack.last;
    return getSubCategories(currentCategoryId);
  }

  /// Get products to display in the current navigation level
  /// Includes products from this category AND all descendant categories
  List<Product> getCurrentProductsForDisplay() {
    if (_categoryNavigationStack.isEmpty) return [];
    
    final currentCategoryId = _categoryNavigationStack.last;
    
    // Handle special categories
    if (currentCategoryId == specialsCategoryId) {
      return getSpecialProductsForToday();
    }
    
    if (currentCategoryId == uncategorizedCategoryId) {
      return _productsByCategory[uncategorizedCategoryId] ?? [];
    }
    
    // Collect products from this category AND all descendant categories
    final allProducts = <Product>[];
    
    // Add products directly in this category
    final directProducts = _productsByCategory[currentCategoryId] ?? [];
    allProducts.addAll(directProducts);
    
    debugPrint('🗂️ CatalogProvider.getCurrentProductsForDisplay: Category $currentCategoryId');
    debugPrint('   Direct products: ${directProducts.length}');
    
    // Add products from all descendant categories
    final descendantIds = getDescendantCategoryIds(currentCategoryId);
    debugPrint('   Descendant categories: ${descendantIds.length}');
    
    for (final descendantId in descendantIds) {
      final descendantProducts = _productsByCategory[descendantId] ?? [];
      debugPrint('     - $descendantId: ${descendantProducts.length} products');
      allProducts.addAll(descendantProducts);
    }
    
    debugPrint('   Total products for display: ${allProducts.length}');
    
    // Count carvery products in display list
    final carveryInDisplay = allProducts.where((p) => p.isCarvery).length;
    if (carveryInDisplay > 0) {
      debugPrint('   🥩 Carvery products in display: $carveryInDisplay');
      for (final p in allProducts.where((p) => p.isCarvery)) {
        debugPrint('      - ${p.name} (${p.id})');
      }
    }
    
    // Sort by category, then sort_order, then name
    allProducts.sort((a, b) {
      final catCompare = (a.categoryId ?? '').compareTo(b.categoryId ?? '');
      if (catCompare != 0) return catCompare;
      
      final sortCompare = a.sortOrder.compareTo(b.sortOrder);
      if (sortCompare != 0) return sortCompare;
      
      return a.name.compareTo(b.name);
    });
    
    return allProducts;
  }

  /// Get breadcrumb trail (list of category names)
  List<BreadcrumbItem> getBreadcrumbTrail() {
    final trail = <BreadcrumbItem>[
      BreadcrumbItem(name: 'All Categories', categoryId: null, index: -1),
    ];
    
    for (int i = 0; i < _categoryNavigationStack.length; i++) {
      final categoryId = _categoryNavigationStack[i];
      final category = getCategoryById(categoryId);
      
      if (category != null) {
        trail.add(BreadcrumbItem(
          name: category.name,
          categoryId: categoryId,
          index: i,
        ));
      }
    }
    
    return trail;
  }

  /// Search products by name or PLU
  Future<List<Product>> searchProducts(String query, String outletId) async {
    if (query.isEmpty) return [];

    try {
      final result = await _productService.searchProducts(query, outletId);
      return result.data ?? [];
    } catch (e) {
      debugPrint('❌ CatalogProvider: Search failed - $e');
      return [];
    }
  }

  /// Get tax rate by ID
  TaxRate? getTaxRateById(String? taxRateId) {
    if (taxRateId == null) return null;
    
    try {
      return _taxRates.firstWhere((rate) => rate.id == taxRateId);
    } catch (e) {
      return null;
    }
  }

  /// Build set of product IDs that have active promotions right now
  void _buildProductsWithPromotionsSet() {
    _productIdsWithActivePromotions.clear();
    
    final activePromotions = _promotionService.getActivePromotionsForNow();
    debugPrint('[CATALOG_PROVIDER] Processing ${activePromotions.length} active promotions');
    
    for (final product in _products) {
      final hasPromotion = _promotionService.getPromotionsForProduct(product.id, product.categoryId).isNotEmpty;
      if (hasPromotion) {
        _productIdsWithActivePromotions.add(product.id);
      }
    }
    
    debugPrint('[CATALOG_PROVIDER] Found ${_productIdsWithActivePromotions.length} products with active promotions');
  }

  /// Check if a product has any active promotion
  bool isSpecialProduct(String productId) => _productIdsWithActivePromotions.contains(productId);

  /// Get all products that have active promotions right now
  List<Product> getSpecialProductsForToday() {
    if (_productIdsWithActivePromotions.isEmpty) return [];
    
    // Return products that have active promotions, sorted by category and sort_order
    final specialProducts = _products
        .where((p) => _productIdsWithActivePromotions.contains(p.id))
        .toList()
      ..sort((a, b) {
        // Group by category first
        final catCompare = (a.categoryId ?? '').compareTo(b.categoryId ?? '');
        if (catCompare != 0) return catCompare;
        
        // Then by sort order
        final sortCompare = a.sortOrder.compareTo(b.sortOrder);
        if (sortCompare != 0) return sortCompare;
        
        // Finally by name
        return a.name.compareTo(b.name);
      });
    
    debugPrint('🌟 CatalogProvider: getSpecialProductsForToday() returning ${specialProducts.length} products');
    return specialProducts;
  }

  /// Get packaged deal service for use by OrderProvider
  PackagedDealService get packagedDealService => _packagedDealService;

  /// Clear all catalog data
  void clear() {
    _categories = [];
    _products = [];
    _productsByCategory = {};
    _taxRates = [];
    _selectedCategoryId = null;
    _currentParentCategoryId = null;
    _productIdsWithActivePromotions = {};
    _hasUncategorizedProducts = false;
    _categoryNavigationStack = [];
    _errorMessage = null;
    _isLoading = false;
    _isRefreshingStock = false;
    _currentOutletId = null;
    _stockService.clear();
    _packagedDealService.clearCache();
    stopPeriodicRefresh();
    notifyListeners();
  }

  /// Run stock diagnostics to identify why stock info might be missing
  Future<void> _runStockDiagnostics(String outletId) async {
    debugPrint('');
    debugPrint('─────────────────────────────────────────────────────────');
    debugPrint('[STOCK_DIAGNOSTICS] Checking stock configuration');
    debugPrint('─────────────────────────────────────────────────────────');
    
    // Find all products that claim to track stock
    final stockTrackedProducts = _products.where((p) => p.trackStock).toList();
    
    if (stockTrackedProducts.isEmpty) {
      debugPrint('[STOCK_DIAGNOSTICS] No products configured to track stock');
      debugPrint('─────────────────────────────────────────────────────────');
      debugPrint('');
      return;
    }
    
    debugPrint('[STOCK_DIAGNOSTICS] Found ${stockTrackedProducts.length} products configured to track stock');
    
    int withStockInfo = 0;
    int withoutStockInfo = 0;
    int withLinkedInventory = 0;
    int withoutLinkedInventory = 0;
    
    for (final product in stockTrackedProducts) {
      final stockInfo = _stockService.getStockInfoForProduct(product.id);
      
      if (stockInfo != null) {
        withStockInfo++;
      } else {
        withoutStockInfo++;
        
        // Diagnose why stock info is missing
        if (product.linkedInventoryItemId != null) {
          withLinkedInventory++;
          debugPrint('[STOCK_DIAGNOSTICS] ⚠️ "${product.name}":');
          debugPrint('  - Has linkedInventoryItemId: ${product.linkedInventoryItemId}');
          debugPrint('  - But stock info is NULL');
          debugPrint('  - Possible cause: Linked inventory item does not exist or has no quantity');
        } else {
          withoutLinkedInventory++;
          debugPrint('[STOCK_DIAGNOSTICS] ⚠️ "${product.name}":');
          debugPrint('  - trackStock=true but linkedInventoryItemId=null');
          debugPrint('  - Should use recipe-based tracking (enhanced mode)');
          debugPrint('  - Possible cause: No active recipe defined for this product');
        }
      }
    }
    
    debugPrint('');
    debugPrint('[STOCK_DIAGNOSTICS] Summary:');
    debugPrint('  Products with stock info loaded: $withStockInfo');
    debugPrint('  Products missing stock info: $withoutStockInfo');
    debugPrint('    - With linkedInventoryItemId: $withLinkedInventory (inventory item may not exist)');
    debugPrint('    - Without linkedInventoryItemId: $withoutLinkedInventory (need recipe-based tracking)');
    debugPrint('─────────────────────────────────────────────────────────');
    debugPrint('');
  }

  @override
  void dispose() {
    stopPeriodicRefresh();
    super.dispose();
  }
}

/// Breadcrumb item for category navigation
class BreadcrumbItem {
  final String name;
  final String? categoryId; // null for root "All Categories"
  final int index; // Position in stack (-1 for root)

  BreadcrumbItem({
    required this.name,
    required this.categoryId,
    required this.index,
  });
}

