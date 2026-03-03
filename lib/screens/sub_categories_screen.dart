import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/providers/catalog_provider.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/services/modifier_service.dart';
import 'package:flowtill/widgets/till/top_app_bar.dart';
import 'package:flowtill/widgets/till/product_grid_panel.dart';
import 'package:flowtill/widgets/till/order_panel.dart';
import 'package:flowtill/widgets/till/bottom_action_bar.dart';
import 'package:flowtill/theme.dart';
import 'package:flowtill/models/category.dart' as models;

class SubCategoriesScreen extends StatefulWidget {
  final String parentCategoryId;

  const SubCategoriesScreen({
    super.key,
    required this.parentCategoryId,
  });

  @override
  State<SubCategoriesScreen> createState() => _SubCategoriesScreenState();
}

class _SubCategoriesScreenState extends State<SubCategoriesScreen> {
  final _modifierService = ModifierService();
  String? _selectedSubCategoryId;

  @override
  void initState() {
    super.initState();
    debugPrint('📂 SubCategoriesScreen: Initialized for parent category: ${widget.parentCategoryId}');
    
    // Auto-select first sub-category on load and load modifiers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load modifiers first
      _loadModifiers();
      
      final catalogProvider = context.read<CatalogProvider>();
      final parentCategory = catalogProvider.getCategoryById(widget.parentCategoryId);
      final subCategories = catalogProvider.getSubCategories(widget.parentCategoryId);
      
      debugPrint('📂 SubCategoriesScreen: Parent category name: ${parentCategory?.name ?? "Unknown"}');
      debugPrint('   Sub-categories count: ${subCategories.length}');
      
      if (subCategories.isEmpty) {
        debugPrint('⚠️  SubCategoriesScreen: No sub-categories found! User might get stuck.');
        debugPrint('   This category may have been misconfigured.');
      }
      
      if (subCategories.isNotEmpty && _selectedSubCategoryId == null) {
        setState(() => _selectedSubCategoryId = subCategories.first.id);
        catalogProvider.selectCategory(subCategories.first.id);
        debugPrint('✅ SubCategoriesScreen: Auto-selected first sub-category: ${subCategories.first.name}');
      }
    });
  }
  
  Future<void> _loadModifiers() async {
    final outletProvider = context.read<OutletProvider>();
    final currentOutlet = outletProvider.currentOutlet;
    
    if (currentOutlet == null) {
      debugPrint('❌ SubCategoriesScreen: No outlet selected, cannot load modifiers');
      return;
    }
    
    debugPrint('🔧 SubCategoriesScreen: Loading modifiers for outlet ${currentOutlet.name} (${currentOutlet.id})');
    final success = await _modifierService.loadModifiersForOutlet(currentOutlet.id);
    
    if (success) {
      debugPrint('✅ SubCategoriesScreen: Modifiers loaded successfully');
      debugPrint('   isLoaded: ${_modifierService.isLoaded}');
      
      // Check for the specific product
      const testProductId = 'd6f42c99-16c8-4010-9b22-7c897265d2d3';
      final hasModifiers = _modifierService.hasModifiers(testProductId);
      final links = _modifierService.getLinksForProduct(testProductId);
      debugPrint('   Test product ($testProductId) hasModifiers: $hasModifiers');
      debugPrint('   Test product has ${links.length} links');
    } else {
      debugPrint('❌ SubCategoriesScreen: Failed to load modifiers');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              TopAppBar(modifierService: _modifierService),
              _buildSubCategoryTabs(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1200;

                    if (isMobile) {
                      return Column(
                        children: [
                          Expanded(
                            flex: 7,
                            child: ProductGridPanel(modifierService: _modifierService),
                          ),
                          Expanded(
                            flex: 3,
                            child: OrderPanel(modifierService: _modifierService),
                          ),
                        ],
                      );
                    }

                    final leftFlex = isTablet ? 5 : 6;
                    final rightFlex = isTablet ? 5 : 4;

                    return Row(
                      children: [
                        Expanded(
                          flex: leftFlex,
                          child: ProductGridPanel(modifierService: _modifierService),
                        ),
                        Expanded(
                          flex: rightFlex,
                          child: OrderPanel(modifierService: _modifierService),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const BottomActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubCategoryTabs() {
    final catalogProvider = context.watch<CatalogProvider>();
    final parentCategory = catalogProvider.getCategoryById(widget.parentCategoryId);
    final subCategories = catalogProvider.getSubCategories(widget.parentCategoryId);
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (subCategories.isEmpty) {
      return Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Center(
          child: Text(
            'No sub-categories available',
            style: context.textStyles.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: isMobile ? AppSpacing.paddingMd : AppSpacing.paddingLg,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb Trail
          _buildBreadcrumb(catalogProvider, parentCategory),
          const SizedBox(height: AppSpacing.md),
          // Sub-Category Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Back Button
                _buildBackButton(),
                const SizedBox(width: AppSpacing.md),
                // Home Button (failsafe)
                _buildHomeButton(),
                const SizedBox(width: AppSpacing.md),
                // Sub-Category Tabs
                ...subCategories.map((subCategory) => 
                  _buildSubCategoryTab(subCategory, catalogProvider)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(CatalogProvider catalogProvider, models.Category? parentCategory) {
    if (parentCategory == null) return const SizedBox.shrink();

    final categoryPathIds = catalogProvider.getCategoryPath(widget.parentCategoryId);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Icon(
            Icons.folder_outlined,
            size: isMobile ? 16 : 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          ...categoryPathIds.asMap().entries.map((entry) {
            final index = entry.key;
            final categoryId = entry.value;
            final category = catalogProvider.getCategoryById(categoryId);
            final isLast = index == categoryPathIds.length - 1;

            if (category == null) return const SizedBox.shrink();

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.name,
                  style: (isMobile 
                      ? context.textStyles.bodyMedium 
                      : context.textStyles.bodyLarge)?.copyWith(
                    color: isLast 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (!isLast) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    size: isMobile ? 14 : 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          debugPrint('🔙 SubCategoriesScreen: Back button tapped from category ${widget.parentCategoryId}');
          final catalogProvider = context.read<CatalogProvider>();
          catalogProvider.setParentCategory(null);
          catalogProvider.selectCategory(widget.parentCategoryId);
          context.pop();
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? AppSpacing.md : AppSpacing.lg,
            vertical: isMobile ? 6 : AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back,
                size: isMobile ? 16 : 20,
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

  Widget _buildHomeButton() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          debugPrint('🏠 SubCategoriesScreen: Home button tapped - returning to main screen');
          final catalogProvider = context.read<CatalogProvider>();
          final topLevelCategories = catalogProvider.getTopLevelCategories();
          
          // Pop all the way back to main till screen
          while (context.canPop()) {
            context.pop();
          }
          
          // Select first top-level category
          if (topLevelCategories.isNotEmpty) {
            catalogProvider.selectCategory(topLevelCategories.first.id);
          }
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? AppSpacing.md : AppSpacing.lg,
            vertical: isMobile ? 6 : AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.home,
                size: isMobile ? 16 : 20,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Home',
                style: (isMobile 
                    ? context.textStyles.titleSmall 
                    : context.textStyles.titleMedium)?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubCategoryTab(
    models.Category subCategory,
    CatalogProvider catalogProvider,
  ) {
    final isSelected = _selectedSubCategoryId == subCategory.id;
    final hasChildren = catalogProvider.hasSubCategories(subCategory.id);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.only(right: isMobile ? 6 : AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (hasChildren) {
              // Navigate to deeper level
              debugPrint('📂 SubCategoriesScreen: Category ${subCategory.name} has children, navigating deeper');
              context.push('/sub-categories/${subCategory.id}');
            } else {
              // Leaf category - select it directly
              debugPrint('🏷️ SubCategoriesScreen: Leaf category ${subCategory.name} selected');
              setState(() => _selectedSubCategoryId = subCategory.id);
              catalogProvider.selectCategory(subCategory.id);
            }
          },
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? AppSpacing.md : AppSpacing.lg,
              vertical: isMobile ? 6 : AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  subCategory.name,
                  style: (isMobile 
                      ? context.textStyles.titleSmall 
                      : context.textStyles.titleMedium)?.copyWith(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasChildren) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    size: isMobile ? 16 : 18,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
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
