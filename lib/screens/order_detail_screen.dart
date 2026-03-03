import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/models/order_with_meta.dart';
import 'package:flowtill/models/epos_order_item.dart';
import 'package:flowtill/models/refund_transaction.dart';
import 'package:flowtill/providers/staff_provider.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/services/order_repository.dart';
import 'package:flowtill/services/transaction_repository.dart';
import 'package:flowtill/theme.dart';
import 'package:intl/intl.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderRepository _orderRepository = OrderRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();
  
  OrderWithMeta? _orderMeta;
  List<EposOrderItem> _items = [];
  List<RefundTransaction> _refunds = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() => _isLoading = true);

    final orderMeta = await _orderRepository.getOrderWithMetaById(widget.orderId);
    final items = await _orderRepository.getOrderItems(widget.orderId);
    final refunds = await _transactionRepository.getRefundsForOrder(widget.orderId);

    setState(() {
      _orderMeta = orderMeta;
      _items = items;
      _refunds = refunds;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading || _orderMeta == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Order Details'),
        ),
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    final order = _orderMeta!.order;
    final staffProvider = context.watch<StaffProvider>();

    // Debug logging
    debugPrint('🔍 OrderDetailScreen: Refund button conditions:');
    debugPrint('   Staff logged in: ${staffProvider.currentStaff != null}');
    debugPrint('   Staff name: ${staffProvider.currentStaff?.fullName}');
    debugPrint('   Permission level: ${staffProvider.currentStaff?.permissionLevel}');
    debugPrint('   canRefund: ${staffProvider.canRefund}');
    debugPrint('   Order status: ${order.status}');
    debugPrint('   Is fully refunded: ${_orderMeta!.refundStatus.isFullyRefunded}');
    debugPrint('   Should show button: ${staffProvider.canRefund && !_orderMeta!.refundStatus.isFullyRefunded && order.status == 'completed'}');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          // Refund button (grey out if already refunded)
          if (staffProvider.canRefund && order.status == 'completed')
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: FilledButton.icon(
                onPressed: _orderMeta!.refundStatus.isFullyRefunded ? null : _showRefundDialog,
                icon: const Icon(Icons.currency_pound, size: 18),
                label: Text(_orderMeta!.refundStatus.isFullyRefunded ? 'Refunded' : 'Refund'),
                style: FilledButton.styleFrom(
                  backgroundColor: _orderMeta!.refundStatus.isFullyRefunded 
                      ? colorScheme.surfaceContainerHighest 
                      : colorScheme.error,
                  foregroundColor: _orderMeta!.refundStatus.isFullyRefunded
                      ? colorScheme.onSurfaceVariant
                      : null,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header summary
            _HeaderCard(orderMeta: _orderMeta!),
            const SizedBox(height: AppSpacing.md),

            // Order items
            _SectionHeader(title: 'Order Items'),
            const SizedBox(height: AppSpacing.sm),
            _ItemsCard(items: _items),
            const SizedBox(height: AppSpacing.md),

            // Totals summary
            _SectionHeader(title: 'Totals'),
            const SizedBox(height: AppSpacing.sm),
            _TotalsCard(order: order),
            const SizedBox(height: AppSpacing.md),

            // Refunds (if any)
            if (_refunds.isNotEmpty) ...[
              _SectionHeader(title: 'Refunds'),
              const SizedBox(height: AppSpacing.sm),
              _RefundsCard(refunds: _refunds),
            ],
          ],
        ),
      ),
    );
  }

  void _showRefundDialog() {
    final order = _orderMeta!.order;
    final refundStatus = _orderMeta!.refundStatus;
    final maxRefundable = order.totalDue - refundStatus.totalRefunded;

    final TextEditingController amountController = TextEditingController(
      text: maxRefundable.toStringAsFixed(2),
    );

    String? selectedReason;
    bool restoreInventory = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Refund Order'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order Total: £${order.totalDue.toStringAsFixed(2)}'),
                if (refundStatus.hasRefund)
                  Text('Already Refunded: £${refundStatus.totalRefunded.toStringAsFixed(2)}'),
                Text('Maximum Refundable: £${maxRefundable.toStringAsFixed(2)}'),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Refund Amount',
                    prefixText: '£',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: const InputDecoration(
                    labelText: 'Refund Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Order Never Made', child: Text('Order Never Made (Mistake)')),
                    DropdownMenuItem(value: 'Price Error', child: Text('Price Error')),
                    DropdownMenuItem(value: 'Quality Issue', child: Text('Quality Issue')),
                    DropdownMenuItem(value: 'Customer Complaint', child: Text('Customer Complaint')),
                    DropdownMenuItem(value: 'Wrong Item', child: Text('Wrong Item Prepared')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                      // Auto-check restore inventory for "Order Never Made"
                      restoreInventory = value == 'Order Never Made';
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                CheckboxListTile(
                  value: restoreInventory,
                  onChanged: (value) => setState(() => restoreInventory = value ?? false),
                  title: const Text('Restore Inventory'),
                  subtitle: const Text('Check if items were never prepared/sold'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _confirmRefund(
                amountController.text,
                selectedReason,
                restoreInventory,
                maxRefundable,
              ),
              child: const Text('Confirm Refund'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRefund(
    String amountText,
    String? reason,
    bool restoreInventory,
    double maxRefundable,
  ) async {
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid refund amount', isError: true);
      return;
    }

    if (amount > maxRefundable) {
      _showSnackBar('Refund amount exceeds maximum refundable amount', isError: true);
      return;
    }

    Navigator.of(context).pop(); // Close dialog

    setState(() => _isLoading = true);

    final outletProvider = context.read<OutletProvider>();
    final staffProvider = context.read<StaffProvider>();

    final success = await _transactionRepository.refundOrder(
      orderId: widget.orderId,
      outletId: outletProvider.currentOutlet!.id,
      staffId: staffProvider.currentStaff!.id,
      amount: amount,
      reason: reason,
      restoreInventory: restoreInventory,
    );

    if (success) {
      final inventoryMsg = restoreInventory ? ' (inventory restored)' : '';
      _showSnackBar('Refund of £${amount.toStringAsFixed(2)} recorded successfully$inventoryMsg');
      await _loadOrderDetails(); // Refresh
    } else {
      _showSnackBar('Failed to record refund. Order may already be fully refunded.', isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final OrderWithMeta orderMeta;

  const _HeaderCard({required this.orderMeta});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final order = orderMeta.order;

    return Card(
      elevation: 2,
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${orderMeta.shortId}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const Spacer(),
                _StatusBadge(label: orderMeta.statusLabel),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            _InfoRow(
              label: 'Date & Time',
              value: order.completedAt != null
                  ? DateFormat('dd MMM yyyy, HH:mm').format(order.completedAt!)
                  : 'Not completed',
            ),
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(
              label: 'Order Type',
              value: orderMeta.orderLabel,
            ),
            if (orderMeta.staffName != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                label: 'Staff',
                value: orderMeta.staffName!,
              ),
            ],
            if (order.paymentMethod != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                label: 'Payment Method',
                value: order.paymentMethod!.toUpperCase(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  final List<EposOrderItem> items;

  const _ItemsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          children: items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Text(
                    '${item.quantity.toInt()}x',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      item.productName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '£${item.grossLineTotal.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final order;

  const _TotalsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          children: [
            _TotalRow(label: 'Subtotal', value: order.subtotal),
            const SizedBox(height: AppSpacing.xs),
            _TotalRow(label: 'Tax', value: order.taxAmount),
            if (order.serviceCharge > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              _TotalRow(label: 'Service Charge', value: order.serviceCharge),
            ],
            if (order.discountAmount > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              _TotalRow(label: 'Loyalty Card', value: -order.discountAmount, isNegative: true),
            ],
            if (order.voucherAmount > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              _TotalRow(label: 'Voucher', value: -order.voucherAmount, isNegative: true),
            ],
            if (order.loyaltyRedeemed > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              _TotalRow(label: 'Loyalty', value: -order.loyaltyRedeemed, isNegative: true),
            ],
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Text(
                  'Total',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '£${order.totalDue.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RefundsCard extends StatelessWidget {
  final List<RefundTransaction> refunds;

  const _RefundsCard({required this.refunds});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          children: refunds.map((refund) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(refund.createdAt),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '-£${refund.amount.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  if (refund.staffName != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Refunded by: ${refund.staffName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (refund.reason != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Reason: ${refund.reason}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
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
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isNegative;

  const _TotalRow({
    required this.label,
    required this.value,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          '£${value.abs().toStringAsFixed(2)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isNegative ? colorScheme.error : colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (bgColor, textColor) = _getColors(colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, Color) _getColors(ColorScheme colorScheme) {
    if (label.toLowerCase().contains('refunded')) {
      return (colorScheme.errorContainer, colorScheme.onErrorContainer);
    }
    if (label.toLowerCase().contains('partial')) {
      return (colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer);
    }
    return (colorScheme.secondaryContainer, colorScheme.onSecondaryContainer);
  }
}
