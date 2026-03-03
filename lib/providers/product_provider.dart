import 'package:flutter/foundation.dart';
import 'package:flowtill/models/category.dart' as models;
import 'package:flowtill/models/product.dart';
import 'package:flowtill/models/tax_rate.dart';
import 'package:flowtill/services/category_service.dart';
import 'package:flowtill/services/product_service.dart';
import 'package:flowtill/services/tax_rate_service.dart';

class ProductProvider with ChangeNotifier {
  final CategoryService _categoryService = CategoryService();
  final ProductService _productService = ProductService();
  final TaxRateService _taxRateService = TaxRateService();

  List<models.Category> _categories = [];
  Map<String, List<Product>> _productsByCategory = {};
  List<TaxRate> _taxRates = [];
  String? _selectedCategoryId;
  bool _isLoading = false;

  List<models.Category> get categories => _categories;
  Map<String, List<Product>> get productsByCategory => _productsByCategory;
  List<TaxRate> get taxRates => _taxRates;
  String? get selectedCategoryId => _selectedCategoryId;
  bool get isLoading => _isLoading;

  List<Product> get currentProducts {
    if (_selectedCategoryId == null) return [];
    return _productsByCategory[_selectedCategoryId] ?? [];
  }

  Future<void> loadDataForOutlet(String outletId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final taxRatesResult = await _taxRateService.getAllTaxRates();
      _taxRates = taxRatesResult.data ?? [];
      
      final categoriesResult = await _categoryService.getCategoriesByOutlet(outletId);
      _categories = categoriesResult.data ?? [];
      
      if (_categories.isNotEmpty) {
        _selectedCategoryId = _categories.first.id;

        _productsByCategory.clear();
        for (final category in _categories) {
          final productsResult = await _productService.getProductsByCategory(category.id);
          _productsByCategory[category.id] = productsResult.data ?? [];
        }
      }
    } catch (e) {
      debugPrint('Error loading products for outlet: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void selectCategory(String categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  Future<List<Product>> searchProducts(String query, String outletId) async {
    final result = await _productService.searchProducts(query);
    return result.data ?? [];
  }

  TaxRate? getTaxRateById(String taxRateId) {
    try {
      return _taxRates.firstWhere((rate) => rate.id == taxRateId);
    } catch (e) {
      return null;
    }
  }
}
