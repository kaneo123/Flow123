import 'package:flutter/material.dart';
import 'package:flowtill/models/category.dart' as models;
import 'package:flowtill/theme.dart';

class CategoryButton extends StatelessWidget {
  final models.Category category;
  final VoidCallback? onTap;
  final bool hasSubCategories;

  const CategoryButton({
    super.key,
    required this.category,
    required this.onTap,
    this.hasSubCategories = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final buttonHeight = isMobile ? 100.0 : 120.0;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: buttonHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: isMobile ? AppSpacing.paddingSm : AppSpacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.name,
                        style: (isMobile 
                            ? context.textStyles.titleSmall 
                            : context.textStyles.titleMedium)?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: EdgeInsets.all(isMobile ? 6 : AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasSubCategories ? Icons.arrow_forward : Icons.category,
                      size: isMobile ? 16 : 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
