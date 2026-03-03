import 'package:flutter/material.dart';
import 'package:flowtill/models/order.dart';
import 'package:flowtill/models/order_item.dart';
import 'package:flowtill/theme.dart';

class ResendOrderModal extends StatefulWidget {
  final Order order;

  const ResendOrderModal({super.key, required this.order});

  @override
  State<ResendOrderModal> createState() => _ResendOrderModalState();
}

class _ResendOrderModalState extends State<ResendOrderModal> {
  late final Map<String, int> _selectedQuantities;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedQuantities = {
      for (final item in widget.order.items) item.id: 0,
    };
  }

  void _toggleItem(String id, bool selected) {
    setState(() {
      _selectedQuantities[id] = selected ? (_selectedQuantities[id] == 0 ? 1 : _selectedQuantities[id]!) : 0;
      _error = null;
    });
  }

  void _increment(String id, int max) {
    setState(() {
      final current = _selectedQuantities[id] ?? 0;
      if (current < max) {
        _selectedQuantities[id] = current + 1;
      }
    });
  }

  void _decrement(String id) {
    setState(() {
      final current = _selectedQuantities[id] ?? 0;
      if (current > 0) {
        _selectedQuantities[id] = current - 1;
      }
    });
  }

  List<OrderItem> _buildSelection() {
    return widget.order.items
        .where((item) => (_selectedQuantities[item.id] ?? 0) > 0)
        .map((item) => item.copyWith(quantity: _selectedQuantities[item.id]))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Resend Order'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select the items to resend to the printer.',
              style: context.textStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 360,
              child: ListView.separated(
                itemCount: widget.order.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = widget.order.items[index];
                  final selectedQty = _selectedQuantities[item.id] ?? 0;
                  final isSelected = selectedQty > 0;
                  return _ResendOrderRow(
                    item: item,
                    selectedQuantity: selectedQty,
                    isSelected: isSelected,
                    onToggle: (value) => _toggleItem(item.id, value),
                    onIncrement: () => _increment(item.id, item.quantity),
                    onDecrement: () => _decrement(item.id),
                  );
                },
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: context.textStyles.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final selection = _buildSelection();
            if (selection.isEmpty) {
              setState(() => _error = 'Select at least one item to resend.');
              return;
            }
            Navigator.of(context).pop(selection);
          },
          child: const Text('Resend'),
        ),
      ],
    );
  }
}

class _ResendOrderRow extends StatelessWidget {
  final OrderItem item;
  final int selectedQuantity;
  final bool isSelected;
  final ValueChanged<bool> onToggle;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _ResendOrderRow({
    required this.item,
    required this.selectedQuantity,
    required this.isSelected,
    required this.onToggle,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Checkbox(value: isSelected, onChanged: (value) => onToggle(value ?? false)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: context.textStyles.titleMedium?.semiBold,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((item.notes).isNotEmpty)
                  Text(
                    item.notes,
                    style: context.textStyles.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _QuantityControl(
            quantity: selectedQuantity,
            max: item.quantity,
            onIncrement: onIncrement,
            onDecrement: onDecrement,
            enabled: isSelected,
          ),
        ],
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  final int quantity;
  final int max;
  final bool enabled;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QuantityControl({
    required this.quantity,
    required this.max,
    required this.enabled,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.remove_circle_outline, color: color),
          onPressed: enabled && quantity > 0 ? onDecrement : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('$quantity / $max', style: context.textStyles.bodyMedium),
        ),
        IconButton(
          icon: Icon(Icons.add_circle_outline, color: color),
          onPressed: enabled && quantity < max ? onIncrement : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}