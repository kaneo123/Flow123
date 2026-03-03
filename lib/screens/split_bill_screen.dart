import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flowtill/models/order.dart';
import 'package:flowtill/models/order_item.dart';
import 'package:flowtill/models/split_bill_segment.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/theme.dart';

class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({super.key});

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  final _uuid = const Uuid();
  String _splitMode = 'even'; // 'even' or 'items'
  int _numberOfPeople = 2;
  List<SplitBillSegment> _segments = [];
  final Set<String> _selectedItemIds = {};
  String _currentSegmentName = '';
  bool _showPaymentSelection = false;
  SplitBillSegment? _segmentToPay;

  @override
  void initState() {
    super.initState();
    _generateEvenSplits();
  }

  void _generateEvenSplits() {
    final orderProvider = context.read<OrderProvider>();
    final order = orderProvider.currentOrder;
    if (order == null) return;

    // Calculate per-person amounts
    final subtotalPerPerson = order.subtotal / _numberOfPeople;
    final taxPerPerson = order.taxAmount / _numberOfPeople;
    final discountPerPerson = (order.discountAmount + order.voucherAmount + order.loyaltyRedeemed) / _numberOfPeople;
    final promoPerPerson = order.promotionDiscount / _numberOfPeople;
    
    final afterDiscounts = subtotalPerPerson - promoPerPerson - discountPerPerson;
    final serviceChargePerPerson = afterDiscounts * order.serviceChargeRate;
    
    final totalPerPerson = subtotalPerPerson + taxPerPerson + serviceChargePerPerson - discountPerPerson - promoPerPerson;

    _segments = List.generate(
      _numberOfPeople,
      (index) => SplitBillSegment(
        id: _uuid.v4(),
        name: 'Person ${index + 1}',
        amount: totalPerPerson,
        subtotal: subtotalPerPerson,
        taxAmount: taxPerPerson,
        discountShare: discountPerPerson,
        promotionDiscountShare: promoPerPerson,
        serviceChargeShare: serviceChargePerPerson,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final order = orderProvider.currentOrder;

    if (order == null || order.items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: const Text('Split Bill'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/payment'),
        ),
      ),
      body: _showPaymentSelection && _segmentToPay != null
          ? _buildPaymentMethodSelection()
          : Column(
              children: [
                // Mode Selector
                Container(
                  padding: AppSpacing.paddingLg,
                  color: Theme.of(context).colorScheme.surface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'even',
                            label: Text('Split Evenly'),
                            icon: Icon(Icons.people, size: 20),
                          ),
                          ButtonSegment(
                            value: 'items',
                            label: Text('Split by Items'),
                            icon: Icon(Icons.list, size: 20),
                          ),
                        ],
                        selected: {_splitMode},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _splitMode = newSelection.first;
                            _segments.clear();
                            _selectedItemIds.clear();
                            if (_splitMode == 'even') {
                              _generateEvenSplits();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _splitMode == 'even'
                      ? _buildEvenSplitView(order)
                      : _buildItemSplitView(order),
                ),

                // Action Bar
                Container(
                  padding: AppSpacing.paddingLg,
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
                  child: _buildActionBar(context),
                ),
              ],
            ),
    );
  }

  Widget _buildEvenSplitView(Order order) {
    final totalPaid = _segments.where((s) => s.isPaid).fold(0.0, (sum, s) => sum + s.amount);
    final totalRemaining = _segments.where((s) => !s.isPaid).fold(0.0, (sum, s) => sum + s.amount);
    final allPaid = _segments.every((s) => s.isPaid);

    return Row(
      children: [
        // Left: Number of People Selector
        Expanded(
          flex: 2,
          child: Container(
            margin: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Split Between',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filled(
                        icon: const Icon(Icons.remove),
                        onPressed: _numberOfPeople > 2 ? () {
                          setState(() {
                            _numberOfPeople--;
                            _generateEvenSplits();
                          });
                        } : null,
                        iconSize: 32,
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      Text(
                        _numberOfPeople.toString(),
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      IconButton.filled(
                        icon: const Icon(Icons.add),
                        onPressed: _numberOfPeople < 10 ? () {
                          setState(() {
                            _numberOfPeople++;
                            _generateEvenSplits();
                          });
                        } : null,
                        iconSize: 32,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'People',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  const Divider(),
                  const SizedBox(height: AppSpacing.lg),
                  _SummaryRow(label: 'Each Person Pays', value: '£${_segments.first.amount.toStringAsFixed(2)}'),
                  const SizedBox(height: AppSpacing.xl),
                  if (totalPaid > 0) ...[
                    const Divider(),
                    const SizedBox(height: AppSpacing.lg),
                    _SummaryRow(
                      label: 'Total Paid',
                      value: '£${totalPaid.toStringAsFixed(2)}',
                      valueColor: Colors.green,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SummaryRow(
                      label: 'Remaining',
                      value: '£${totalRemaining.toStringAsFixed(2)}',
                      valueColor: allPaid ? Colors.green : Theme.of(context).colorScheme.error,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Right: Split Segments List
        Expanded(
          flex: 3,
          child: Container(
            margin: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: AppSpacing.paddingLg,
                  child: Text(
                    'Payment Splits',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: AppSpacing.paddingSm,
                    itemCount: _segments.length,
                    itemBuilder: (context, index) {
                      final segment = _segments[index];
                      return _SegmentCard(
                        segment: segment,
                        onRename: (newName) {
                          setState(() {
                            _segments[index] = segment.copyWith(name: newName);
                          });
                        },
                        onPay: () {
                          setState(() {
                            _segmentToPay = segment;
                            _showPaymentSelection = true;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemSplitView(Order order) {
    final availableItems = order.items.where((item) {
      // Item is available if it's not selected AND not already in a segment
      final alreadyInSegment = _segments.any((seg) => seg.items?.any((i) => i.id == item.id) ?? false);
      return !alreadyInSegment;
    }).toList();

    final totalPaid = _segments.where((s) => s.isPaid).fold(0.0, (sum, s) => sum + s.amount);
    final totalRemaining = _segments.where((s) => !s.isPaid).fold(0.0, (sum, s) => sum + s.amount);
    final totalAmount = _segments.fold(0.0, (sum, s) => sum + s.amount);

    return Row(
      children: [
        // Left: Available Items Selection
        Expanded(
          flex: 2,
          child: Container(
            margin: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Items',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Split Name',
                          hintText: 'e.g., John, Sarah, Table 5',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => _currentSegmentName = value,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: availableItems.isEmpty
                      ? Center(
                          child: Text(
                            'All items assigned to splits',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: AppSpacing.paddingSm,
                          itemCount: availableItems.length,
                          itemBuilder: (context, index) {
                            final item = availableItems[index];
                            final isSelected = _selectedItemIds.contains(item.id);

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedItemIds.add(item.id);
                                  } else {
                                    _selectedItemIds.remove(item.id);
                                  }
                                });
                              },
                              title: Text(
                                '${item.quantity}x ${item.product.name}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              subtitle: Text(
                                '£${item.product.price.toStringAsFixed(2)} each',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              secondary: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  '£${item.total.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (_selectedItemIds.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: AppSpacing.paddingLg,
                    child: ElevatedButton.icon(
                      onPressed: () => _addItemSplit(order),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Split'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Right: Created Splits
        Expanded(
          flex: 3,
          child: Container(
            margin: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Created Splits',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (_segments.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total: £${totalAmount.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            if (totalPaid > 0)
                              Text(
                                'Paid: £${totalPaid.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _segments.isEmpty
                      ? Center(
                          child: Text(
                            'No splits created yet',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: AppSpacing.paddingSm,
                          itemCount: _segments.length,
                          itemBuilder: (context, index) {
                            final segment = _segments[index];
                            return _ItemSplitCard(
                              segment: segment,
                              onDelete: () {
                                setState(() {
                                  _segments.removeAt(index);
                                });
                              },
                              onPay: () {
                                setState(() {
                                  _segmentToPay = segment;
                                  _showPaymentSelection = true;
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _addItemSplit(Order order) {
    if (_selectedItemIds.isEmpty) return;

    final selectedItems = order.items.where((item) => _selectedItemIds.contains(item.id)).toList();
    
    // Calculate subtotal and tax for selected items
    double subtotal = 0.0;
    double taxAmount = 0.0;
    for (final item in selectedItems) {
      subtotal += item.subtotal;
      taxAmount += item.taxAmount;
    }

    // Calculate proportional discount share
    final totalSubtotal = order.subtotal;
    final discountRatio = totalSubtotal > 0 ? subtotal / totalSubtotal : 0.0;
    final discountShare = (order.discountAmount + order.voucherAmount + order.loyaltyRedeemed) * discountRatio;
    final promotionDiscountShare = order.promotionDiscount * discountRatio;

    // Calculate service charge for this split (applied after discounts)
    final splitAfterDiscount = subtotal - promotionDiscountShare - discountShare;
    final serviceChargeShare = splitAfterDiscount * order.serviceChargeRate;

    // Calculate total due
    final totalDue = subtotal + taxAmount + serviceChargeShare - discountShare - promotionDiscountShare;

    final segmentName = _currentSegmentName.trim().isEmpty 
        ? 'Split ${_segments.length + 1}' 
        : _currentSegmentName.trim();

    final segment = SplitBillSegment(
      id: _uuid.v4(),
      name: segmentName,
      amount: totalDue,
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountShare: discountShare,
      promotionDiscountShare: promotionDiscountShare,
      serviceChargeShare: serviceChargeShare,
      items: selectedItems,
    );

    setState(() {
      _segments.add(segment);
      _selectedItemIds.clear();
      _currentSegmentName = '';
    });
  }

  Widget _buildPaymentMethodSelection() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Container(
          width: 500,
          margin: AppSpacing.paddingLg,
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Payment Method',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _segmentToPay!.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '£${_segmentToPay!.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton.icon(
                  onPressed: () => _processPayment('card'),
                  icon: const Icon(Icons.credit_card, size: 32),
                  label: const Text('Card', style: TextStyle(fontSize: 20)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton.icon(
                  onPressed: () => _processPayment('cash'),
                  icon: const Icon(Icons.payments, size: 32),
                  label: const Text('Cash', style: TextStyle(fontSize: 20)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _showPaymentSelection = false;
                    _segmentToPay = null;
                  });
                },
                child: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _processPayment(String paymentMethod) {
    if (_segmentToPay == null) return;

    if (paymentMethod == 'cash') {
      // Show cash payment modal for amount input
      _showCashPaymentModal();
    } else {
      // Card payment - mark as paid immediately
      _markSegmentAsPaid(paymentMethod);
    }
  }

  void _showCashPaymentModal() {
    if (_segmentToPay == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _CashPaymentDialog(
        amount: _segmentToPay!.amount,
        segmentName: _segmentToPay!.name,
        onComplete: (tenderedAmount, changeDue) {
          Navigator.of(dialogContext).pop();
          _markSegmentAsPaid('cash', tenderedAmount: tenderedAmount, changeDue: changeDue);
        },
        onCancel: () {
          Navigator.of(dialogContext).pop();
          setState(() {
            _showPaymentSelection = false;
            _segmentToPay = null;
          });
        },
      ),
    );
  }

  void _markSegmentAsPaid(String paymentMethod, {double? tenderedAmount, double? changeDue}) {
    if (_segmentToPay == null) return;

    setState(() {
      final index = _segments.indexWhere((s) => s.id == _segmentToPay!.id);
      if (index != -1) {
        _segments[index] = _segments[index].copyWith(
          paymentMethod: paymentMethod,
          paidAt: DateTime.now(),
          amountTendered: tenderedAmount,
          changeDue: changeDue,
        );
      }
      _showPaymentSelection = false;
      _segmentToPay = null;
    });

    // Show success message
    final changeInfo = changeDue != null && changeDue > 0 
        ? ' (Change: £${changeDue.toStringAsFixed(2)})' 
        : '';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_segments.firstWhere((s) => s.paymentMethod == paymentMethod && s.paidAt != null).name} paid via $paymentMethod$changeInfo'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final allPaid = _segments.isNotEmpty && _segments.every((s) => s.isPaid);
    final hasSplits = _segments.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.go('/payment'),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: allPaid ? () => _completeSplitPayment(context) : null,
            child: Text(
              allPaid 
                  ? 'Complete Payment' 
                  : hasSplits
                      ? 'Pay All Splits First'
                      : 'Create Splits to Continue',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _completeSplitPayment(BuildContext context) async {
    final orderProvider = context.read<OrderProvider>();
    
    // Create a summary of payment methods used
    final cardSegments = _segments.where((s) => s.paymentMethod == 'card');
    final cashSegments = _segments.where((s) => s.paymentMethod == 'cash');
    
    final cardTotal = cardSegments.fold(0.0, (sum, s) => sum + s.amount);
    final cashTotal = cashSegments.fold(0.0, (sum, s) => sum + s.amount);
    
    // Calculate total amounts
    final totalPaid = _segments.fold(0.0, (sum, s) => sum + s.amount);
    final totalTendered = _segments.fold(0.0, (sum, s) => sum + (s.amountTendered ?? s.amount));
    final totalChange = _segments.fold(0.0, (sum, s) => sum + (s.changeDue ?? 0.0));
    
    debugPrint('💰 Completing split bill payment:');
    debugPrint('   Total due: £${totalPaid.toStringAsFixed(2)}');
    debugPrint('   Card total: £${cardTotal.toStringAsFixed(2)}');
    debugPrint('   Cash total: £${cashTotal.toStringAsFixed(2)}');
    debugPrint('   Total tendered: £${totalTendered.toStringAsFixed(2)}');
    debugPrint('   Total change: £${totalChange.toStringAsFixed(2)}');
    
    // Determine primary payment method (for order record)
    // Use the payment method with the larger amount, or 'card' if equal
    final primaryPaymentMethod = cardTotal >= cashTotal ? 'card' : 'cash';
    
    // Build split payment summary for order notes
    final paymentSummary = <String>[];
    if (cardTotal > 0) paymentSummary.add('Card: £${cardTotal.toStringAsFixed(2)}');
    if (cashTotal > 0) paymentSummary.add('Cash: £${cashTotal.toStringAsFixed(2)}');
    final splitSummary = 'Split Bill (${paymentSummary.join(', ')})';
    
    // Complete the order with primary payment method
    orderProvider.completeOrder(
      paymentMethod: primaryPaymentMethod,
      amountPaid: totalTendered,
      changeDue: totalChange,
    );

    // Save to database (this will create the order and primary transaction)
    final saved = await orderProvider.saveCompletedOrderToSupabase(
      splitPaymentSummary: splitSummary,
      splitPayments: {
        if (cardTotal > 0) 'card': cardTotal,
        if (cashTotal > 0) 'cash': cashTotal,
      },
    );

    if (!saved) {
      debugPrint('⚠️ Failed to save split bill to database');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warning: Order may not be saved to database'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (context.mounted) {
      // Show success and navigate to receipt
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Split bill payment completed: $splitSummary'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      
      debugPrint('✅ Navigating to receipt screen');
      context.go('/receipt');
    }
  }
}

class _SegmentCard extends StatefulWidget {
  final SplitBillSegment segment;
  final Function(String) onRename;
  final VoidCallback onPay;

  const _SegmentCard({
    required this.segment,
    required this.onRename,
    required this.onPay,
  });

  @override
  State<_SegmentCard> createState() => _SegmentCardState();
}

class _SegmentCardState extends State<_SegmentCard> {
  bool _isEditing = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.segment.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            // Payment status indicator
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.segment.isPaid ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            
            // Name (editable if unpaid)
            Expanded(
              child: _isEditing && !widget.segment.isPaid
                  ? TextField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (value) {
                        setState(() => _isEditing = false);
                        if (value.trim().isNotEmpty) {
                          widget.onRename(value.trim());
                        }
                      },
                    )
                  : GestureDetector(
                      onTap: widget.segment.isPaid ? null : () => setState(() => _isEditing = true),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.segment.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.segment.isPaid)
                            Text(
                              'Paid via ${widget.segment.paymentMethod}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.green,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '£${widget.segment.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.segment.isPaid ? Colors.green : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(width: AppSpacing.md),
            
            // Pay button
            if (!widget.segment.isPaid)
              FilledButton.icon(
                onPressed: widget.onPay,
                icon: const Icon(Icons.payment, size: 20),
                label: const Text('Pay'),
              )
            else
              const Icon(Icons.check_circle, color: Colors.green, size: 32),
          ],
        ),
      ),
    );
  }
}

class _ItemSplitCard extends StatelessWidget {
  final SplitBillSegment segment;
  final VoidCallback onDelete;
  final VoidCallback onPay;

  const _ItemSplitCard({
    required this.segment,
    required this.onDelete,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.sm),
      child: ExpansionTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: segment.isPaid ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(
          segment.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: segment.isPaid
            ? Text(
                'Paid via ${segment.paymentMethod}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.green,
                ),
              )
            : Text('${segment.items?.length ?? 0} items'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '£${segment.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: segment.isPaid ? Colors.green : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            if (!segment.isPaid)
              FilledButton.icon(
                onPressed: onPay,
                icon: const Icon(Icons.payment, size: 20),
                label: const Text('Pay'),
              )
            else
              const Icon(Icons.check_circle, color: Colors.green, size: 32),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              children: [
                ...?segment.items?.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item.quantity}x ${item.product.name}'),
                      Text('£${item.total.toStringAsFixed(2)}'),
                    ],
                  ),
                )),
                if (!segment.isPaid) ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete, size: 20),
                        label: const Text('Remove Split'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
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
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _CashPaymentDialog extends StatefulWidget {
  final double amount;
  final String segmentName;
  final Function(double tenderedAmount, double changeDue) onComplete;
  final VoidCallback onCancel;

  const _CashPaymentDialog({
    required this.amount,
    required this.segmentName,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<_CashPaymentDialog> createState() => _CashPaymentDialogState();
}

class _CashPaymentDialogState extends State<_CashPaymentDialog> {
  double _tenderedAmount = 0.0;
  final TextEditingController _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  double get _changeDue => (_tenderedAmount - widget.amount).clamp(0.0, double.infinity);

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
            // Segment info
            Container(
              padding: AppSpacing.paddingSm,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: [
                  Text(
                    widget.segmentName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '£${widget.amount.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Exact change option
            InkWell(
              onTap: () {
                setState(() => _tenderedAmount = widget.amount);
                widget.onComplete(widget.amount, 0.0);
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Tap for exact change',
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
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Quick cash buttons
            Text(
              'Select cash amount tendered:',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
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

            // Custom amount input
            TextField(
              controller: _customController,
              keyboardType: TextInputType.number,
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

            // Change due display
            if (_tenderedAmount >= widget.amount) ...[
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
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
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
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _tenderedAmount >= widget.amount
              ? () => widget.onComplete(_tenderedAmount, _changeDue)
              : null,
          child: const Text('Complete Payment'),
        ),
      ],
    );
  }
}

class _CashButton extends StatelessWidget {
  final double amount;
  final VoidCallback onTap;

  const _CashButton({
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          '£${amount.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
