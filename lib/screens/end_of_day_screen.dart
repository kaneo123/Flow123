import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/providers/trading_day_provider.dart';
import 'package:flowtill/providers/navigation_provider.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/theme.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:intl/intl.dart';

class EndOfDayScreen extends StatefulWidget {
  const EndOfDayScreen({super.key});

  @override
  State<EndOfDayScreen> createState() => _EndOfDayScreenState();
}

class _EndOfDayScreenState extends State<EndOfDayScreen> {
  final _cashCountedController = TextEditingController();
  final _carryForwardController = TextEditingController();
  bool _carryForward = true;
  bool _isLoadingTotals = true;
  
  double _totalCashSales = 0.0;
  double _totalCardSales = 0.0;
  double _totalSales = 0.0;
  double? _customCarryForward;

  @override
  void initState() {
    super.initState();
    _loadSalesTotals();
  }

  Future<void> _loadSalesTotals() async {
    final tradingDayProvider = context.read<TradingDayProvider>();
    final outletProvider = context.read<OutletProvider>();
    
    if (tradingDayProvider.currentTradingDay == null || outletProvider.currentOutlet == null) {
      setState(() => _isLoadingTotals = false);
      return;
    }

    final tradingDay = tradingDayProvider.currentTradingDay!;

    try {
      // Query transactions for today's trading day
      // Filter out adjustment transactions (discount, voucher, loyalty, refund)
      final response = await SupabaseConfig.client
          .from('transactions')
          .select('payment_method, total_due')
          .eq('outlet_id', outletProvider.currentOutlet!.id)
          .gte('created_at', tradingDay.openedAt.toIso8601String())
          .eq('payment_status', 'completed');

      double cashTotal = 0.0;
      double cardTotal = 0.0;

      for (final txn in response as List) {
        final paymentMethod = txn['payment_method']?.toString().toLowerCase() ?? 'cash';
        
        // Skip adjustment transactions
        if (paymentMethod == 'discount' || 
            paymentMethod == 'voucher' || 
            paymentMethod == 'loyalty' || 
            paymentMethod == 'refund') {
          continue;
        }
        
        final amount = (txn['total_due'] as num?)?.toDouble() ?? 0.0;

        if (paymentMethod == 'cash') {
          cashTotal += amount;
        } else if (paymentMethod == 'card') {
          cardTotal += amount;
        }
      }

      setState(() {
        _totalCashSales = cashTotal;
        _totalCardSales = cardTotal;
        _totalSales = cashTotal + cardTotal;
        _isLoadingTotals = false;
      });
    } catch (e) {
      debugPrint('❌ Failed to load sales totals: $e');
      setState(() => _isLoadingTotals = false);
    }
  }

  double get _expectedCash {
    final tradingDay = context.read<TradingDayProvider>().currentTradingDay;
    if (tradingDay == null) return 0.0;
    return tradingDay.openingFloatAmount + _totalCashSales;
  }

  double? get _variance {
    final counted = double.tryParse(_cashCountedController.text);
    if (counted == null) return null;
    return counted - _expectedCash;
  }

  double get _carryForwardAmount {
    if (!_carryForward) return 0.0;
    if (_customCarryForward != null) return _customCarryForward!;
    final counted = double.tryParse(_cashCountedController.text) ?? 0.0;
    return counted;
  }

  Future<void> _endDay() async {
    final tradingDayProvider = context.read<TradingDayProvider>();
    final navProvider = context.read<NavigationProvider>();

    if (tradingDayProvider.currentTradingDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No trading day to close')),
      );
      return;
    }

    if (navProvider.loggedInStaff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No staff logged in')),
      );
      return;
    }

    final counted = double.tryParse(_cashCountedController.text);
    if (counted == null || counted < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid cash amount')),
      );
      return;
    }

    // Confirm end of day
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Trading Day'),
        content: Text(
          'Are you sure you want to close the trading day?\n\n'
          'Total Sales: £${_totalSales.toStringAsFixed(2)}\n'
          'Cash Variance: ${_variance != null ? "${_variance! < 0 ? "-" : "+"}£${_variance!.abs().toStringAsFixed(2)}" : "N/A"}\n'
          'Carry Forward: £${_carryForwardAmount.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await tradingDayProvider.endTradingDay(
      staffId: navProvider.loggedInStaff!.id,
      closingCashCounted: counted,
      totalCashSales: _totalCashSales,
      totalCardSales: _totalCardSales,
      totalSales: _totalSales,
      carryForward: _carryForward,
      customCarryForwardAmount: _customCarryForward,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trading day closed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      // Navigate back to till
      navProvider.setCurrentItem(NavigationItem.till);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tradingDayProvider.error ?? 'Failed to end trading day'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _cashCountedController.dispose();
    _carryForwardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tradingDay = context.watch<TradingDayProvider>().currentTradingDay;

    if (tradingDay == null || tradingDay.isClosed) {
      return Scaffold(
        backgroundColor: colorScheme.surfaceContainerHighest,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No Open Trading Day',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Start a new trading day to begin trading',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: AppSpacing.paddingLg,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available,
                    size: 32,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End of Day',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Trading day: ${DateFormat('dd MMM yyyy').format(tradingDay.tradingDate)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoadingTotals
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: AppSpacing.paddingLg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // System Totals Card
                          _SectionCard(
                            title: 'System Calculated Totals',
                            icon: Icons.calculate,
                            children: [
                              _TotalRow(
                                label: 'Cash Sales',
                                amount: _totalCashSales,
                                color: Colors.green,
                              ),
                              const Divider(height: 24),
                              _TotalRow(
                                label: 'Card Sales',
                                amount: _totalCardSales,
                                color: Colors.blue,
                              ),
                              const Divider(height: 24),
                              _TotalRow(
                                label: 'Total Sales',
                                amount: _totalSales,
                                isBold: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Cash Reconciliation Card
                          _SectionCard(
                            title: 'Cash Reconciliation',
                            icon: Icons.account_balance_wallet,
                            children: [
                              _InfoRow(
                                label: 'Opening Float',
                                value: '£${tradingDay.openingFloatAmount.toStringAsFixed(2)}',
                              ),
                              const Divider(height: 24),
                              _InfoRow(
                                label: 'Cash Sales',
                                value: '£${_totalCashSales.toStringAsFixed(2)}',
                              ),
                              const Divider(height: 24),
                              _InfoRow(
                                label: 'Expected Cash',
                                value: '£${_expectedCash.toStringAsFixed(2)}',
                                isBold: true,
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              // Cash Counted Input
                              Text(
                                'Cash Counted in Drawer',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextField(
                                controller: _cashCountedController,
                                decoration: InputDecoration(
                                  prefixText: '£ ',
                                  hintText: '0.00',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  contentPadding: AppSpacing.paddingMd,
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                                onChanged: (_) => setState(() {}),
                              ),

                              // Variance Display
                              if (_variance != null) ...[
                                const SizedBox(height: AppSpacing.lg),
                                Container(
                                  padding: AppSpacing.paddingMd,
                                  decoration: BoxDecoration(
                                    color: (_variance! < 0 ? Colors.red : Colors.green)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(
                                      color: (_variance! < 0 ? Colors.red : Colors.green)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _variance! < 0
                                            ? Icons.trending_down
                                            : Icons.trending_up,
                                        color: _variance! < 0 ? Colors.red : Colors.green,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Cash Variance',
                                              style: theme.textTheme.labelMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${_variance! < 0 ? "-" : "+"}£${_variance!.abs().toStringAsFixed(2)}',
                                              style: theme.textTheme.titleLarge?.copyWith(
                                                color: _variance! < 0 ? Colors.red : Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Carry Forward Card
                          _SectionCard(
                            title: 'Carry Forward to Next Day',
                            icon: Icons.arrow_forward,
                            children: [
                              SwitchListTile(
                                title: const Text('Carry cash forward to next trading day?'),
                                subtitle: Text(
                                  _carryForward
                                      ? 'Cash will be suggested as opening float'
                                      : 'Next day will start with £0.00 float',
                                  style: theme.textTheme.bodySmall,
                                ),
                                value: _carryForward,
                                onChanged: (value) => setState(() {
                                  _carryForward = value;
                                  _customCarryForward = null;
                                  _carryForwardController.clear();
                                }),
                                contentPadding: EdgeInsets.zero,
                              ),

                              if (_carryForward) ...[
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'Carry Forward Amount (optional)',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                TextField(
                                  controller: _carryForwardController,
                                  decoration: InputDecoration(
                                    prefixText: '£ ',
                                    hintText: _cashCountedController.text.isNotEmpty
                                        ? _cashCountedController.text
                                        : '0.00',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                    ),
                                    contentPadding: AppSpacing.paddingMd,
                                    helperText: 'Leave blank to use cash counted amount',
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                  ],
                                  onChanged: (value) => setState(() {
                                    _customCarryForward = double.tryParse(value);
                                  }),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Next day float: £${_carryForwardAmount.toStringAsFixed(2)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // End Day Button
                          Consumer<TradingDayProvider>(
                            builder: (context, provider, _) => FilledButton.icon(
                              onPressed: provider.isLoading ||
                                      _cashCountedController.text.isEmpty
                                  ? null
                                  : _endDay,
                              icon: provider.isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle),
                              label: Text(provider.isLoading
                                  ? 'Closing Day...'
                                  : 'Close Trading Day'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color? color;
  final bool isBold;

  const _TotalRow({
    required this.label,
    required this.amount,
    this.color,
    this.isBold = false,
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
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '£${amount.toStringAsFixed(2)}',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: color ?? colorScheme.onSurface,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
