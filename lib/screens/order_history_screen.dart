import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/models/order_with_meta.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/services/order_repository.dart';
import 'package:flowtill/screens/order_detail_screen.dart';
import 'package:flowtill/theme.dart';
import 'package:intl/intl.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final OrderRepository _orderRepository = OrderRepository();
  final TextEditingController _searchController = TextEditingController();
  
  List<OrderWithMeta> _allOrders = [];
  List<OrderWithMeta> _filteredOrders = [];
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'today'; // today, yesterday, last7days

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchController.addListener(_filterOrders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    debugPrint('🔄 OrderHistoryScreen: Loading orders...');
    
    final outletProvider = context.read<OutletProvider>();
    final outletId = outletProvider.currentOutlet?.id;
    
    if (outletId == null) {
      debugPrint('❌ OrderHistoryScreen: No outlet selected');
      return;
    }

    debugPrint('📍 OrderHistoryScreen: Using outlet ID: $outletId');
    debugPrint('📅 OrderHistoryScreen: Filter: $_selectedFilter');

    setState(() => _isLoading = true);

    final (from, to) = _getDateRange();
    debugPrint('📆 OrderHistoryScreen: Date range: $from to $to');
    
    final orders = await _orderRepository.fetchOrdersForDateRange(
      outletId: outletId,
      from: from,
      to: to,
    );

    debugPrint('✅ OrderHistoryScreen: Received ${orders.length} orders');

    setState(() {
      _allOrders = orders;
      _filteredOrders = orders;
      _isLoading = false;
    });
    
    debugPrint('🎯 OrderHistoryScreen: State updated, displaying ${_filteredOrders.length} orders');
  }

  (DateTime, DateTime) _getDateRange() {
    // Use UTC to match Supabase timestamps
    final now = DateTime.now().toUtc();
    switch (_selectedFilter) {
      case 'today':
        final start = DateTime.utc(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        return (start, end);
      case 'yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        final start = DateTime.utc(yesterday.year, yesterday.month, yesterday.day);
        final end = start.add(const Duration(days: 1));
        return (start, end);
      case 'last7days':
        final start = DateTime.utc(now.year, now.month, now.day).subtract(const Duration(days: 7));
        final end = DateTime.utc(now.year, now.month, now.day).add(const Duration(days: 1));
        return (start, end);
      case 'custom':
        // Convert local date selection to UTC for querying
        final start = DateTime.utc(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        final end = start.add(const Duration(days: 1));
        return (start, end);
      default:
        return (_getDateRange());
    }
  }

  void _filterOrders() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredOrders = _allOrders);
      return;
    }

    setState(() {
      _filteredOrders = _allOrders.where((orderMeta) {
        final order = orderMeta.order;
        return order.id.toLowerCase().contains(query) ||
            (order.tableNumber?.toLowerCase().contains(query) ?? false) ||
            (order.tabName?.toLowerCase().contains(query) ?? false) ||
            (order.customerName?.toLowerCase().contains(query) ?? false) ||
            (orderMeta.staffName?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  void _selectDateFilter(String filter) {
    setState(() => _selectedFilter = filter);
    _loadOrders();
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedFilter = 'custom';
      });
      _loadOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header Bar
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, size: 28, color: colorScheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Order History',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _getFilterLabel(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filter Bar
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Quick filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Today',
                        isSelected: _selectedFilter == 'today',
                        onTap: () => _selectDateFilter('today'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _FilterChip(
                        label: 'Yesterday',
                        isSelected: _selectedFilter == 'yesterday',
                        onTap: () => _selectDateFilter('yesterday'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _FilterChip(
                        label: 'Last 7 days',
                        isSelected: _selectedFilter == 'last7days',
                        onTap: () => _selectDateFilter('last7days'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _FilterChip(
                        label: _selectedFilter == 'custom' 
                            ? DateFormat('dd MMM yyyy').format(_selectedDate)
                            : 'Pick Date',
                        isSelected: _selectedFilter == 'custom',
                        onTap: _pickCustomDate,
                        icon: Icons.calendar_today,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by order ID, table, tab, staff, customer...',
                    prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Results list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: colorScheme.primary),
                  )
                : _filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'No orders found',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: AppSpacing.paddingMd,
                        itemCount: _filteredOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final orderMeta = _filteredOrders[index];
                          return _OrderTile(
                            orderMeta: orderMeta,
                            onTap: () => _navigateToDetail(orderMeta),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _getFilterLabel() {
    switch (_selectedFilter) {
      case 'today':
        return 'Today';
      case 'yesterday':
        return 'Yesterday';
      case 'last7days':
        return 'Last 7 Days';
      case 'custom':
        return DateFormat('dd MMM yyyy').format(_selectedDate);
      default:
        return '';
    }
  }

  void _navigateToDetail(OrderWithMeta orderMeta) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: orderMeta.order.id),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OrderWithMeta orderMeta;
  final VoidCallback onTap;

  const _OrderTile({
    required this.orderMeta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final order = orderMeta.order;

    return Stack(
      children: [
        Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          elevation: 1,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                children: [
                  // Time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.completedAt != null
                            ? DateFormat('HH:mm').format(order.completedAt!)
                            : '--:--',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '#${orderMeta.shortId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Order label (Table/Tab/Customer/Quick Sale)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderMeta.orderLabel,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (orderMeta.staffName != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            orderMeta.staffName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '£${order.totalDue.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _StatusBadge(label: orderMeta.statusLabel),
                    ],
                  ),

                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Refunded stamp overlay (top-left corner)
        if (orderMeta.refundStatus.hasRefund)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: colorScheme.error,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh,
                    size: 12,
                    color: colorScheme.onError,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    orderMeta.refundStatus.isFullyRefunded ? 'REFUNDED' : 'PARTIAL',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onError,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
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
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
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
