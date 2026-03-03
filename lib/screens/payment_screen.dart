import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/models/order.dart';
import 'package:flowtill/models/staff.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/providers/order_history_provider.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/providers/staff_provider.dart';
import 'package:flowtill/providers/login_provider.dart';
import 'package:flowtill/services/printer/printer_service.dart';
import 'package:flowtill/models/split_bill.dart';
import 'package:flowtill/services/loyalty_service.dart';
import 'package:flowtill/services/loyalty_coordinator.dart';
import 'package:flowtill/models/loyalty_models.dart';
import 'package:flowtill/theme.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final order = orderProvider.currentOrder;
    final staff = context.watch<StaffProvider>().currentStaff;
    final splitBill = orderProvider.activeSplitBill;

    debugPrint('🔍 PaymentScreen: Building...');
    debugPrint('   Order: ${order?.id ?? "null"}');
    debugPrint('   Staff: ${staff?.fullName ?? "null"}');
    debugPrint('   Split Bill: ${splitBill != null ? "Active (${splitBill.splitType})" : "None"}');

    if (order == null || (order.items.isEmpty && splitBill == null)) {
      debugPrint('⚠️ PaymentScreen: No order or empty items, redirecting to till');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      body: SafeArea(
        child: Column(
          children: [
            _PaymentHeader(order: order, staff: staff, splitBill: splitBill),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;

                  if (isMobile) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          _OrderSummaryPanel(order: order, splitBill: splitBill, isScrollable: true),
                          const SizedBox(height: AppSpacing.md),
                          _PaymentMethodsPanel(order: order, splitBill: splitBill, isScrollable: true),
                        ],
                      ),
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: _OrderSummaryPanel(order: order, splitBill: splitBill, isScrollable: false),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 6,
                        child: _PaymentMethodsPanel(order: order, splitBill: splitBill, isScrollable: false),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentHeader extends StatelessWidget {
  final Order order;
  final Staff? staff;
  final SplitBill? splitBill;

  const _PaymentHeader({required this.order, this.staff, this.splitBill});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: isMobile ? AppSpacing.paddingMd : AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () => context.go('/'),
            iconSize: isMobile ? 20 : 24,
          ),
          SizedBox(width: isMobile ? AppSpacing.sm : AppSpacing.md),
          if (staff != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person, size: 18, color: colorScheme.onPrimaryContainer),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    staff!.fullName,
                    style: theme.textTheme.bodyMedium?.semiBold.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                splitBill != null ? 'Split Bill Payment' : 'Take Payment',
                style: (isMobile 
                    ? theme.textTheme.titleLarge 
                    : theme.textTheme.headlineSmall)?.bold.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                splitBill?.splitType == 'even'
                    ? 'Person ${splitBill?.splitIndex ?? 1} of ${splitBill?.totalSplits ?? 1}'
                    : 'Order ${order.id.substring(0, 8)}',
                style: (isMobile 
                    ? theme.textTheme.bodySmall 
                    : theme.textTheme.bodyMedium)?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryPanel extends StatelessWidget {
  final Order order;
  final SplitBill? splitBill;
  final bool isScrollable;

  const _OrderSummaryPanel({required this.order, this.splitBill, required this.isScrollable});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Use split bill amounts if active, otherwise use order amounts
    final displayItems = splitBill?.items ?? order.items;
    final displaySubtotal = splitBill?.subtotal ?? order.subtotal;
    final displayTax = splitBill?.taxAmount ?? order.taxAmount;
    final displayDiscount = splitBill?.discountShare ?? order.discountAmount;
    final displayPromo = splitBill?.promotionDiscountShare ?? order.promotionDiscount;
    final displayServiceCharge = splitBill?.serviceChargeShare ?? order.serviceCharge;
    final displayTotal = splitBill?.totalDue ?? order.totalDue;

    return Container(
      margin: isMobile ? AppSpacing.paddingMd : AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: isMobile ? AppSpacing.paddingMd : AppSpacing.paddingLg,
            child: Text(
              splitBill != null ? 'Split Bill Summary' : 'Order Summary',
              style: (isMobile 
                  ? theme.textTheme.titleMedium 
                  : theme.textTheme.titleLarge)?.bold.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const Divider(height: 1),
          if (isScrollable)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: isMobile ? AppSpacing.paddingSm : AppSpacing.paddingMd,
              itemCount: displayItems.length,
              itemBuilder: (context, index) {
                final item = displayItems[index];
                return Padding(
                  padding: AppSpacing.verticalXs,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${item.quantity}x',
                          style: theme.textTheme.labelLarge?.bold.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              style: theme.textTheme.bodyLarge?.medium.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'VAT ${(item.taxRate * 100).toStringAsFixed(0)}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '£${item.total.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyLarge?.semiBold.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          else
            Expanded(
              child: ListView.builder(
                padding: isMobile ? AppSpacing.paddingSm : AppSpacing.paddingMd,
                itemCount: displayItems.length,
                itemBuilder: (context, index) {
                  final item = displayItems[index];
                  return Padding(
                    padding: AppSpacing.verticalXs,
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${item.quantity}x',
                            style: theme.textTheme.labelLarge?.bold.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: theme.textTheme.bodyLarge?.medium.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'VAT ${(item.taxRate * 100).toStringAsFixed(0)}%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '£${item.total.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyLarge?.semiBold.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: isMobile ? AppSpacing.paddingMd : AppSpacing.paddingLg,
            child: Column(
              children: [
                _SummaryRow(
                  label: 'Subtotal',
                  value: '£${displaySubtotal.toStringAsFixed(2)}',
                  theme: theme,
                ),
                const SizedBox(height: AppSpacing.sm),
                _SummaryRow(
                  label: 'Tax',
                  value: '£${displayTax.toStringAsFixed(2)}',
                  theme: theme,
                ),
                if (displayPromo > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _SummaryRow(
                    label: 'Promotions',
                    value: '-£${displayPromo.toStringAsFixed(2)}',
                    theme: theme,
                    valueColor: colorScheme.primary,
                  ),
                ],
                if (displayDiscount > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _SummaryRow(
                    label: order.loyaltyCustomerName != null
                        ? 'Loyalty Card (${order.loyaltyCustomerName})'
                        : 'Loyalty Card',
                    value: '-£${displayDiscount.toStringAsFixed(2)}',
                    theme: theme,
                    valueColor: colorScheme.error,
                  ),
                  if (order.loyaltyRewardName != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.md),
                      child: Text(
                        order.loyaltyRewardName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
                if (displayServiceCharge > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _SummaryRow(
                    label: 'Service Charge',
                    value: '£${displayServiceCharge.toStringAsFixed(2)}',
                    theme: theme,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Due',
                      style: theme.textTheme.headlineSmall?.bold.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '£${displayTotal.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineSmall?.bold.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.theme,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.semiBold.copyWith(
            color: valueColor ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodsPanel extends StatelessWidget {
  final Order order;
  final SplitBill? splitBill;
  final bool isScrollable;

  const _PaymentMethodsPanel({required this.order, this.splitBill, required this.isScrollable});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Container(
      margin: isMobile ? AppSpacing.paddingMd : AppSpacing.paddingLg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = isMobile ? 2 : 3;

          return GridView.count(
            shrinkWrap: isScrollable,
            physics: isScrollable ? const NeverScrollableScrollPhysics() : null,
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: isMobile ? AppSpacing.sm : AppSpacing.md,
            crossAxisSpacing: isMobile ? AppSpacing.sm : AppSpacing.md,
            childAspectRatio: isMobile ? 1.0 : 1.2,
            children: [
              _PaymentMethodTile(
                icon: Icons.credit_card,
                label: 'Card Payment',
                color: Theme.of(context).colorScheme.primary,
                onTap: () => _showCardPayment(context),
              ),
              _PaymentMethodTile(
                icon: Icons.payments_outlined,
                label: 'Cash Payment',
                color: Theme.of(context).colorScheme.primary,
                onTap: () => _showCashPayment(context),
              ),
              Consumer<OrderProvider>(
                builder: (context, orderProvider, _) {
                  final discountAmount = orderProvider.currentOrder?.discountAmount ?? 0.0;
                  final hasDiscount = discountAmount > 0;
                  return _PaymentMethodTile(
                    icon: hasDiscount ? Icons.local_offer : Icons.card_giftcard,
                    label: hasDiscount 
                        ? 'Loyalty Card (£${discountAmount.toStringAsFixed(2)})' 
                        : 'Loyalty Card',
                    color: hasDiscount 
                        ? Theme.of(context).colorScheme.error 
                        : Theme.of(context).colorScheme.secondary,
                    onTap: () => _showDiscountModal(context),
                  );
                },
              ),
              _PaymentMethodTile(
                icon: Icons.confirmation_number_outlined,
                label: 'Voucher Code',
                color: Theme.of(context).colorScheme.secondary,
                onTap: () => _showVoucherModal(context),
              ),
              _PaymentMethodTile(
                icon: Icons.card_membership,
                label: 'Discount Card',
                color: Theme.of(context).colorScheme.secondary,
                onTap: () => _showDiscountCardModal(context),
              ),
              if (splitBill == null) // Only show split bill option if not already in split mode
                _PaymentMethodTile(
                  icon: Icons.call_split,
                  label: 'Split Bill',
                  color: Theme.of(context).colorScheme.tertiary,
                  onTap: () => _showSplitBill(context),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showCardPayment(BuildContext context) {
    debugPrint('💳 Card Payment: Opening modal');
    debugPrint('   Order: ${order.id}');
    debugPrint('   Total: £${order.totalDue.toStringAsFixed(2)}');

    final orderProvider = context.read<OrderProvider>();
    final historyProvider = context.read<OrderHistoryProvider>();
    final staffProvider = context.read<StaffProvider>();
    final loginProvider = context.read<LoginProvider>();

    final rootContext = Navigator.of(context, rootNavigator: true).context;

    debugPrint('   OrderProvider: ${orderProvider.currentOrder?.id ?? "null"}');
    debugPrint('   StaffProvider: ${staffProvider.currentStaff?.fullName ?? "null"}');
    debugPrint('   Calling showDialog on rootNavigator...');

    try {
      showDialog(
        context: rootContext,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogContext) {
          debugPrint('   Dialog builder called (CARD)');
          return _CardPaymentModal(
            order: order,
            orderProvider: orderProvider,
            historyProvider: historyProvider,
            staffProvider: staffProvider,
            loginProvider: loginProvider,
          );
        },
      ).then((_) {
        debugPrint('   Card dialog closed');
      });
      debugPrint('   showDialog returned (CARD)');
    } catch (e, stackTrace) {
      debugPrint('❌ Error showing card payment modal: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _showCashPayment(BuildContext context) {
    debugPrint('💵 Cash Payment: Opening modal');
    debugPrint('   Order: ${order.id}');
    debugPrint('   Total: £${order.totalDue.toStringAsFixed(2)}');

    final orderProvider = context.read<OrderProvider>();
    final historyProvider = context.read<OrderHistoryProvider>();
    final staffProvider = context.read<StaffProvider>();
    final loginProvider = context.read<LoginProvider>();

    final rootContext = Navigator.of(context, rootNavigator: true).context;

    debugPrint('   OrderProvider: ${orderProvider.currentOrder?.id ?? "null"}');
    debugPrint('   StaffProvider: ${staffProvider.currentStaff?.fullName ?? "null"}');
    debugPrint('   Calling showDialog on rootNavigator...');

    try {
      showDialog(
        context: rootContext,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogContext) {
          debugPrint('   Dialog builder called (CASH)');
          return _CashPaymentModal(
            order: order,
            orderProvider: orderProvider,
            historyProvider: historyProvider,
            staffProvider: staffProvider,
            loginProvider: loginProvider,
          );
        },
      ).then((_) {
        debugPrint('   Cash dialog closed');
      });
      debugPrint('   showDialog returned (CASH)');
    } catch (e, stackTrace) {
      debugPrint('❌ Error showing cash payment modal: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _showDiscountModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _DiscountModal(order: order),
    );
  }

  void _showVoucherModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => const _VoucherModal(),
    );
  }

  void _showDiscountCardModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _DiscountCardModal(order: order, splitBill: splitBill),
    );
  }

  void _showSplitBill(BuildContext context) {
    context.go('/split-bill');
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: 2,
      child: InkWell(
        onTap: () {
          debugPrint('🖱️ Payment Method Tile Tapped: $label');
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: isMobile ? AppSpacing.paddingMd : AppSpacing.paddingLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: isMobile ? 36 : 48, color: color),
              SizedBox(height: isMobile ? AppSpacing.sm : AppSpacing.md),
              Text(
                label,
                textAlign: TextAlign.center,
                style: (isMobile 
                    ? theme.textTheme.titleSmall 
                    : theme.textTheme.titleMedium)?.semiBold.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardPaymentModal extends StatefulWidget {
  final Order order;
  final OrderProvider orderProvider;
  final OrderHistoryProvider historyProvider;
  final StaffProvider staffProvider;
  final LoginProvider loginProvider;

  const _CardPaymentModal({
    required this.order,
    required this.orderProvider,
    required this.historyProvider,
    required this.staffProvider,
    required this.loginProvider,
  });

  @override
  State<_CardPaymentModal> createState() => _CardPaymentModalState();
}

class _CardPaymentModalState extends State<_CardPaymentModal> {
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🔧 Card Payment Modal: Initialized');
    _simulateCardProcessing();
  }

  Future<void> _simulateCardProcessing() async {
    debugPrint('⏳ Card Payment: Starting terminal simulation...');
    setState(() => _processing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      debugPrint('✅ Card Payment: Terminal ready');
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.credit_card, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          const Text('Card Payment'),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_processing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Processing card payment...',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Please wait for customer to complete payment on terminal',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Icon(
                Icons.check_circle,
                size: 64,
                color: colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Card terminal ready',
                style: theme.textTheme.titleLarge?.bold,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Amount: £${widget.order.totalDue.toStringAsFixed(2)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _processing
              ? null
              : () {
                  debugPrint('❌ Card Payment: Cancel button pressed');
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _processing
              ? null
              : () async {
                  debugPrint(
                    '✅ Card Payment: Complete Payment button pressed (inside button)',
                  );
                  await _completeCardPayment(context);
                },
          child: _processing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Complete Payment'),
        ),
      ],
    );
  }

  Future<void> _completeCardPayment(BuildContext context) async {
    debugPrint('✅ Card Payment: Complete button pressed');
    debugPrint('   Order ID: ${widget.order.id}');
    debugPrint('   Amount: £${widget.order.totalDue.toStringAsFixed(2)}');
    debugPrint(
      '   Staff: ${widget.staffProvider.currentStaff?.fullName ?? "null"}',
    );

    // Show loading state
    if (!mounted) return;
    setState(() => _processing = true);

    try {
      // 1. Complete order in memory
      debugPrint('   Completing order...');
      widget.orderProvider.completeOrder(
        paymentMethod: 'card',
        amountPaid: widget.order.totalDue,
      );
      debugPrint('   Order completed successfully');

      // 2. Save to Supabase
      debugPrint('   Saving to Supabase...');
      final saved = await widget.orderProvider.saveCompletedOrderToSupabase();
      
      if (!saved) {
        debugPrint('⚠️ Failed to save to Supabase, but continuing...');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Warning: Order may not be saved to database'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        debugPrint('✅ Order saved to Supabase successfully');
      }

      // 3. Clear order history (for table orders)
      if (widget.order.tableNumber != null) {
        debugPrint('   Clearing order history...');
        await widget.historyProvider.clearHistoryForOrder(widget.order.id);
      }

      // 4. Loyalty sync (award points / redemption)
      final updatedOrder = widget.orderProvider.currentOrder;
      debugPrint('🔍 [CARD] Checking loyalty sync...');
      debugPrint('   updatedOrder exists: ${updatedOrder != null}');
      debugPrint('   loyaltyCustomerId: ${updatedOrder?.loyaltyCustomerId}');
      debugPrint('   loyaltyRestaurantId: ${updatedOrder?.loyaltyRestaurantId}');
      debugPrint('   totalDue: ${updatedOrder?.totalDue}');
      debugPrint('   loyaltyRewardId: ${updatedOrder?.loyaltyRewardId}');
      debugPrint('   loyaltyRewardType: ${updatedOrder?.loyaltyRewardType}');
      
      if (updatedOrder != null && updatedOrder.loyaltyCustomerId != null) {
        try {
          debugPrint('   Processing loyalty rewards...');
          
          // Get loyalty settings from outlet
          final outletProvider = context.read<OutletProvider>();
          final loyaltyEnabled = outletProvider.currentSettings?.loyaltyEnabled ?? true;
          final pointsPerPound = outletProvider.currentSettings?.loyaltyPointsPerPound ?? 1.0;
          final doublePointsEnabled = outletProvider.currentSettings?.loyaltyDoublePointsEnabled ?? false;
          
          if (!loyaltyEnabled) {
            debugPrint('⚠️ Loyalty disabled in settings, skipping');
          } else {
            final awarded = await LoyaltyCoordinator.instance.handlePaymentCompletion(
              updatedOrder,
              pointsPerPound: pointsPerPound,
              doublePointsEnabled: doublePointsEnabled,
            );
            if (awarded) {
              final effectiveRate = doublePointsEnabled ? pointsPerPound * 2 : pointsPerPound;
              final pointsAwarded = (updatedOrder.totalDue * effectiveRate).floor();
              debugPrint('✅ Loyalty points awarded: $pointsAwarded points');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Loyalty points added: $pointsAwarded points${doublePointsEnabled ? " (2x!)" : ""}'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } else {
              debugPrint('⚠️ No loyalty points awarded (might be duplicate or no customer attached)');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Loyalty points failed (non-blocking): $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ Points failed to apply: $e'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          // Don't block payment completion
        }
      } else {
        debugPrint('⚠️ No loyalty customer attached, skipping points award');
      }

      // 5. Auto-print receipt if enabled (don't block UI)
      _autoPrintReceiptIfEnabled(context);

      // 6. Navigate to receipt
      debugPrint('   Closing modal...');
      if (context.mounted) {
        Navigator.of(context).pop();
        debugPrint('   Navigating to receipt screen...');
        context.go('/receipt');
        debugPrint('   Navigation complete');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error completing card payment: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _processing = false);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _autoPrintReceiptIfEnabled(BuildContext context) async {
    final printerService = PrinterService.instance;
    final outlet = context.read<OutletProvider>().currentOutlet;
    
    if (!printerService.autoPrintReceiptEnabled) {
      debugPrint('🖨️ Auto-print: Disabled');
      return;
    }
    
    final defaultPrinter = printerService.getDefaultReceiptPrinter();
    if (defaultPrinter == null) {
      debugPrint('🖨️ Auto-print: No receipt printer configured');
      return;
    }

    // Print in background, don't block UI
    Future(() async {
      try {
        debugPrint('🖨️ Auto-print: Printing receipt to ${defaultPrinter.name}...');
        await printerService.printCustomerReceipt(widget.order, outletName: outlet?.name, outlet: outlet);
        debugPrint('✅ Auto-print: Receipt printed successfully');
      } catch (e) {
        debugPrint('❌ Auto-print failed: $e');
        // Don't show error to user for auto-print, just log it
      }
    });
  }
}

class _CashPaymentModal extends StatefulWidget {
  final Order order;
  final OrderProvider orderProvider;
  final OrderHistoryProvider historyProvider;
  final StaffProvider staffProvider;
  final LoginProvider loginProvider;

  const _CashPaymentModal({
    required this.order,
    required this.orderProvider,
    required this.historyProvider,
    required this.staffProvider,
    required this.loginProvider,
  });

  @override
  State<_CashPaymentModal> createState() => _CashPaymentModalState();
}

class _CashPaymentModalState extends State<_CashPaymentModal> {
  double _tenderedAmount = 0.0;
  bool _processing = false;
  final TextEditingController _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  double get _changeDue =>
      (_tenderedAmount - widget.order.totalDue).clamp(0.0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.payments_outlined, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          const Text('Cash Payment'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () {
                debugPrint('💰 Exact change selected: £${widget.order.totalDue.toStringAsFixed(2)}');
                setState(() => _tenderedAmount = widget.order.totalDue);
                _completeCashPayment(context);
              },
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Total Due',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.touch_app,
                          size: 16,
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                    Text(
                      '£${widget.order.totalDue.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineMedium?.bold.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      'Tap for exact change',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Select cash amount tendered:',
              style: theme.textTheme.titleMedium?.semiBold,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _CashButton(
                  amount: 5,
                  onTap: () => setState(() => _tenderedAmount = 5),
                ),
                _CashButton(
                  amount: 10,
                  onTap: () => setState(() => _tenderedAmount = 10),
                ),
                _CashButton(
                  amount: 20,
                  onTap: () => setState(() => _tenderedAmount = 20),
                ),
                _CashButton(
                  amount: 50,
                  onTap: () => setState(() => _tenderedAmount = 50),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _customController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Custom Amount',
                prefixText: '£',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _tenderedAmount = double.tryParse(value) ?? 0.0;
                });
              },
            ),
            if (_tenderedAmount >= widget.order.totalDue) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  children: [
                    Text(
                      'Change Due',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                    Text(
                      '£${_changeDue.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineMedium?.bold.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _processing
              ? null
              : () {
                  debugPrint('❌ Cash Payment: Cancel button pressed');
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_tenderedAmount >= widget.order.totalDue) && !_processing
              ? () async {
                  debugPrint(
                    '✅ Cash Payment: Complete Payment button pressed (inside button)',
                  );
                  await _completeCashPayment(context);
                }
              : null,
          child: _processing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Complete Payment'),
        ),
      ],
    );
  }

  Future<void> _completeCashPayment(BuildContext context) async {
    debugPrint('✅ Cash Payment: Complete button pressed');
    debugPrint('   Order ID: ${widget.order.id}');
    debugPrint('   Tendered: £${_tenderedAmount.toStringAsFixed(2)}');
    debugPrint('   Change: £${_changeDue.toStringAsFixed(2)}');
    debugPrint(
      '   Staff: ${widget.staffProvider.currentStaff?.fullName ?? "null"}',
    );

    // Show loading state
    if (!mounted) return;
    setState(() => _processing = true);

    try {
      // 1. Complete order in memory
      debugPrint('   Completing order...');
      widget.orderProvider.completeOrder(
        paymentMethod: 'cash',
        amountPaid: _tenderedAmount,
        changeDue: _changeDue,
      );
      debugPrint('   Order completed successfully');

      // 1.5. Open cash drawer for cash payment
      debugPrint('   Opening cash drawer...');
      try {
        await PrinterService.instance.openCashDrawer();
        debugPrint('✅ Cash drawer opened successfully');
      } catch (e) {
        debugPrint('⚠️ Failed to open cash drawer: $e');
        // Don't block payment completion if drawer fails
      }

      // 2. Save to Supabase
      debugPrint('   Saving to Supabase...');
      final saved = await widget.orderProvider.saveCompletedOrderToSupabase();
      
      if (!saved) {
        debugPrint('⚠️ Failed to save to Supabase, but continuing...');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Warning: Order may not be saved to database'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        debugPrint('✅ Order saved to Supabase successfully');
      }

      // 3. Clear order history (for table orders)
      if (widget.order.tableNumber != null) {
        debugPrint('   Clearing order history...');
        await widget.historyProvider.clearHistoryForOrder(widget.order.id);
      }

      // 4. Loyalty sync (award points / redemption)
      final updatedOrder = widget.orderProvider.currentOrder;
      debugPrint('🔍 [CASH] Checking loyalty sync...');
      debugPrint('   updatedOrder exists: ${updatedOrder != null}');
      debugPrint('   loyaltyCustomerId: ${updatedOrder?.loyaltyCustomerId}');
      debugPrint('   loyaltyRestaurantId: ${updatedOrder?.loyaltyRestaurantId}');
      debugPrint('   totalDue: ${updatedOrder?.totalDue}');
      debugPrint('   loyaltyRewardId: ${updatedOrder?.loyaltyRewardId}');
      debugPrint('   loyaltyRewardType: ${updatedOrder?.loyaltyRewardType}');
      
      if (updatedOrder != null && updatedOrder.loyaltyCustomerId != null) {
        try {
          debugPrint('   Processing loyalty rewards...');
          
          // Get loyalty settings from outlet
          final outletProvider = context.read<OutletProvider>();
          final loyaltyEnabled = outletProvider.currentSettings?.loyaltyEnabled ?? true;
          final pointsPerPound = outletProvider.currentSettings?.loyaltyPointsPerPound ?? 1.0;
          final doublePointsEnabled = outletProvider.currentSettings?.loyaltyDoublePointsEnabled ?? false;
          
          if (!loyaltyEnabled) {
            debugPrint('⚠️ Loyalty disabled in settings, skipping');
          } else {
            final awarded = await LoyaltyCoordinator.instance.handlePaymentCompletion(
              updatedOrder,
              pointsPerPound: pointsPerPound,
              doublePointsEnabled: doublePointsEnabled,
            );
            if (awarded) {
              final effectiveRate = doublePointsEnabled ? pointsPerPound * 2 : pointsPerPound;
              final pointsAwarded = (updatedOrder.totalDue * effectiveRate).floor();
              debugPrint('✅ Loyalty points awarded: $pointsAwarded points');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Loyalty points added: $pointsAwarded points${doublePointsEnabled ? " (2x!)" : ""}'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } else {
              debugPrint('⚠️ No loyalty points awarded (might be duplicate or no customer attached)');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Loyalty points failed (non-blocking): $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ Points failed to apply: $e'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          // Don't block payment completion
        }
      } else {
        debugPrint('⚠️ No loyalty customer attached, skipping points award');
      }

      // 5. Auto-print receipt if enabled (don't block UI)
      _autoPrintReceiptIfEnabled(context);

      // 6. Navigate to receipt
      debugPrint('   Closing modal...');
      if (context.mounted) {
        Navigator.of(context).pop();
        debugPrint('   Navigating to receipt screen...');
        context.go('/receipt');
        debugPrint('   Navigation complete');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error completing cash payment: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _processing = false);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _autoPrintReceiptIfEnabled(BuildContext context) async {
    final printerService = PrinterService.instance;
    final outlet = context.read<OutletProvider>().currentOutlet;
    
    if (!printerService.autoPrintReceiptEnabled) {
      debugPrint('🖨️ Auto-print: Disabled');
      return;
    }
    
    final defaultPrinter = printerService.getDefaultReceiptPrinter();
    if (defaultPrinter == null) {
      debugPrint('🖨️ Auto-print: No receipt printer configured');
      return;
    }

    // Print in background, don't block UI
    Future(() async {
      try {
        debugPrint('🖨️ Auto-print: Printing receipt to ${defaultPrinter.name}...');
        await printerService.printCustomerReceipt(widget.order, outletName: outlet?.name, outlet: outlet);
        debugPrint('✅ Auto-print: Receipt printed successfully');
      } catch (e) {
        debugPrint('❌ Auto-print failed: $e');
        // Don't show error to user for auto-print, just log it
      }
    });
  }
}

class _CashButton extends StatelessWidget {
  final double amount;
  final VoidCallback onTap;

  const _CashButton({required this.amount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        child: Text(
          '£${amount.toInt()}',
          style: Theme.of(context).textTheme.titleMedium?.bold,
        ),
      ),
    );
  }
}

class _DiscountModal extends StatefulWidget {
  final Order order;

  const _DiscountModal({required this.order});

  @override
  State<_DiscountModal> createState() => _DiscountModalState();
}

class _DiscountModalState extends State<_DiscountModal> {
  final TextEditingController _percentController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isPercent = true;

  @override
  void dispose() {
    _percentController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasDiscount = widget.order.discountAmount > 0;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.card_giftcard, color: colorScheme.secondary),
          const SizedBox(width: AppSpacing.sm),
          Text(hasDiscount ? 'Manage Loyalty Card' : 'Apply Loyalty Card'),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasDiscount) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_offer,
                      color: colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Loyalty Card',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                          Text(
                            '£${widget.order.discountAmount.toStringAsFixed(2)}',
                            style: theme.textTheme.titleLarge?.bold.copyWith(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Update or remove loyalty card',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Percent')),
                ButtonSegment(value: false, label: Text('Amount')),
              ],
              selected: {_isPercent},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() => _isPercent = newSelection.first);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_isPercent)
              TextField(
                controller: _percentController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Loyalty Card Percentage',
                  suffixText: '%',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              )
            else
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Loyalty Card Amount',
                  prefixText: '£',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (hasDiscount)
          TextButton(
            onPressed: () {
              final orderProvider = context.read<OrderProvider>();
              orderProvider.clearDiscount();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.error,
            ),
            child: const Text('Remove Loyalty Card'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final orderProvider = context.read<OrderProvider>();
            if (_isPercent) {
              final percent = double.tryParse(_percentController.text) ?? 0.0;
              final amount = widget.order.subtotal * (percent / 100);
              orderProvider.applyDiscount(amount);
            } else {
              final amount = double.tryParse(_amountController.text) ?? 0.0;
              orderProvider.applyDiscount(amount);
            }
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _VoucherModal extends StatefulWidget {
  const _VoucherModal();

  @override
  State<_VoucherModal> createState() => _VoucherModalState();
}

class _VoucherModalState extends State<_VoucherModal> {
  final TextEditingController _codeController = TextEditingController();
  bool _isValidating = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.confirmation_number_outlined, color: colorScheme.secondary),
          const SizedBox(width: AppSpacing.sm),
          const Text('Voucher Code'),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Enter Voucher Code',
                hintText: 'ABC123',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                errorText: _errorMessage.isEmpty ? null : _errorMessage,
              ),
            ),
            if (_isValidating) ...[
              const SizedBox(height: AppSpacing.md),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isValidating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isValidating ? null : _validateVoucher,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Future<void> _validateVoucher() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a voucher code');
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = '';
    });

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // TODO: Implement actual voucher validation
    setState(() => _isValidating = false);
    
    final orderProvider = context.read<OrderProvider>();
    orderProvider.applyVoucher(5.0);
    
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Voucher $code applied: £5.00 discount')),
    );
  }
}

class _DiscountCardModal extends StatefulWidget {
  final Order order;
  final SplitBill? splitBill;

  const _DiscountCardModal({required this.order, this.splitBill});

  @override
  State<_DiscountCardModal> createState() => _DiscountCardModalState();
}

class _DiscountCardModalState extends State<_DiscountCardModal> with SingleTickerProviderStateMixin {
  static const String _restaurantMongoId = '68ccdacc4c19b2344d711c20';
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();
  bool _loadingCustomer = false;
  bool _loadingRewards = false;
  bool _testingAward = false;
  String? _error;
  String? _rewardError;
  String? _testResponse;
  LoyaltyCustomer? _selectedCustomer;
  List<LoyaltyReward> _offers = [];
  List<LoyaltyReward> _coupons = [];
  LoyaltyReward? _selectedReward;
  late TabController _tabController;

  Order get _activeOrder => context.read<OrderProvider>().currentOrder ?? widget.order;
  double get _subtotal => widget.splitBill?.subtotal ?? _activeOrder.subtotal;
  double get _totalDue => widget.splitBill?.totalDue ?? _activeOrder.totalDue;

  @override
  void initState() {
    super.initState();
    _pointsController.text = _calculatePointsToAward().toStringAsFixed(0);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _pointsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.card_membership, color: colorScheme.secondary),
          const SizedBox(width: AppSpacing.sm),
          const Text('Scan / Enter Discount Card Number'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter discount card number', style: theme.textTheme.titleMedium?.semiBold),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _identifierController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Card / Barcode Identifier',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  errorText: _error,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadingCustomer ? null : _findCustomer,
                    icon: _loadingCustomer
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    label: const Text('Find Customer'),
                  ),
                  if (_selectedCustomer != null)
                    OutlinedButton.icon(
                      onPressed: _loadingRewards ? null : _loadRewards,
                      icon: _loadingRewards
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.local_offer),
                      label: const Text('Load Rewards'),
                    ),
                  if (_selectedCustomer != null)
                    OutlinedButton.icon(
                      onPressed: _testingAward ? null : _testAwardPoints,
                      icon: _testingAward
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.bolt),
                      label: const Text('Test Award Points'),
                    ),
                ],
              ),
              if (_selectedCustomer != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer found', style: theme.textTheme.titleMedium?.semiBold),
                      const SizedBox(height: AppSpacing.xs),
                      _InfoRow(label: 'Name', value: _selectedCustomer!.fullName),
                      _InfoRow(label: 'Identifier', value: _selectedCustomer!.identifier ?? '-'),
                      _InfoRow(label: 'Points', value: _selectedCustomer!.points.toStringAsFixed(0)),
                    ],
                  ),
                ),
              ],
              if (_rewardError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colorScheme.error, size: 20),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(child: Text(_rewardError!, style: TextStyle(color: colorScheme.error))),
                    ],
                  ),
                ),
              ],
              if (_offers.isNotEmpty || _coupons.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                TabBar(
                  controller: _tabController,
                  labelColor: colorScheme.primary,
                  tabs: const [Tab(text: 'Offers'), Tab(text: 'Coupons')],
                ),
                SizedBox(
                  height: 220,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _rewardList(context, _offers),
                      _rewardList(context, _coupons),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text('Points preview', style: theme.textTheme.titleMedium?.semiBold),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _pointsController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Points to add on completion',
                  helperText: 'Auto-calculated from bill total',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_selectedReward != null)
                _InfoRow(
                  label: 'Loyalty card preview',
                  value: '£${_previewDiscount().toStringAsFixed(2)} → new total £${(_totalDue - _previewDiscount()).clamp(0, _totalDue).toStringAsFixed(2)}',
                ),
              if (_testResponse != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Test award response', style: theme.textTheme.titleMedium?.semiBold),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  width: double.infinity,
                  padding: AppSpacing.paddingSm,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(_testResponse!, style: theme.textTheme.bodySmall),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        if (_selectedReward != null)
          TextButton(
            onPressed: () {
              final orderProvider = context.read<OrderProvider>();
              orderProvider.clearDiscount();
              orderProvider.clearLoyaltyAttachment();
            },
            child: const Text('Remove Discount'),
          ),
        if (_selectedCustomer != null && _selectedReward == null)
          TextButton(
            onPressed: _selectedCustomer == null ? null : _continueWithoutDiscount,
            child: const Text('Attach Customer'),
          ),
        ElevatedButton(
          onPressed: _selectedCustomer != null ? _applyLoyalty : null,
          child: const Text('Apply Loyalty Card'),
        ),
      ],
    );
  }

  Widget _rewardList(BuildContext context, List<LoyaltyReward> rewards) {
    if (rewards.isEmpty) {
      return const Center(child: Text('No rewards available'));
    }

    return ListView.separated(
      itemCount: rewards.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final reward = rewards[index];
        final isSelected = _selectedReward?.id == reward.id;
        return ListTile(
          title: Text(reward.name),
          subtitle: Text(reward.description ?? ''),
          trailing: Text(
            reward.discountType == LoyaltyDiscountType.percentage
                ? '${reward.discountValue.toStringAsFixed(0)}%'
                : '£${reward.discountValue.toStringAsFixed(2)}',
          ),
          selected: isSelected,
          onTap: () => setState(() => _selectedReward = reward),
        );
      },
    );
  }

  Future<void> _findCustomer() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() => _error = 'Please enter an identifier');
      return;
    }

    setState(() {
      _error = null;
      _loadingCustomer = true;
      _rewardError = null;
      _offers = [];
      _coupons = [];
      _selectedReward = null;
      _testResponse = null;
    });

    try {
      debugPrint('🔍 Finding customer with identifier: $identifier');
      final results = await LoyaltyService.findCustomer(identifier);
      debugPrint('✅ Customer lookup returned ${results.length} results');
      if (results.isEmpty) {
        setState(() {
          _error = 'Customer not found';
          _selectedCustomer = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer not found for that card number')),
          );
        }
      } else {
        final found = results.first;
        final attachedCustomer = LoyaltyCustomer(
          id: found.id,
          fullName: found.fullName,
          email: found.email,
          phone: found.phone,
          identifier: found.identifier ?? identifier,
          points: found.points,
        );

        final orderProvider = context.read<OrderProvider>();
        final pointsPreview = _calculatePointsToAward();

        orderProvider.applyLoyaltyAttachment(
          customer: attachedCustomer,
          pointsToAward: pointsPreview,
          restaurantId: _restaurantMongoId,
        );

        _pointsController.text = pointsPreview.toStringAsFixed(0);

        setState(() {
          _selectedCustomer = attachedCustomer;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Customer attached: ${attachedCustomer.fullName}')),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Customer lookup failed: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() => _error = 'Lookup failed: ${e.toString()}');
    } finally {
      setState(() => _loadingCustomer = false);
    }
  }

  Future<void> _loadRewards() async {
    if (_selectedCustomer == null || _selectedCustomer!.id.isEmpty) {
      setState(() => _error = 'Find customer first');
      return;
    }
    setState(() {
      _loadingRewards = true;
      _rewardError = null;
    });

    final restaurantId = _restaurantMongoId;

    try {
      final discountUserId = _selectedCustomer!.id;
      debugPrint('🎁 PaymentScreen: Loading rewards for customerId=$discountUserId, restaurantId=$restaurantId');
      final result = await LoyaltyService.loadRewards(
        userId: discountUserId,
        restaurantId: restaurantId,
      );
      debugPrint('✅ PaymentScreen: Loaded ${result.offers.length} offers and ${result.coupons.length} coupons');
      setState(() {
        _offers = result.offers;
        _coupons = result.coupons;
        _selectedReward = null;
        _rewardError = null;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ PaymentScreen: Failed to load rewards: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() => _rewardError = 'Failed to load rewards: ${e.toString()}');
    } finally {
      setState(() => _loadingRewards = false);
    }
  }

  double _previewDiscount() {
    if (_selectedReward == null) return 0;
    return _selectedReward!.calculateDiscount(_subtotal);
  }

  void _applyLoyalty() {
    if (_selectedCustomer == null) return;

    final orderProvider = context.read<OrderProvider>();
    final points = _calculatePointsToAward();
    final discountAmount = _selectedReward != null ? _previewDiscount() : null;

    orderProvider.applyLoyaltyAttachment(
      customer: _selectedCustomer!,
      pointsToAward: points,
      restaurantId: _restaurantMongoId,
      reward: _selectedReward,
      discountAmount: discountAmount,
    );

    Navigator.of(context).pop();
  }

  double _calculatePointsToAward() => (_totalDue * 1.0).floorToDouble(); // Default 1 point per pound

  Future<void> _testAwardPoints() async {
    if (_selectedCustomer == null) return;

    final body = {
      'userId': _selectedCustomer!.id,
      'type': 'earn',
      'restaurantId': _restaurantMongoId,
      'points': 10,
      'orderDetails': 'FlowTill POS | Test award (dev button)',
    };

    setState(() {
      _testingAward = true;
      _testResponse = null;
    });

    try {
      final response = await LoyaltyService.awardPoints(body);
      final responseText = response != null ? response.toString() : 'Success (no body)';
      setState(() => _testResponse = responseText);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test award sent (10 points)')),
        );
      }
    } catch (e) {
      setState(() => _testResponse = 'Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test award failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _testingAward = false);
      }
    }
  }

  void _continueWithoutDiscount() {
    if (_selectedCustomer == null) return;
    final orderProvider = context.read<OrderProvider>();
    final points = _calculatePointsToAward();

    orderProvider.applyLoyaltyAttachment(
      customer: _selectedCustomer!,
      pointsToAward: points,
      restaurantId: _restaurantMongoId,
    );

    Navigator.of(context).pop();
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.bodyMedium?.semiBold),
        ],
      ),
    );
  }
}


