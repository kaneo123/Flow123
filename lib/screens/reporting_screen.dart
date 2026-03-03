import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flowtill/services/transaction_repository.dart';
import 'package:flowtill/services/till_adjustment_service.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/models/epos_transaction.dart';
import 'package:flowtill/theme.dart';

/// Reporting screen for sales summary and tender totals
/// Online-only - requires active internet connection
class ReportingScreen extends StatefulWidget {
  const ReportingScreen({super.key});

  @override
  State<ReportingScreen> createState() => _ReportingScreenState();
}

class _ReportingScreenState extends State<ReportingScreen> {
  final _transactionRepo = TransactionRepository();
  final _adjustmentService = TillAdjustmentService();
  final _connectionService = ConnectionService();
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Date filters
  DateFilter _selectedFilter = DateFilter.today;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  
  // Sales data
  List<EposTransaction> _transactions = [];
  double _totalRevenue = 0.0;
  int _transactionCount = 0;
  Map<String, double> _tenderTotals = {};
  double _tillAdjustmentTotal = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    // Check if online
    if (!_connectionService.isOnline) {
      setState(() {
        _errorMessage = 'Reporting requires an active internet connection. Please connect to the internet and try again.';
      });
      return;
    }

    final outletProvider = context.read<OutletProvider>();
    final outletId = outletProvider.currentOutlet?.id;

    if (outletId == null) {
      setState(() {
        _errorMessage = 'No outlet selected. Please select an outlet to view reports.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dateRange = _getDateRange();
      
      // Fetch transactions
      final transactions = await _transactionRepo.getTransactionsForOutlet(
        outletId,
        startDate: dateRange.start,
        endDate: dateRange.end,
      );

      // Fetch till adjustments
      final adjustments = await _adjustmentService.fetchAdjustments(
        outletId: outletId,
        startDate: dateRange.start,
        endDate: dateRange.end,
      );

      // Calculate totals by tender type
      final tenderTotals = <String, double>{};
      double revenue = 0.0;
      int count = 0;

      for (final txn in transactions) {
        // Only count main payment transactions (not adjustment transactions)
        if (txn.paymentMethod != 'discount' && 
            txn.paymentMethod != 'voucher' && 
            txn.paymentMethod != 'loyalty') {
          
          if (txn.paymentMethod == 'refund') {
            // Refunds are negative
            tenderTotals[txn.paymentMethod] = (tenderTotals[txn.paymentMethod] ?? 0.0) + txn.amountPaid.abs();
          } else {
            // Regular payments
            tenderTotals[txn.paymentMethod] = (tenderTotals[txn.paymentMethod] ?? 0.0) + txn.totalDue;
            revenue += txn.totalDue;
            count++;
          }
        }
      }

      // Calculate till adjustment total (sum of all adjustments)
      final adjustmentTotal = adjustments.fold<double>(0.0, (sum, adj) => sum + adj.amount);

      setState(() {
        _transactions = transactions;
        _tenderTotals = tenderTotals;
        _totalRevenue = revenue;
        _transactionCount = count;
        _tillAdjustmentTotal = adjustmentTotal;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load report data: $e';
        _isLoading = false;
      });
    }
  }

  DateTimeRange _getDateRange() {
    // Use UTC to match Supabase timestamps
    final now = DateTime.now().toUtc();
    
    switch (_selectedFilter) {
      case DateFilter.today:
        final startOfDay = DateTime.utc(now.year, now.month, now.day);
        final endOfDay = DateTime.utc(now.year, now.month, now.day, 23, 59, 59);
        return DateTimeRange(start: startOfDay, end: endOfDay);
        
      case DateFilter.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekDay = DateTime.utc(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final endOfDay = DateTime.utc(now.year, now.month, now.day, 23, 59, 59);
        return DateTimeRange(start: startOfWeekDay, end: endOfDay);
        
      case DateFilter.thisMonth:
        final startOfMonth = DateTime.utc(now.year, now.month, 1);
        final endOfDay = DateTime.utc(now.year, now.month, now.day, 23, 59, 59);
        return DateTimeRange(start: startOfMonth, end: endOfDay);
        
      case DateFilter.custom:
        if (_customStartDate != null && _customEndDate != null) {
          // Convert local date selection to UTC for querying
          final startUtc = DateTime.utc(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
          final endUtc = DateTime.utc(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59);
          return DateTimeRange(start: startUtc, end: endUtc);
        }
        // Fallback to today if custom dates not set
        final startOfDay = DateTime.utc(now.year, now.month, now.day);
        final endOfDay = DateTime.utc(now.year, now.month, now.day, 23, 59, 59);
        return DateTimeRange(start: startOfDay, end: endOfDay);
    }
  }

  String _getFilterLabel() {
    switch (_selectedFilter) {
      case DateFilter.today:
        return 'Today';
      case DateFilter.thisWeek:
        return 'This Week';
      case DateFilter.thisMonth:
        return 'This Month';
      case DateFilter.custom:
        if (_customStartDate != null && _customEndDate != null) {
          final formatter = DateFormat('dd/MM/yyyy');
          return '${formatter.format(_customStartDate!)} - ${formatter.format(_customEndDate!)}';
        }
        return 'Custom Range';
    }
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23, 59, 59,
        );
        _selectedFilter = DateFilter.custom;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Sales Reporting', style: theme.textTheme.titleLarge),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(theme, colorScheme),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    // Show error if offline or other issues
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Unable to Load Reports',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Filters section
        Container(
          padding: AppSpacing.paddingMd,
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
              Text(
                'Date Filter:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _FilterChip(
                      label: 'Today',
                      isSelected: _selectedFilter == DateFilter.today,
                      onSelected: () {
                        setState(() => _selectedFilter = DateFilter.today);
                        _loadData();
                      },
                    ),
                    _FilterChip(
                      label: 'This Week',
                      isSelected: _selectedFilter == DateFilter.thisWeek,
                      onSelected: () {
                        setState(() => _selectedFilter = DateFilter.thisWeek);
                        _loadData();
                      },
                    ),
                    _FilterChip(
                      label: 'This Month',
                      isSelected: _selectedFilter == DateFilter.thisMonth,
                      onSelected: () {
                        setState(() => _selectedFilter = DateFilter.thisMonth);
                        _loadData();
                      },
                    ),
                    _FilterChip(
                      label: _selectedFilter == DateFilter.custom && _customStartDate != null
                          ? _getFilterLabel()
                          : 'Custom Range',
                      isSelected: _selectedFilter == DateFilter.custom,
                      onSelected: _selectCustomDateRange,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: colorScheme.primary),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Loading report data...',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Summary cards
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              title: 'Total Revenue',
                              value: '£${_totalRevenue.toStringAsFixed(2)}',
                              icon: Icons.payments,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Transactions',
                              value: _transactionCount.toString(),
                              icon: Icons.receipt_long,
                              color: colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: AppSpacing.xl),
                      
                      // Tender totals section
                      Text(
                        'Tender Totals',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      
                      if (_tenderTotals.isEmpty)
                        Container(
                          padding: AppSpacing.paddingXl,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Center(
                            child: Text(
                              'No transactions found for the selected date range',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ..._buildTenderTiles(theme, colorScheme),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  List<Widget> _buildTenderTiles(ThemeData theme, ColorScheme colorScheme) {
    final sortedTenders = _tenderTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final tiles = <Widget>[];

    for (final entry in sortedTenders) {
      final tenderType = entry.key;
      final amount = entry.value;
      
      tiles.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _TenderTile(
            tenderType: tenderType,
            amount: amount,
            icon: _getTenderIcon(tenderType),
            color: _getTenderColor(tenderType, colorScheme),
          ),
        ),
      );

      // Add Net Cash calculation after Cash tender
      if (tenderType.toLowerCase() == 'cash' && _tillAdjustmentTotal != 0.0) {
        final netCash = amount + _tillAdjustmentTotal;
        tiles.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _tillAdjustmentTotal < 0
                              ? Colors.red.withValues(alpha: 0.15)
                              : Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: _tillAdjustmentTotal < 0 ? Colors.red : Colors.green,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Till Adjustments',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              _tillAdjustmentTotal < 0 ? 'Cash Removed' : 'Cash Added',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '£${_tillAdjustmentTotal.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: _tillAdjustmentTotal < 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.lg),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(Icons.calculate, color: Colors.blue, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Net Cash in Till',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '£${netCash.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return tiles;
  }

  IconData _getTenderIcon(String tenderType) {
    switch (tenderType.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'refund':
        return Icons.assignment_return;
      case 'discount':
        return Icons.discount;
      case 'voucher':
        return Icons.card_giftcard;
      case 'loyalty':
        return Icons.loyalty;
      default:
        return Icons.payment;
    }
  }

  Color _getTenderColor(String tenderType, ColorScheme colorScheme) {
    switch (tenderType.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.blue;
      case 'refund':
        return colorScheme.error;
      case 'discount':
        return Colors.orange;
      case 'voucher':
        return Colors.purple;
      case 'loyalty':
        return Colors.amber;
      default:
        return colorScheme.primary;
    }
  }
}

enum DateFilter {
  today,
  thisWeek,
  thisMonth,
  custom,
}

/// Filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

/// Summary card widget
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tender tile widget
class _TenderTile extends StatelessWidget {
  final String tenderType;
  final double amount;
  final IconData icon;
  final Color color;

  const _TenderTile({
    required this.tenderType,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenderType.toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  tenderType == 'refund' ? 'Total refunded' : 'Total collected',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '£${amount.toStringAsFixed(2)}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
