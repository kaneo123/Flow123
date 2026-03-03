import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/models/order.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/providers/staff_provider.dart';
import 'package:flowtill/providers/login_provider.dart';
import 'package:flowtill/services/printer/printer_service.dart';
import 'package:flowtill/theme.dart';
import 'package:intl/intl.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  Timer? _logoutTimer;
  int _remainingSeconds = 3;

  @override
  void initState() {
    super.initState();
    _startLogoutTimer();
  }

  @override
  void dispose() {
    _logoutTimer?.cancel();
    super.dispose();
  }

  void _startLogoutTimer() {
    _logoutTimer?.cancel();
    setState(() => _remainingSeconds = 3);

    _logoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _autoLogout();
      }
    });
  }

  void _resetTimer() {
    _startLogoutTimer();
  }

  void _autoLogout() {
    if (!mounted) return;

    final staffProvider = context.read<StaffProvider>();
    final loginProvider = context.read<LoginProvider>();
    final orderProvider = context.read<OrderProvider>();

    orderProvider.clearCurrentOrderAndSelection();
    staffProvider.logout();
    loginProvider.clearAuthenticatedStaff();

    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrderProvider>().currentOrder;
    final outlet = context.watch<OutletProvider>().currentOutlet;

    if (order == null || order.completedAt == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return GestureDetector(
      onTap: _resetTimer,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight;
              final availableWidth = constraints.maxWidth;
              
              // Responsive sizing
              final iconSize = (availableHeight * 0.1).clamp(48.0, 72.0);
              final maxCardWidth = availableWidth > 800 ? 600.0 : availableWidth * 0.9;
              final vertPadding = (availableHeight * 0.02).clamp(12.0, 24.0);
              final horzPadding = (availableWidth * 0.03).clamp(16.0, 32.0);
              
              return Column(
                children: [
                  // Countdown banner at top
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Auto-logout in $_remainingSeconds seconds (tap anywhere to reset)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: maxCardWidth),
                        margin: EdgeInsets.symmetric(
                          horizontal: horzPadding,
                          vertical: vertPadding,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _ReceiptHeader(
                              order: order,
                              outlet: outlet,
                              iconSize: iconSize,
                              padding: vertPadding,
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: _ReceiptBody(
                                order: order,
                                padding: vertPadding,
                              ),
                            ),
                            const Divider(height: 1),
                            _ReceiptActions(
                              order: order,
                              padding: vertPadding,
                              onAction: _resetTimer,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReceiptHeader extends StatelessWidget {
  final Order order;
  final dynamic outlet;
  final double iconSize;
  final double padding;

  const _ReceiptHeader({
    required this.order,
    this.outlet,
    required this.iconSize,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: iconSize,
            color: colorScheme.primary,
          ),
          SizedBox(height: padding * 0.5),
          Text(
            'Payment Complete',
            style: theme.textTheme.headlineMedium?.bold.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: padding * 0.3),
          Text(
            DateFormat('dd MMM yyyy, HH:mm').format(order.completedAt!),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (outlet?.name != null) ...[
            SizedBox(height: padding * 0.2),
            Text(
              outlet.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReceiptBody extends StatelessWidget {
  final Order order;
  final double padding;

  const _ReceiptBody({required this.order, required this.padding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Order Details',
            style: theme.textTheme.titleLarge?.bold.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: padding * 0.5),
          Container(
            padding: EdgeInsets.all(padding * 0.6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _InfoRow(
                  label: 'Order ID',
                  value: order.id.substring(0, 8).toUpperCase(),
                ),
                SizedBox(height: padding * 0.3),
                _InfoRow(
                  label: 'Payment Method',
                  value: order.paymentMethod ?? 'Unknown',
                ),
                if (order.tableNumber != null) ...[
                  SizedBox(height: padding * 0.3),
                  _InfoRow(
                    label: 'Table Number',
                    value: order.tableNumber!,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: padding * 0.8),
          Text(
            'Items',
            style: theme.textTheme.titleMedium?.semiBold.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: padding * 0.5),
          ...order.items.map(
            (item) => Padding(
              padding: EdgeInsets.symmetric(vertical: padding * 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${item.quantity}',
                          style: theme.textTheme.labelSmall?.bold.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      SizedBox(width: padding * 0.5),
                      Expanded(
                        child: Text(
                          item.product.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        '£${item.total.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.semiBold.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  if (item.selectedModifiers.isNotEmpty) ...[
                    SizedBox(height: padding * 0.2),
                    Padding(
                      padding: EdgeInsets.only(left: 28 + padding * 0.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: item.selectedModifiers.map((modifier) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: padding * 0.1),
                            child: Text(
                              '  > ${modifier.displayText}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: padding * 0.8),
          const Divider(height: 1),
          SizedBox(height: padding * 0.8),
          _SummaryRow(
            label: 'Subtotal',
            value: '£${order.subtotal.toStringAsFixed(2)}',
          ),
          SizedBox(height: padding * 0.3),
          _SummaryRow(
            label: 'Tax',
            value: '£${order.taxAmount.toStringAsFixed(2)}',
          ),
          if (order.serviceCharge > 0) ...[
            SizedBox(height: padding * 0.3),
            _SummaryRow(
              label: 'Service Charge',
              value: '£${order.serviceCharge.toStringAsFixed(2)}',
            ),
          ],
          if (order.totalDiscounts > 0) ...[
            SizedBox(height: padding * 0.3),
            _SummaryRow(
              label: 'Discounts',
              value: '-£${order.totalDiscounts.toStringAsFixed(2)}',
              valueColor: Theme.of(context).colorScheme.error,
            ),
          ],
          SizedBox(height: padding * 0.5),
          const Divider(height: 1),
          SizedBox(height: padding * 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Paid',
                style: theme.textTheme.titleLarge?.bold.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                '£${order.totalDue.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.bold.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          if (order.changeDue > 0) ...[
            SizedBox(height: padding * 0.5),
            Container(
              padding: EdgeInsets.all(padding * 0.6),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Change Given',
                    style: theme.textTheme.titleMedium?.bold.copyWith(
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                  Text(
                    '£${order.changeDue.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.bold.copyWith(
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.semiBold.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

class _ReceiptActions extends StatelessWidget {
  final Order order;
  final double padding;
  final VoidCallback onAction;

  const _ReceiptActions({
    required this.order,
    required this.padding,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    onAction();
                    _printReceipt(context);
                  },
                  icon: const Icon(Icons.print),
                  label: const Text('Print'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: padding * 0.6),
                  ),
                ),
              ),
              SizedBox(width: padding * 0.5),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    onAction();
                    _emailReceipt(context);
                  },
                  icon: const Icon(Icons.email),
                  label: const Text('Email'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: padding * 0.6),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: padding * 0.5),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                onAction();
                _startNewOrder(context);
              },
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('New Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(vertical: padding * 0.6),
              ),
            ),
          ),
          SizedBox(height: padding * 0.5),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                onAction();
                _finishAndLogout(context);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Finish & Logout'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: padding * 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printReceipt(BuildContext context) async {
    final printerService = PrinterService.instance;
    final outlet = context.read<OutletProvider>().currentOutlet;

    // Check if printer is configured
    final defaultPrinter = printerService.getDefaultReceiptPrinter();
    if (defaultPrinter == null) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No Printer Configured'),
          content: const Text(
            'No receipt printer is configured. Please go to Settings → Printer Configuration and ensure you have a printer with type="receipt" in the Supabase printers table.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await printerService.printCustomerReceipt(order, outletName: outlet?.name, outlet: outlet);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Receipt sent to printer'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Print Failed'),
            content: Text(
              'Failed to print receipt:\n\n$e\n\n'
              'Make sure:\n'
              '• Printer is turned on and connected\n'
              '• Printer has paper loaded\n'
              '• Connection is active',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _emailReceipt(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _EmailReceiptDialog(order: order),
    );
  }

  void _startNewOrder(BuildContext context) {
    final orderProvider = context.read<OrderProvider>();
    final outletProvider = context.read<OutletProvider>();
    final outlet = outletProvider.currentOutlet;
    
    // Clear current order and any table selection, then start fresh
    orderProvider.clearCurrentOrderAndSelection();
    orderProvider.startNewOrder(
      autoEnableServiceCharge: outlet?.enableServiceCharge ?? false,
      outletServiceChargePercent: outlet?.serviceChargePercent ?? 0.0,
    );
    
    context.go('/'); // back to till, staff stays logged in
  }

  void _finishAndLogout(BuildContext context) {
    final staffProvider = context.read<StaffProvider>();
    final loginProvider = context.read<LoginProvider>();
    final orderProvider = context.read<OrderProvider>();

    // Clear current order and selection before logout (already completed, no need to park)
    orderProvider.clearCurrentOrderAndSelection();
    
    staffProvider.logout(); // No need to park since order is already completed
    loginProvider.clearAuthenticatedStaff();

    context.go('/login');
  }
}

class _EmailReceiptDialog extends StatefulWidget {
  final Order order;

  const _EmailReceiptDialog({required this.order});

  @override
  State<_EmailReceiptDialog> createState() => _EmailReceiptDialogState();
}

class _EmailReceiptDialogState extends State<_EmailReceiptDialog> {
  final TextEditingController _emailController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Email Receipt'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Customer Email',
              hintText: 'customer@example.com',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          if (_isSending) ...[
            const SizedBox(height: AppSpacing.md),
            const CircularProgressIndicator(),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _sendEmail,
          child: const Text('Send'),
        ),
      ],
    );
  }

  Future<void> _sendEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() => _isSending = true);

    // TODO: Implement email sending logic
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Receipt sent to $email')),
    );
  }
}
