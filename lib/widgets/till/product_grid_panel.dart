import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/providers/catalog_provider.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/services/modifier_service.dart';
import 'package:flowtill/widgets/till/search_bar_widget.dart';
import 'package:flowtill/widgets/till/category_tabs.dart';
import 'package:flowtill/widgets/till/product_button.dart';
import 'package:flowtill/widgets/till/category_button.dart';
import 'package:flowtill/widgets/till/modifiers_modal.dart';
import 'package:flowtill/theme.dart';

class ProductGridPanel extends StatelessWidget {
  final ModifierService modifierService;
  final double? mobileBottomPadding;
  static String? _lastLogSignature;

  const ProductGridPanel({
    super.key,
    required this.modifierService,
    this.mobileBottomPadding,
  });

  Widget _buildBreadcrumb(BuildContext context) {
    return Consumer<CatalogProvider>(
      builder: (context, catalogProvider, _) {
        final breadcrumbs = catalogProvider.getBreadcrumbTrail();
        final displayMode = catalogProvider.getCurrentDisplayMode();
        
        // Show breadcrumb when viewing products OR when navigation stack is not empty
        // This ensures users can always navigate back when they're viewing products
        final showBackButton = catalogProvider.categoryNavigationStack.isNotEmpty;
        
        if (!showBackButton) return const SizedBox.shrink();
        
        final isMobile = MediaQuery.of(context).size.width < 600;
        
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? AppSpacing.md : AppSpacing.lg,
            vertical: isMobile ? AppSpacing.sm : AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              // Back button - always visible and prominent
              Material(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  onTap: () {
                    debugPrint('🔙 ProductGridPanel: Back button tapped');
                    catalogProvider.navigateBack();
                  },
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 8 : 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back,
                          size: isMobile ? 18 : 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Back',
                          style: (isMobile 
                              ? context.textStyles.titleSmall 
                              : context.textStyles.titleMedium)?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Breadcrumb trail
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < breadcrumbs.length; i++) ...[
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (i == 0) {
                                catalogProvider.resetNavigation();
                              } else if (i < breadcrumbs.length - 1) {
                                // Navigate to this level by removing everything after it
                                while (catalogProvider.categoryNavigationStack.length > i) {
                                  catalogProvider.navigateBack();
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text(
                                breadcrumbs[i].name,
                                style: (isMobile 
                                    ? context.textStyles.bodySmall 
                                    : context.textStyles.bodyMedium)?.copyWith(
                                  color: i == breadcrumbs.length - 1
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.primary,
                                  fontWeight: i == breadcrumbs.length - 1 
                                      ? FontWeight.w600 
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (i < breadcrumbs.length - 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.chevron_right,
                              size: isMobile ? 14 : 16,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          _buildBreadcrumb(context),
          Expanded(
            child: Consumer<CatalogProvider>(
              builder: (context, catalogProvider, _) {
                final displayMode = catalogProvider.getCurrentDisplayMode();
                final categoriesCount = catalogProvider.getCurrentCategories().length;
                final productsCount =
                    catalogProvider.getCurrentProductsForDisplay().length;

                final signature =
                    '$displayMode|$categoriesCount|$productsCount|${catalogProvider.isLoading}|${catalogProvider.errorMessage ?? 'none'}';

                if (_lastLogSignature != signature) {
                  _lastLogSignature = signature;
                  debugPrint(
                    '🗂️ ProductGridPanel: mode=$displayMode, '
                    'categories=$categoriesCount, products=$productsCount, '
                    'loading=${catalogProvider.isLoading}, '
                    'error=${catalogProvider.errorMessage ?? 'none'}',
                  );
                }
                
                debugPrint('🗂️ ProductGridPanel: Display mode = $displayMode');
                
                // Determine what to show based on display mode
                if (displayMode == 'categories') {
                  return _buildCategoryGrid(context, catalogProvider);
                } else {
                  return _buildProductGrid(context, catalogProvider);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context, CatalogProvider catalogProvider) {
    final categories = catalogProvider.getCurrentCategories();
    
    debugPrint('🗂️ ProductGridPanel: Showing ${categories.length} categories');
    
    if (catalogProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (catalogProvider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Error loading catalog',
              style: context.textStyles.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              catalogProvider.errorMessage!,
              style: context.textStyles.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No categories available',
              style: context.textStyles.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = _calculateColumns(constraints.maxWidth);
        final aspectRatio = isMobile ? 1.2 : 1.4;
        
        // Add bottom padding in mobile to account for collapsed OrderPanel overlay
        final bottomPadding = isMobile ? (mobileBottomPadding ?? 110.0) : 0.0;
        
        return GridView.builder(
          padding: isMobile 
              ? EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm + bottomPadding,
                )
              : AppSpacing.paddingMd,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: isMobile ? AppSpacing.sm : AppSpacing.md,
            mainAxisSpacing: isMobile ? AppSpacing.sm : AppSpacing.md,
            childAspectRatio: aspectRatio,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final hasChildren = catalogProvider.hasSubCategories(category.id);
            
            return CategoryButton(
              category: category,
              hasSubCategories: hasChildren,
              onTap: () {
                debugPrint('🗂️ Category tapped: ${category.name} (${category.id})');
                debugPrint('   Has sub-categories: $hasChildren');
                catalogProvider.navigateToCategory(category.id);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProductGrid(BuildContext context, CatalogProvider catalogProvider) {
    final allProducts = catalogProvider.getCurrentProductsForDisplay();
    
    debugPrint('🗂️ ProductGridPanel._buildProductGrid: Got ${allProducts.length} products for display');
    
    // Count and log carvery products before filtering
    final carveryBeforeFilter = allProducts.where((p) => p.isCarvery).length;
    debugPrint('   🥩 Carvery products before filtering: $carveryBeforeFilter');
    if (carveryBeforeFilter > 0) {
      for (final p in allProducts.where((p) => p.isCarvery)) {
        debugPrint('      - ${p.name} (isCarvery=${p.isCarvery}, trackStock=${p.trackStock}, autoHide=${p.autoHideWhenOutOfStock})');
        final stockInfo = catalogProvider.getStockInfo(p.id);
        debugPrint('        Stock: ${stockInfo != null ? 'tracked=${stockInfo.trackStock}, outOfStock=${stockInfo.isOutOfStock}' : 'null'}');
      }
    }
    
    // Filter products based on stock and auto_hide setting
    final products = allProducts.where((product) {
      final stockInfo = catalogProvider.getStockInfo(product.id);
      
      // If product doesn't track stock, always show it
      if (stockInfo == null || !stockInfo.trackStock) return true;
      
      // If product is out of stock and has auto_hide enabled, hide it
      if (stockInfo.isOutOfStock && product.autoHideWhenOutOfStock) {
        debugPrint('   ⚠️ Hiding out-of-stock product: ${product.name}');
        return false;
      }
      
      // Otherwise show it (even if out of stock)
      return true;
    }).toList();
    
    // Count and log carvery products after filtering
    final carveryAfterFilter = products.where((p) => p.isCarvery).length;
    debugPrint('   🥩 Carvery products after filtering: $carveryAfterFilter');
    debugPrint('   📊 Final product count for display: ${products.length}');

    if (catalogProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No products in this category',
              style: context.textStyles.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = _calculateColumns(constraints.maxWidth);
        final aspectRatio = isMobile ? 1.2 : 1.4;
        
        // Add bottom padding in mobile to account for collapsed OrderPanel overlay
        final bottomPadding = isMobile ? (mobileBottomPadding ?? 110.0) : 0.0;
        
        return GridView.builder(
          padding: isMobile 
              ? EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm + bottomPadding,
                )
              : AppSpacing.paddingMd,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: isMobile ? AppSpacing.sm : AppSpacing.md,
            mainAxisSpacing: isMobile ? AppSpacing.sm : AppSpacing.md,
            childAspectRatio: aspectRatio,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final stockInfo = catalogProvider.getStockInfo(product.id);
            final isOutOfStock = stockInfo?.isOutOfStock ?? false;
            
            return ProductButton(
              product: product,
              isAvailable: !isOutOfStock,
              onTap: !isOutOfStock ? () async {
                debugPrint('🛒 ProductGridPanel: Product tapped: ${product.name} (${product.id})');
                debugPrint('   Price: £${product.price.toStringAsFixed(2)}');
                debugPrint('   Tax Rate ID: ${product.taxRateId ?? "null"}');
                
                final taxRate = catalogProvider.getTaxRateById(product.taxRateId);
                debugPrint('   Tax Rate Found: ${taxRate != null ? '${(taxRate.rate * 100).toStringAsFixed(1)}%' : 'null (using 0%)'}');
                
                final orderProvider = context.read<OrderProvider>();
                final currentOrder = orderProvider.currentOrder;
                
                debugPrint('   Current Order: ${currentOrder != null ? currentOrder.id : "NULL"}');
                debugPrint('   Current Items Count: ${currentOrder?.items.length ?? 0}');
                
                // Check if product has modifiers
                debugPrint('   🔧 Checking modifiers for product: ${product.id}');
                debugPrint('      ModifierService.isLoaded: ${modifierService.isLoaded}');
                debugPrint('      ModifierService.hasModifiers(${product.id}): ${modifierService.hasModifiers(product.id)}');
                
                if (modifierService.isLoaded) {
                  final links = modifierService.getLinksForProduct(product.id);
                  debugPrint('      Product has ${links.length} modifier links');
                  for (final link in links) {
                    debugPrint('         - Group: ${link.groupId} (required: ${link.requiredOverride})');
                  }
                }
                
                if (modifierService.isLoaded && modifierService.hasModifiers(product.id)) {
                  debugPrint('   🔧 Product has modifiers, showing modal...');
                  
                  final selectedModifiers = await showDialog(
                    context: context,
                    builder: (context) => ModifiersModal(
                      product: product,
                      modifierService: modifierService,
                    ),
                  );
                  
                  if (selectedModifiers != null) {
                    debugPrint('   ✅ Modifiers selected: ${selectedModifiers.length}');
                    orderProvider.addProduct(
                      product,
                      taxRate?.rate ?? 0.0,
                      selectedModifiers: selectedModifiers,
                    );
                  } else {
                    debugPrint('   ❌ Modifiers modal cancelled');
                  }
                } else {
                  // No modifiers, add directly
                  debugPrint('   📦 No modifiers, adding directly');
                  orderProvider.addProduct(
                    product,
                    taxRate?.rate ?? 0.0,
                  );
                }
                
                debugPrint('   ✅ Product handling complete');
              } : null,
            );
          },
        );
      },
    );
  }

  int _calculateColumns(double width) {
    if (width < 360) return 2;
    if (width < 600) return 3;
    if (width < 900) return 4;
    if (width < 1200) return 5;
    return 6;
  }
}
