import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flowtill/models/order_item.dart';
import 'package:flowtill/models/selected_modifier.dart';
import 'package:flowtill/services/modifier_service.dart';
import 'package:flowtill/widgets/till/modifiers_modal.dart';
import 'package:flowtill/theme.dart';

class OrderItemTile extends StatefulWidget {
  final OrderItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final Function(String notes)? onUpdateNotes;
  final Function(List<SelectedModifier> modifiers)? onUpdateModifiers;
  final ModifierService? modifierService;

  const OrderItemTile({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    this.onUpdateNotes,
    this.onUpdateModifiers,
    this.modifierService,
  });

  @override
  State<OrderItemTile> createState() => _OrderItemTileState();
}

class _OrderItemTileState extends State<OrderItemTile> {
  bool _isExpanded = false;

  void _showNotesDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.item.notes);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Item Notes'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter special instructions or notes...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              widget.onUpdateNotes?.call(controller.text);
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showModifiersDialog(BuildContext context) async {
    if (widget.modifierService == null || !widget.modifierService!.isLoaded) return;
    if (!widget.modifierService!.hasModifiers(widget.item.product.id)) return;

    final updatedModifiers = await showDialog<List<SelectedModifier>>(
      context: context,
      builder: (context) => ModifiersModal(
        product: widget.item.product,
        modifierService: widget.modifierService!,
        initialSelections: widget.item.selectedModifiers,
      ),
    );

    if (updatedModifiers != null) {
      widget.onUpdateModifiers?.call(updatedModifiers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    // Compact mode on ALL Android devices (not just small screens)
    final isAndroid = defaultTargetPlatform == TargetPlatform.android && !kIsWeb;
    final compact = isAndroid;
    
    final hasModifiers = widget.item.selectedModifiers.isNotEmpty;
    final hasComponentItems = widget.item.isPackagedDeal && 
                              widget.item.dealComponentItems != null && 
                              widget.item.dealComponentItems!.isNotEmpty;
    
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 1 : (isMobile ? AppSpacing.xs : AppSpacing.sm)),
      padding: compact 
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : (isMobile ? AppSpacing.paddingSm : AppSpacing.paddingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(compact ? AppRadius.sm : AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: (hasModifiers || hasComponentItems) ? () => setState(() => _isExpanded = !_isExpanded) : null,
                  child: Row(
                    children: [
                      if (hasModifiers || hasComponentItems) ...[
                        AnimatedRotation(
                          turns: _isExpanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.arrow_right,
                            size: compact ? 16 : 20,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(width: compact ? 2 : 4),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (widget.item.isPackagedDeal) ...[
                                  Icon(
                                    Icons.card_giftcard,
                                    size: compact ? 14 : 18,
                                    color: Theme.of(context).colorScheme.tertiary,
                                  ),
                                  SizedBox(width: compact ? 3 : 6),
                                ],
                                Expanded(
                                  child: Text(
                                    widget.item.product.name,
                                    style: (compact
                                        ? context.textStyles.bodySmall?.semiBold
                                        : (isMobile 
                                            ? context.textStyles.bodyMedium 
                                            : context.textStyles.titleSmall)?.semiBold)?.copyWith(
                                      color: widget.item.isPackagedDeal 
                                          ? Theme.of(context).colorScheme.tertiary
                                          : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasComponentItems && !_isExpanded) ...[
                                  SizedBox(width: compact ? 2 : 4),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: compact ? 4 : 6,
                                      vertical: compact ? 1 : 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.tertiaryContainer,
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                    ),
                                    child: Text(
                                      '${widget.item.dealComponentItems!.length} items',
                                      style: (compact 
                                          ? context.textStyles.bodySmall?.copyWith(fontSize: 10)
                                          : context.textStyles.bodySmall)?.copyWith(
                                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                                      ),
                                    ),
                                  ),
                                ] else if (hasModifiers && !_isExpanded) ...[
                                  SizedBox(width: compact ? 2 : 4),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: compact ? 4 : 6,
                                      vertical: compact ? 1 : 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                    ),
                                    child: Text(
                                      '${widget.item.selectedModifiers.length}',
                                      style: (compact 
                                          ? context.textStyles.bodySmall?.copyWith(fontSize: 10)
                                          : context.textStyles.bodySmall)?.copyWith(
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (hasComponentItems && _isExpanded) ...[
                              SizedBox(height: compact ? 2 : AppSpacing.xs),
                              ...widget.item.dealComponentItems!.map((componentItem) => Padding(
                                padding: EdgeInsets.only(bottom: compact ? 1 : 2),
                                child: Text(
                                  '  • ${componentItem.quantity}x ${componentItem.product.name}',
                                  style: (compact 
                                      ? context.textStyles.bodySmall?.copyWith(fontSize: 10)
                                      : context.textStyles.bodySmall)?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )),
                            ],
                            if (hasModifiers && _isExpanded) ...[
                              SizedBox(height: compact ? 2 : AppSpacing.xs),
                              ...widget.item.selectedModifiers.map((mod) => Padding(
                                padding: EdgeInsets.only(bottom: compact ? 1 : 2),
                                child: Text(
                                  '  > ${mod.displayText}',
                                  style: (compact 
                                      ? context.textStyles.bodySmall?.copyWith(fontSize: 10)
                                      : context.textStyles.bodySmall)?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )),
                            ],
                            if (widget.item.notes.isNotEmpty) ...[
                              SizedBox(height: compact ? 2 : AppSpacing.xs),
                              Text(
                                'Note: ${widget.item.notes}',
                                style: (compact 
                                    ? context.textStyles.bodySmall?.copyWith(fontSize: 10)
                                    : context.textStyles.bodySmall)?.copyWith(
                                  color: Theme.of(context).colorScheme.tertiary,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: compact ? 4 : 8),
              IconButton(
                icon: Icon(
                  Icons.close, 
                  size: compact ? 16 : 20, 
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (widget.item.isPackagedDeal)
                    // Packaged deals cannot have quantity changed - show static quantity
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 6 : 12,
                        vertical: compact ? 3 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'x${widget.item.quantity}',
                        style: (compact
                            ? context.textStyles.bodySmall?.semiBold
                            : context.textStyles.bodyMedium?.semiBold)?.copyWith(
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        children: [
                          _QuantityButton(
                            icon: Icons.remove,
                            onPressed: widget.onDecrement,
                            compact: compact,
                          ),
                          Container(
                            width: compact ? 24 : (isMobile ? 32 : 40),
                            padding: EdgeInsets.symmetric(vertical: compact ? 2 : (isMobile ? 4 : AppSpacing.xs)),
                            child: Text(
                              '${widget.item.quantity}',
                              style: compact
                                  ? context.textStyles.bodySmall?.semiBold
                                  : (isMobile 
                                      ? context.textStyles.bodySmall 
                                      : context.textStyles.titleSmall)?.semiBold,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          _QuantityButton(
                            icon: Icons.add,
                            onPressed: widget.onIncrement,
                            compact: compact,
                          ),
                        ],
                      ),
                    ),
                  if (widget.onUpdateNotes != null) ...[
                    SizedBox(width: compact ? 4 : 8),
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        size: compact ? 18 : 24,
                        color: widget.item.notes.isNotEmpty 
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => _showNotesDialog(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Add/Edit Notes',
                    ),
                  ],
                  if (widget.onUpdateModifiers != null && 
                      widget.modifierService != null && 
                      widget.modifierService!.isLoaded && 
                      widget.modifierService!.hasModifiers(widget.item.product.id)) ...[
                    SizedBox(width: compact ? 4 : 8),
                    IconButton(
                      icon: Icon(
                        Icons.tune,
                        size: compact ? 18 : 24,
                        color: widget.item.selectedModifiers.isNotEmpty 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => _showModifiersDialog(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit Modifiers',
                    ),
                  ],
                ],
              ),
              Text(
                '£${widget.item.total.toStringAsFixed(2)}',
                style: compact
                    ? context.textStyles.bodyMedium?.bold.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : (isMobile 
                        ? context.textStyles.titleSmall 
                        : context.textStyles.titleMedium)?.bold.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool compact;

  const _QuantityButton({
    required this.icon,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: compact ? const EdgeInsets.all(4) : const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            icon, 
            size: compact ? 14 : 18, 
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
