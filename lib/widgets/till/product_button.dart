import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/models/product.dart';
import 'package:flowtill/models/product_stock_info.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/providers/catalog_provider.dart';
import 'package:flowtill/theme.dart';

class ProductButton extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final bool isAvailable;

  const ProductButton({
    super.key,
    required this.product,
    required this.onTap,
    this.isAvailable = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = !isAvailable;
    final outletProvider = context.watch<OutletProvider>();
    final catalogProvider = context.watch<CatalogProvider>();
    final quantityWatchEnabled = outletProvider.quantityWatchEnabled;
    final highlightSpecials = outletProvider.outletSettings?.highlightSpecials ?? true;
    final isSpecial = catalogProvider.isSpecialProduct(product.id);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final buttonHeight = isMobile ? 100.0 : 120.0;
    
    // Enhanced debugging for carvery products
    if (product.isCarvery) {
      debugPrint('🎨 ProductButton.build: Rendering carvery product');
      debugPrint('   Name: ${product.name}');
      debugPrint('   ID: ${product.id}');
      debugPrint('   isCarvery: ${product.isCarvery}');
      debugPrint('   Price: £${product.price.toStringAsFixed(2)}');
      debugPrint('   isAvailable: $isAvailable');
      debugPrint('   isDisabled: $isDisabled');
    }
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null ? () {
          debugPrint('🔘 ProductButton: Tap detected on ${product.name}');
          debugPrint('   Disabled: $isDisabled');
          debugPrint('   Calling onTap callback...');
          onTap!();
          debugPrint('   ✅ onTap callback completed');
        } : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          children: [
            Container(
              height: buttonHeight,
              decoration: BoxDecoration(
                color: isDisabled 
                    ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isDisabled
                      ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: isMobile ? AppSpacing.paddingSm : AppSpacing.paddingMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              product.name,
                              style: (isMobile 
                                  ? context.textStyles.titleSmall 
                                  : context.textStyles.titleMedium)?.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                color: isDisabled 
                                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                            ),
                          ),
                          if (isSpecial && highlightSpecials)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: isMobile ? 12 : 14,
                                    color: Theme.of(context).colorScheme.tertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Special',
                                    style: (isMobile 
                                        ? context.textStyles.labelSmall 
                                        : context.textStyles.bodySmall)?.copyWith(
                                      color: Theme.of(context).colorScheme.tertiary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: isMobile ? 10 : 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          if (isDisabled)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Out of stock',
                                style: (isMobile 
                                    ? context.textStyles.labelSmall 
                                    : context.textStyles.bodySmall)?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            '£${product.price.toStringAsFixed(2)}',
                            style: (isMobile 
                                ? context.textStyles.titleMedium 
                                : context.textStyles.titleLarge)?.copyWith(
                              color: isDisabled
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                                  : Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (!isDisabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.all(isMobile ? 6 : AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add,
                              size: isMobile ? 16 : 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Quantity Watch Badge (top-right)
            if (quantityWatchEnabled)
              Positioned(
                top: 8,
                right: 8,
                child: _QuantityBadge(product: product),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuantityBadge extends StatelessWidget {
  final Product product;

  const _QuantityBadge({required this.product});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final catalogProvider = context.watch<CatalogProvider>();
    final stockInfo = catalogProvider.getStockInfo(product.id);
    
    // 🧾 Debug for Roast Beef
    if (product.id == 'b8ca25d0-3bc8-4d5b-9122-c69090fd4195') {
      debugPrint('🧾 ProductButton badge for Roast Beef:');
      debugPrint('🧾   stockInfo: ${stockInfo != null ? 'EXISTS' : 'NULL'}');
      if (stockInfo != null) {
        debugPrint('🧾   trackStock: ${stockInfo.trackStock}');
        debugPrint('🧾   isBasicMode: ${stockInfo.isBasicMode}');
        debugPrint('🧾   isEnhancedMode: ${stockInfo.isEnhancedMode}');
        debugPrint('🧾   currentQty: ${stockInfo.currentQty}');
        debugPrint('🧾   portionsRemaining: ${stockInfo.portionsRemaining}');
        debugPrint('🧾   displayQuantity: ${stockInfo.displayQuantity}');
      }
    }
    
    // Determine what to display
    final String displayText;
    final Color backgroundColor;
    final Color textColor;
    
    if (stockInfo != null && stockInfo.trackStock) {
      // Get quantity from stock info
      displayText = stockInfo.displayQuantity;
      
      // Color coding based on stock level
      if (displayText == '!') {
        // Config issue - show warning color
        backgroundColor = colorScheme.tertiaryContainer;
        textColor = colorScheme.onTertiaryContainer;
      } else if (stockInfo.isOutOfStock) {
        backgroundColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
      } else {
        final numericQty = stockInfo.numericQuantity;
        if (numericQty <= 5) {
          backgroundColor = colorScheme.tertiaryContainer;
          textColor = colorScheme.onTertiaryContainer;
        } else {
          backgroundColor = colorScheme.surfaceContainerHighest;
          textColor = colorScheme.onSurface;
        }
      }
    } else {
      // Show infinity symbol for non-tracked products
      displayText = '∞';
      backgroundColor = colorScheme.surfaceContainerHighest;
      textColor = colorScheme.onSurface;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        displayText,
        style: context.textStyles.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
