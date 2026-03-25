import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/providers/order_history_provider.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/models/order.dart';
import 'package:flowtill/models/order_item.dart';
import 'package:flowtill/services/modifier_service.dart';
import 'package:flowtill/services/printer/printer_service.dart';
import 'package:flowtill/widgets/till/order_item_tile.dart';
import 'package:flowtill/widgets/till/order_summary.dart';
import 'package:flowtill/widgets/till/order_history_modal.dart';
import 'package:flowtill/widgets/till/resend_order_modal.dart';
import 'package:flowtill/theme.dart';

class OrderPanel extends StatefulWidget {
  final ModifierService modifierService;
  final double? mobileExpandedListHeight;
  final ValueChanged<bool>? onExpandedChanged;

  const OrderPanel({
    super.key,
    required this.modifierService,
    this.mobileExpandedListHeight,
    this.onExpandedChanged,
  });

  @override
  State<OrderPanel> createState() => _OrderPanelState();
}

class _OrderPanelState extends State<OrderPanel> with TickerProviderStateMixin {
  bool _isExpanded = false; // Controls mobile collapsed/expanded state

  void _toggleExpanded({bool? expanded}) {
    final nextValue = expanded ?? !_isExpanded;
    if (nextValue == _isExpanded) return;
    setState(() => _isExpanded = nextValue);
    widget.onExpandedChanged?.call(_isExpanded);
  }

  static void _showAddMiscItemDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    bool includeVat = true;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Miscellaneous Item'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'e.g., Delivery Charge, Discount, Adjustment',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an item name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (£)',
                        hintText: 'Positive or negative (e.g., 5.00 or -2.50)',
                        border: OutlineInputBorder(),
                        prefixText: '£',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an amount';
                        }
                        final price = double.tryParse(value);
                        if (price == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CheckboxListTile(
                      title: const Text('Include VAT (20%)'),
                      value: includeVat,
                      onChanged: (value) => setState(() => includeVat = value ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final name = nameController.text.trim();
                    final price = double.parse(priceController.text);
                    
                    // Add miscellaneous item to order
                    context.read<OrderProvider>().addMiscellaneousItem(name, price, includeVat: includeVat);
                    
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _showResendOrderDialog(BuildContext context, Order order) async {
    final settings = context.read<OutletProvider>().currentSettings;
    final copies = settings?.orderTicketCopies ?? 1;

    try {
      final selection = await showDialog<List<OrderItem>>(
        context: context,
        builder: (dialogContext) => ResendOrderModal(order: order),
      );

      if (selection == null || selection.isEmpty) {
        return;
      }

      final outletProvider = context.read<OutletProvider>();
      await PrinterService.instance.printOrderTicketsForOrder(
        order: order.copyWith(items: selection),
        copies: copies,
        settings: outletProvider.currentSettings,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🖨️ Selected items resent'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend items: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<void> _printBill(BuildContext context, dynamic order) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Printing bill...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Print the bill using PrinterService
      await PrinterService.instance.printCustomerReceipt(order);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Bill printed successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error printing bill: $e');
      
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to print: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    // Compact mode on ALL Android devices (not just small screens)
    final isAndroid = defaultTargetPlatform == TargetPlatform.android && !kIsWeb;
    final compact = isAndroid;
    
    if (isMobile) {
      return _buildMobilePanel(context, compact);
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          _buildHeader(context, isMobile, compact),
          Expanded(child: _buildOrderList(context, compact)),
          const OrderSummary(isCollapsed: false),
        ],
      ),
    );
  }

  Widget _buildMobilePanel(BuildContext context, bool compact) {
    final expandedHeight = widget.mobileExpandedListHeight ?? MediaQuery.of(context).size.height * 0.85;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.surface,
        child: SizedBox(
          height: _isExpanded ? expandedHeight : null,
          child: Column(
            mainAxisSize: _isExpanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _toggleExpanded(),
                child: _buildHeader(context, true, compact, isExpanded: _isExpanded),
              ),
              if (_isExpanded) ...[
                Expanded(child: _buildOrderList(context, compact)),
                const OrderSummary(isCollapsed: false),
              ] else ...[
                InkWell(
                  onTap: () => _toggleExpanded(expanded: true),
                  child: const OrderSummary(isCollapsed: true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile, bool compact, {bool showCloseButton = false, bool isExpanded = false}) {
    final miscButton = Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        return OutlinedButton.icon(
          onPressed: () => _showAddMiscItemDialog(context),
          icon: Icon(Icons.add, size: compact ? 16 : 20),
          label: const Text('Misc'),
          style: OutlinedButton.styleFrom(
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                : const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
          ),
        );
      },
    );

    final resendButton = Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        final order = orderProvider.currentOrder;
        final showResend = order != null && order.tableNumber != null && order.completedAt == null;
        if (!showResend) {
          return const SizedBox.shrink();
        }

        final hasItems = order!.items.isNotEmpty;

        return OutlinedButton.icon(
          onPressed: hasItems ? () => _showResendOrderDialog(context, order) : null,
          icon: Icon(Icons.repeat, size: compact ? 16 : 20),
          label: const Text('Resend'),
          style: OutlinedButton.styleFrom(
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                : const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
          ),
        );
      },
    );

    final printButton = Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        final order = orderProvider.currentOrder;
        final hasItems = order != null && order.items.isNotEmpty;
        
        return OutlinedButton.icon(
          onPressed: hasItems ? () => _printBill(context, order) : null,
          icon: Icon(Icons.print, size: compact ? 16 : 20),
          label: const Text('Print'),
          style: OutlinedButton.styleFrom(
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                : const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
          ),
        );
      },
    );

    final itemCountChip = Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        final itemCount = orderProvider.currentOrder?.itemCount ?? 0;
        return Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
              : const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(compact ? AppRadius.md : AppRadius.lg),
          ),
          child: Text(
            '$itemCount items',
            style: (compact 
                ? context.textStyles.labelSmall 
                : context.textStyles.labelMedium)?.semiBold.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        );
      },
    );

    final actionsWrap = Wrap(
      spacing: compact ? 6 : AppSpacing.sm,
      runSpacing: compact ? 4 : AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: isMobile ? WrapAlignment.start : WrapAlignment.end,
      children: [
        miscButton,
        resendButton,
        printButton,
        itemCountChip,
      ],
    );

    final titleRow = Row(
      children: [
        Expanded(
          child: Text(
            'Current Order',
            style: compact
                ? context.textStyles.titleMedium?.semiBold
                : (isMobile 
                    ? context.textStyles.titleLarge 
                    : context.textStyles.headlineSmall)?.semiBold,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isMobile && !showCloseButton) ...[
          const SizedBox(width: 8),
          Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
        if (showCloseButton) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ],
    );

    final headerContent = isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleRow,
              SizedBox(height: compact ? 6 : AppSpacing.sm),
              actionsWrap,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleRow),
              actionsWrap,
            ],
          );

    return Container(
      padding: compact 
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
          : const EdgeInsets.all(AppSpacing.md),
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
          headerContent,
          // View History button for table orders
          Consumer<OrderProvider>(
            builder: (context, orderProvider, _) {
              final order = orderProvider.currentOrder;
              
              // Only show for table orders that are open or parked
              if (order == null || 
                  order.tableNumber == null ||
                  order.completedAt != null) {
                return const SizedBox.shrink();
              }
              
              return Padding(
                padding: EdgeInsets.only(top: compact ? 4 : AppSpacing.sm),
                child: TextButton.icon(
                  onPressed: () async {
                    // Load history for current order
                    final historyProvider = context.read<OrderHistoryProvider>();
                    await historyProvider.loadHistoryForOrder(order.id);
                    
                    // Show modal
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (context) => const OrderHistoryModal(),
                      );
                    }
                  },
                  icon: Icon(Icons.history, size: compact ? 14 : 18),
                  label: const Text('View History'),
                  style: TextButton.styleFrom(
                    padding: compact
                        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
                        : const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                  ),
                ),
              );
            },
          ),
          // Table info if order is for a table
          Consumer<OrderProvider>(
            builder: (context, orderProvider, _) {
              final tableNumber = orderProvider.currentOrder?.tableNumber;
              final tableId = orderProvider.currentOrder?.tableId;
              
              // Log table identity when rendering order header
              if (tableNumber != null && tableId != null) {
                debugPrint('[ORDER_HEADER] Rendering table order header:');
                debugPrint('[ORDER_HEADER]    table_id=$tableId');
                debugPrint('[ORDER_HEADER]    table_number=$tableNumber');
              }
              
              if (tableNumber == null) return const SizedBox.shrink();
              
              return Container(
                margin: EdgeInsets.only(top: compact ? 4 : AppSpacing.sm),
                padding: compact
                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                    : const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(compact ? AppRadius.sm : AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.table_restaurant,
                      size: compact ? 16 : 20,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    SizedBox(width: compact ? 4 : AppSpacing.sm),
                    Text(
                      'Table $tableNumber',
                      style: (compact 
                          ? context.textStyles.bodyMedium 
                          : context.textStyles.titleMedium)?.semiBold.copyWith(
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(BuildContext context, bool compact) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        final order = orderProvider.currentOrder;
        
        if (order == null || order.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: compact ? 48 : 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                Text(
                  'No items in order',
                  style: (compact 
                      ? context.textStyles.titleSmall 
                      : context.textStyles.titleMedium)?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: compact ? 4 : AppSpacing.xs),
                Text(
                  'Tap products to add them',
                  style: (compact 
                      ? context.textStyles.bodySmall 
                      : context.textStyles.bodyMedium)?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: compact 
              ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
              : const EdgeInsets.all(AppSpacing.md),
          itemCount: order.items.length,
          itemBuilder: (context, index) {
            final item = order.items[index];
            return OrderItemTile(
              item: item,
              onIncrement: () => orderProvider.incrementQuantity(item.id),
              onDecrement: () => orderProvider.decrementQuantity(item.id),
              onRemove: () => orderProvider.removeItem(item.id),
              onUpdateNotes: (notes) => orderProvider.updateItemNotes(item.id, notes),
              onUpdateModifiers: (modifiers) => orderProvider.updateItemModifiers(item.id, modifiers),
              modifierService: widget.modifierService,
            );
          },
        );
      },
    );
  }
}
