import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/providers/catalog_provider.dart';
import 'package:flowtill/theme.dart';

class CategoryTabs extends StatelessWidget {
  const CategoryTabs({super.key});


  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Consumer<CatalogProvider>(
      builder: (context, catalogProvider, _) {
        // Only show top-level categories (parent_id is null)
        final topLevelCategories = catalogProvider.getTopLevelCategories();
        final selectedId = catalogProvider.selectedCategoryId;
        final hasSpecials = catalogProvider.hasSpecials;
        final hasUncategorized = catalogProvider.hasUncategorizedProducts;

        if (topLevelCategories.isEmpty && !hasUncategorized) {
          return const SizedBox.shrink();
        }

        // Check if we're on a special category (Specials or Uncategorized)
        final isOnSpecialCategory = selectedId == CatalogProvider.specialsCategoryId || 
                                    selectedId == CatalogProvider.uncategorizedCategoryId;

        debugPrint('🔍 CategoryTabs: selectedId=$selectedId, specialsId=${CatalogProvider.specialsCategoryId}, uncategorizedId=${CatalogProvider.uncategorizedCategoryId}');
        debugPrint('🔍 CategoryTabs: isOnSpecialCategory=$isOnSpecialCategory');

        // Build tabs list with conditional Back button
        final tabsList = <Widget>[];

        // If on Specials/Uncategorized, show Back button first
        if (isOnSpecialCategory) {
          debugPrint('✅ CategoryTabs: Adding Back button for special category');
          tabsList.add(_buildBackButton(context, isMobile, () {
            debugPrint('🔙 CategoryTabs: Back from special category - resetting to first category');
            // Reset to first top-level category
            if (topLevelCategories.isNotEmpty) {
              catalogProvider.selectCategory(topLevelCategories.first.id);
            }
          }));
        } else {
          debugPrint('❌ CategoryTabs: Not on special category, no Back button');
        }

        // Always show Home button
        tabsList.add(_buildTabButton(
          context: context,
          label: "🏠 Home",
          isSelected: false, // Always show as unselected to make it more prominent
          isMobile: isMobile,
          onTap: () {
            debugPrint('🏠 CategoryTabs: Home tapped - resetting to first category (current: $selectedId)');
            // Pop any sub-category screens first
            while (context.canPop()) {
              context.pop();
            }
            // Reset to first top-level category
            if (topLevelCategories.isNotEmpty) {
              catalogProvider.selectCategory(topLevelCategories.first.id);
            }
          },
          isHomeButton: true, // Special styling for Home button
        ));

        // Add Specials tab if we have specials
        if (hasSpecials) {
          final isSelected = selectedId == CatalogProvider.specialsCategoryId;
          debugPrint('🌟 CategoryTabs: Rendering Specials tab (hasSpecials=$hasSpecials, isSelected=$isSelected)');
          tabsList.add(_buildTabButton(
            context: context,
            label: "Today's Specials",
            icon: Icons.star,
            isSelected: isSelected,
            isMobile: isMobile,
            onTap: () {
              debugPrint('🌟 CategoryTabs: Tapping Specials tab');
              catalogProvider.selectCategory(CatalogProvider.specialsCategoryId);
            },
          ));
        }

        // Add regular top-level categories
        for (final category in topLevelCategories) {
          final isSelected = category.id == selectedId;
          final hasChildren = catalogProvider.hasSubCategories(category.id);

          tabsList.add(_buildTabButton(
            context: context,
            label: category.name,
            isSelected: isSelected,
            isMobile: isMobile,
            hasChildren: hasChildren,
            onTap: () {
              if (hasChildren) {
                // Navigate to sub-categories screen
                debugPrint('📂 CategoryTabs: Category "${category.name}" has children, navigating to sub-categories');
                debugPrint('   Category ID: ${category.id}');
                debugPrint('   Route: /sub-categories/${category.id}');
                context.push('/sub-categories/${category.id}');
              } else {
                // Leaf category - select it directly
                debugPrint('🏷️ CategoryTabs: Leaf category "${category.name}" selected');
                catalogProvider.selectCategory(category.id);
              }
            },
          ));
        }

        // Add Uncategorized tab if we have uncategorized products
        if (hasUncategorized) {
          final isSelected = selectedId == CatalogProvider.uncategorizedCategoryId;
          debugPrint('📦 CategoryTabs: Rendering Uncategorized tab (hasUncategorized=$hasUncategorized, isSelected=$isSelected)');
          tabsList.add(_buildTabButton(
            context: context,
            label: "Uncategorized",
            icon: Icons.category_outlined,
            isSelected: isSelected,
            isMobile: isMobile,
            onTap: () {
              debugPrint('📦 CategoryTabs: Tapping Uncategorized tab');
              catalogProvider.selectCategory(CatalogProvider.uncategorizedCategoryId);
            },
          ));
        }

        return Container(
          height: isMobile ? 48 : 56,
          padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : AppSpacing.sm),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: isMobile ? const EdgeInsets.symmetric(horizontal: 6) : AppSpacing.horizontalMd,
            itemCount: tabsList.length,
            separatorBuilder: (_, __) => SizedBox(width: isMobile ? 4 : AppSpacing.sm),
            itemBuilder: (context, index) => tabsList[index],
          ),
        );
      },
    );
  }

  Widget _buildBackButton(BuildContext context, bool isMobile, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          constraints: BoxConstraints(
            minWidth: isMobile ? 60 : 80,
            minHeight: isMobile ? 32 : 40,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? AppSpacing.md : AppSpacing.lg,
            vertical: isMobile ? 6 : AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back,
                size: isMobile ? 16 : 18,
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
    );
  }

  Widget _buildTabButton({
    required BuildContext context,
    required String label,
    IconData? icon,
    required bool isSelected,
    required bool isMobile,
    bool hasChildren = false,
    required VoidCallback onTap,
    bool isHomeButton = false,
  }) {
    // Special styling for Home button - make it stand out
    final backgroundColor = isHomeButton
        ? Theme.of(context).colorScheme.secondaryContainer
        : isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface;
    
    final borderColor = isHomeButton
        ? Theme.of(context).colorScheme.secondary
        : isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);
    
    final textColor = isHomeButton
        ? Theme.of(context).colorScheme.secondary
        : isSelected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: isMobile ? 60 : 80,
            minHeight: isMobile ? 32 : 40,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? AppSpacing.md : AppSpacing.lg,
              vertical: isMobile ? 6 : AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: borderColor,
                width: isHomeButton ? 2.0 : 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: isMobile ? 16 : 18,
                    color: textColor,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    maxLines: 1,
                    style: (isMobile 
                        ? context.textStyles.titleSmall 
                        : context.textStyles.titleMedium)?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasChildren) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    size: isMobile ? 16 : 18,
                    color: textColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
