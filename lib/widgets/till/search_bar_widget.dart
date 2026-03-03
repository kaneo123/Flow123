import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/models/product.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/providers/catalog_provider.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/services/modifier_service.dart';
import 'package:flowtill/widgets/till/modifiers_modal.dart';
import 'package:flowtill/theme.dart';

class SearchBarWidget extends StatefulWidget {
  final ModifierService modifierService;

  const SearchBarWidget({
    super.key,
    required this.modifierService,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final outletId = context.read<OutletProvider>().currentOutlet?.id;
    if (outletId != null) {
      final results = await context.read<CatalogProvider>().searchProducts(query, outletId);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _addProductToOrder(Product product) async {
    final catalogProvider = context.read<CatalogProvider>();
    final stockInfo = catalogProvider.getStockInfo(product.id);
    
    // Don't add if out of stock
    if (stockInfo != null && stockInfo.isOutOfStock) return;
    
    final taxRate = catalogProvider.getTaxRateById(product.taxRateId);
    
    // Check if product has modifiers
    if (widget.modifierService.isLoaded && widget.modifierService.hasModifiers(product.id)) {
      debugPrint('   🔧 Product has modifiers, showing modal...');
      
      final selectedModifiers = await showDialog(
        context: context,
        builder: (context) => ModifiersModal(
          product: product,
          modifierService: widget.modifierService,
        ),
      );
      
      if (selectedModifiers != null) {
        debugPrint('   ✅ Modifiers selected: ${selectedModifiers.length}');
        context.read<OrderProvider>().addProduct(
          product,
          taxRate?.rate ?? 0.0,
          selectedModifiers: selectedModifiers,
        );
      } else {
        debugPrint('   ❌ Modifiers modal cancelled');
        return; // Don't clear search if cancelled
      }
    } else {
      // No modifiers, add directly
      context.read<OrderProvider>().addProduct(product, taxRate?.rate ?? 0.0);
    }
    
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
            ),
            child: TextField(
              controller: _searchController,
              style: context.textStyles.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: context.textStyles.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 24),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: AppSpacing.horizontalMd,
              ),
              onChanged: _performSearch,
            ),
          ),
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Consumer<CatalogProvider>(
                builder: (context, catalogProvider, _) => ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final product = _searchResults[index];
                    final stockInfo = catalogProvider.getStockInfo(product.id);
                    final isOutOfStock = stockInfo?.isOutOfStock ?? false;
                    final isAvailable = !isOutOfStock;
                    
                    return ListTile(
                      title: Text(
                        product.name,
                        style: context.textStyles.bodyMedium?.semiBold.copyWith(
                          color: isAvailable ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Text('£${product.price.toStringAsFixed(2)}', style: context.textStyles.bodySmall),
                          if (!isAvailable) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Out of stock',
                              style: context.textStyles.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Icon(
                        Icons.add_circle,
                        color: isAvailable
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      onTap: isAvailable ? () => _addProductToOrder(product) : null,
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
