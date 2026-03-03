import 'package:flutter/material.dart';
import 'package:flowtill/models/product.dart';
import 'package:flowtill/models/modifier_option.dart';
import 'package:flowtill/models/selected_modifier.dart';
import 'package:flowtill/services/modifier_service.dart';
import 'package:flowtill/theme.dart';

class ModifiersModal extends StatefulWidget {
  final Product product;
  final ModifierService modifierService;
  final List<SelectedModifier>? initialSelections;

  const ModifiersModal({
    super.key,
    required this.product,
    required this.modifierService,
    this.initialSelections,
  });

  @override
  State<ModifiersModal> createState() => _ModifiersModalState();
}

class _ModifiersModalState extends State<ModifiersModal> {
  // Map: groupId -> Set<optionId>
  final Map<String, Set<String>> _selections = {};
  late final List<ModifierGroupRules> _groupRules;

  @override
  void initState() {
    super.initState();
    _groupRules = widget.modifierService.getGroupsForProduct(widget.product.id);
    
    // Initialize selections with defaults or provided initial selections
    if (widget.initialSelections != null && widget.initialSelections!.isNotEmpty) {
      // Restore previous selections
      for (final selected in widget.initialSelections!) {
        _selections.putIfAbsent(selected.groupId, () => {}).add(selected.optionId);
      }
    } else {
      // Apply defaults
      for (final rules in _groupRules) {
        final defaults = widget.modifierService.getDefaultSelections(
          rules.group.id,
          rules.group.selectionType,
        );
        if (defaults.isNotEmpty) {
          _selections[rules.group.id] = defaults.map((opt) => opt.id).toSet();
        }
      }
    }
  }

  bool _isValid() {
    for (final rules in _groupRules) {
      final selected = _selections[rules.group.id] ?? {};
      
      // Check required
      if (rules.isRequired && selected.isEmpty) {
        return false;
      }
      
      // Check min/max for multiple selection
      if (rules.group.selectionType == 'multiple') {
        final min = rules.minSelect ?? 0;
        final max = rules.maxSelect;
        
        if (selected.length < min) return false;
        if (max != null && selected.length > max) return false;
      }
    }
    return true;
  }

  void _toggleOption(String groupId, String optionId, String selectionType) {
    setState(() {
      final currentSelections = _selections.putIfAbsent(groupId, () => {});
      
      if (selectionType == 'single') {
        // Radio behavior: clear all and select this one
        if (currentSelections.contains(optionId)) {
          currentSelections.clear(); // Allow deselect
        } else {
          currentSelections.clear();
          currentSelections.add(optionId);
        }
      } else {
        // Checkbox behavior: toggle
        if (currentSelections.contains(optionId)) {
          currentSelections.remove(optionId);
        } else {
          currentSelections.add(optionId);
        }
      }
    });
  }

  List<SelectedModifier> _buildSelectedModifiers() {
    final result = <SelectedModifier>[];
    
    for (final rules in _groupRules) {
      final selectedIds = _selections[rules.group.id] ?? {};
      
      for (final optionId in selectedIds) {
        final option = widget.modifierService.getOption(optionId);
        if (option != null) {
          result.add(SelectedModifier(
            groupId: rules.group.id,
            groupName: rules.group.name,
            optionId: option.id,
            optionName: option.name,
            priceDelta: option.priceDelta,
          ));
        }
      }
    }
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _isValid();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 600,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: isMobile ? AppSpacing.paddingMd : AppSpacing.paddingLg,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: context.textStyles.titleLarge?.bold,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Customize your selection',
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Modifier groups list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: isMobile ? AppSpacing.paddingMd : AppSpacing.paddingLg,
                itemCount: _groupRules.length,
                itemBuilder: (context, index) {
                  final rules = _groupRules[index];
                  final options = widget.modifierService.getOptionsForGroup(rules.group.id);
                  final selectedIds = _selections[rules.group.id] ?? {};
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: rules.isRequired && selectedIds.isEmpty
                            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.3)
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                rules.group.name,
                                style: context.textStyles.titleMedium?.semiBold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: rules.isRequired 
                                    ? Theme.of(context).colorScheme.errorContainer
                                    : Theme.of(context).colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Text(
                                rules.displayRules,
                                style: context.textStyles.labelSmall?.copyWith(
                                  color: rules.isRequired
                                      ? Theme.of(context).colorScheme.onErrorContainer
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        if (rules.group.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            rules.group.description!,
                            style: context.textStyles.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: AppSpacing.md),
                        
                        // Options grid
                        Wrap(
                          spacing: isMobile ? AppSpacing.sm : AppSpacing.md,
                          runSpacing: isMobile ? AppSpacing.sm : AppSpacing.md,
                          children: options.map((option) {
                            final isSelected = selectedIds.contains(option.id);
                            
                            return SizedBox(
                              width: isMobile ? (screenWidth - 80) / 2 : 160,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _toggleOption(
                                    rules.group.id,
                                    option.id,
                                    rules.group.selectionType,
                                  ),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  child: Container(
                                    height: isMobile ? 90 : 100,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primaryContainer
                                          : Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      border: Border.all(
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                        width: isSelected ? 2 : 1.5,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Padding(
                                          padding: AppSpacing.paddingMd,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Option name
                                              Expanded(
                                                child: Text(
                                                  option.name,
                                                  style: (isMobile 
                                                      ? context.textStyles.titleSmall 
                                                      : context.textStyles.titleMedium)?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.2,
                                                    color: isSelected
                                                        ? Theme.of(context).colorScheme.onPrimaryContainer
                                                        : Theme.of(context).colorScheme.onSurface,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              
                                              const SizedBox(height: AppSpacing.xs),
                                              
                                              // Price delta
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  if (option.priceDelta != 0)
                                                    Text(
                                                      '${option.priceDelta > 0 ? '+' : ''}£${option.priceDelta.abs().toStringAsFixed(2)}',
                                                      style: (isMobile 
                                                          ? context.textStyles.titleSmall 
                                                          : context.textStyles.titleMedium)?.copyWith(
                                                        color: isSelected
                                                            ? Theme.of(context).colorScheme.primary
                                                            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    )
                                                  else
                                                    Text(
                                                      'No charge',
                                                      style: context.textStyles.bodySmall?.copyWith(
                                                        color: isSelected
                                                            ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                                                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  
                                                  // Selection indicator
                                                  if (isSelected)
                                                    Container(
                                                      padding: EdgeInsets.all(isMobile ? 4 : 6),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context).colorScheme.primary,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.check,
                                                        size: isMobile ? 14 : 16,
                                                        color: Theme.of(context).colorScheme.onPrimary,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Footer with buttons
            Container(
              padding: isMobile ? AppSpacing.paddingMd : AppSpacing.paddingLg,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: isValid
                          ? () {
                              final selections = _buildSelectedModifiers();
                              Navigator.of(context).pop(selections);
                            }
                          : null,
                      child: Text(
                        widget.initialSelections != null ? 'Update' : 'Add to Order',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
