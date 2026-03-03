import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/providers/order_history_provider.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/providers/staff_provider.dart';
import 'package:flowtill/models/order_item.dart';
import 'package:flowtill/services/order_repository_hybrid.dart';
import 'package:flowtill/services/printer/printer_service.dart';
import 'package:flowtill/services/printer/printer_helper.dart';
import 'package:flowtill/services/till_adjustment_service.dart';
import 'package:flowtill/theme.dart';

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: isMobile ? AppSpacing.paddingMd : AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Consumer2<OrderProvider, OutletProvider>(
        builder: (context, orderProvider, outletProvider, _) {
          final hasItems = orderProvider.currentOrder?.items.isNotEmpty ?? false;
          final outlet = outletProvider.currentOutlet;
          final restaurantMode = outlet?.settings?['restaurantMode'] as bool? ?? false;
          final isTableOrder = orderProvider.currentOrder?.tableNumber != null;
          final canClear = hasItems || isTableOrder;
          final clearLabel = isTableOrder ? 'Close Table' : 'Clear';

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              
              if (isMobile) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'Order Away',
                            icon: Icons.pause_circle_outline,
                            color: Theme.of(context).colorScheme.secondary,
                            onPressed: hasItems ? () => _orderAway(context) : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _ActionButton(
                            label: 'No Sale',
                            icon: Icons.point_of_sale,
                            color: Theme.of(context).colorScheme.tertiary,
                            onPressed: () => _noSale(context),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _ActionButton(
                            label: clearLabel,
                            icon: Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                            onPressed: canClear ? () => _clearSale(context) : null,
                          ),
                        ),
                        if (restaurantMode) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _ActionButton(
                              label: 'Table',
                              icon: Icons.table_restaurant,
                              color: Theme.of(context).colorScheme.tertiary,
                              onPressed: () => _selectTable(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _CheckoutButton(enabled: hasItems),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _CheckoutButton(enabled: hasItems),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ActionButton(
                      label: 'Order Away',
                      icon: Icons.pause_circle_outline,
                      color: Theme.of(context).colorScheme.secondary,
                      onPressed: hasItems ? () => _orderAway(context) : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ActionButton(
                      label: 'No Sale',
                      icon: Icons.point_of_sale,
                      color: Theme.of(context).colorScheme.tertiary,
                      onPressed: () => _noSale(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ActionButton(
                      label: clearLabel,
                      icon: Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                      onPressed: canClear ? () => _clearSale(context) : null,
                    ),
                  ),
                  if (restaurantMode) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ActionButton(
                        label: 'Table',
                        icon: Icons.table_restaurant,
                        color: Theme.of(context).colorScheme.tertiary,
                        onPressed: () => _selectTable(context),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _orderAway(BuildContext context) async {
    final orderProvider = context.read<OrderProvider>();
    final outletProvider = context.read<OutletProvider>();
    final settings = outletProvider.currentSettings;
    final currentOrder = orderProvider.currentOrder;
    
    if (currentOrder == null || currentOrder.items.isEmpty) return;

    // Only prompt if the order contains carvery items; otherwise auto-continue
    final requiresConfirmation = currentOrder.items.any((item) => item.product.isCarvery);
    bool confirmed = true;

    if (requiresConfirmation) {
      confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Print Carvery Tickets?'),
              content: const Text('Send this order to the kitchen/bar printers and park it?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Send'),
                ),
              ],
            ),
          ) ??
          false;
    }

    if (!confirmed) return;

    // Calculate items that still need printing before we mutate provider state
    final pendingItems = settings?.printOrderTicketsOnOrderAway == true
        ? orderProvider.getPendingPrintItems()
        : <OrderItem>[];

    // Step 1: Park/save the order first
    if (currentOrder.tableNumber != null) {
      // If it's a table order, save to Supabase with status='parked'
      final saveSuccess = await orderProvider.parkCurrentOrderToSupabase();
      if (!saveSuccess) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send order away'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // After parking table order, initialize a new quick-service order
      final outlet = outletProvider.currentOutlet;
      final staffProvider = context.read<StaffProvider>();
      if (outlet != null) {
        orderProvider.initializeOrder(
          outlet.id,
          staffProvider.currentStaff?.id,
          autoEnableServiceCharge: outlet.enableServiceCharge,
          outletServiceChargePercent: outlet.serviceChargePercent,
        );
      }
    } else {
      // Regular in-memory park for quick service orders
      final outlet = outletProvider.currentOutlet;
      orderProvider.parkOrder(
        autoEnableServiceCharge: outlet?.enableServiceCharge ?? false,
        outletServiceChargePercent: outlet?.serviceChargePercent ?? 0.0,
      );
    }
    
    // Step 2: Print order tickets if enabled in settings
    if (settings != null && settings.printOrderTicketsOnOrderAway) {
      if (pendingItems.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No new items to send'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      try {
        final printerService = PrinterService.instance;
        final orderToPrint = currentOrder.copyWith(items: pendingItems);
        
        await printerService.printOrderTicketsForOrder(
          order: orderToPrint,
          copies: settings.orderTicketCopies,
          settings: settings,
        );
        orderProvider.markItemsPrinted(orderId: currentOrder.id, items: currentOrder.items);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🖨️ Order sent away - tickets printed'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // Show error but don't block the order away action
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Order sent away but printing failed: ${e.toString()}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      // Tickets disabled
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentOrder.tableNumber != null 
                  ? 'Order sent away - available in Tables view'
                  : 'Order sent away'
            ),
          ),
        );
      }
    }
  }

  void _clearSale(BuildContext context) async {
    final orderProvider = context.read<OrderProvider>();
    final currentOrder = orderProvider.currentOrder;
    
    // Determine if this is a table order
    final isTableOrder = currentOrder?.tableNumber != null;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Sale'),
        content: Text(
          isTableOrder 
              ? 'Are you sure you want to clear this sale and close Table ${currentOrder?.tableNumber}?'
              : 'Are you sure you want to clear this sale?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              // If it's a table order, update status to 'void' in Supabase to free the table
              if (isTableOrder && currentOrder != null) {
                final orderRepository = OrderRepositoryHybrid();
                final historyProvider = context.read<OrderHistoryProvider>();
                
                try {
                  // Update order status to 'void' in Supabase (this frees the table)
                  final success = await orderRepository.voidOrder(currentOrder.id);
                  
                  if (success) {
                    // Clear order history
                    await historyProvider.clearHistoryForOrder(currentOrder.id);
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Table ${currentOrder.tableNumber} cleared and closed'),
                        ),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to clear table order'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to clear table order'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
              
              // Clear order from memory with service charge settings
              final outlet = context.read<OutletProvider>().currentOutlet;
              context.read<OrderProvider>().clearOrder(
                autoEnableServiceCharge: outlet?.enableServiceCharge ?? false,
                outletServiceChargePercent: outlet?.serviceChargePercent ?? 0.0,
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _selectTable(BuildContext context) {
    final tableController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Table Selection'),
        content: TextField(
          controller: tableController,
          decoration: const InputDecoration(
            labelText: 'Table Number',
            hintText: 'Enter table number',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<OrderProvider>().setTableNumber(tableController.text);
              Navigator.pop(dialogContext);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _noSale(BuildContext context) async {
    final outletProvider = context.read<OutletProvider>();
    final staffProvider = context.read<StaffProvider>();
    final outlet = outletProvider.currentOutlet;
    final staff = staffProvider.currentStaff;

    if (outlet == null || staff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot perform No Sale: outlet or staff not selected'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // 1. Create audit log entry
      final adjustmentService = TillAdjustmentService();
      await adjustmentService.createAdjustment(
        outletId: outlet.id,
        staffId: staff.id,
        amount: 0.0,
        type: 'drawer_open',
        reason: 'No Sale',
        notes: 'Cash drawer opened without transaction',
      );

      // 2. Open cash drawer
      await PrinterService.instance.openCashDrawer();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💰 No Sale - Cash drawer opened and logged'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ No Sale failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No Sale failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _CheckoutButton extends StatelessWidget {
  final bool enabled;

  const _CheckoutButton({required this.enabled});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return SizedBox(
      height: isMobile ? 48 : 56,
      child: ElevatedButton(
        onPressed: enabled ? () => _handleCheckout(context) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          disabledBackgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          disabledForegroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag, 
              color: Theme.of(context).colorScheme.onPrimary,
              size: isMobile ? 20 : 24,
            ),
            SizedBox(width: isMobile ? 6 : AppSpacing.sm),
            Text(
              'Checkout',
              style: (isMobile 
                  ? context.textStyles.titleMedium 
                  : context.textStyles.titleLarge)?.bold.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCheckout(BuildContext context) {
    context.go('/payment');
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return SizedBox(
      height: isMobile ? 48 : 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: isMobile 
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: isMobile ? 16 : 20),
            SizedBox(width: isMobile ? 4 : AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: (isMobile 
                    ? context.textStyles.titleSmall 
                    : context.textStyles.titleMedium)?.semiBold.copyWith(color: color),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
