import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/models/epos_order.dart';
import 'package:flowtill/models/table_session.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/providers/staff_provider.dart';
import 'package:flowtill/services/order_repository_hybrid.dart';
import 'package:flowtill/services/table_lock_service.dart';
import 'package:flowtill/widgets/till/table_lock_warning.dart';
import 'package:flowtill/theme.dart';

class TabsTablesScreen extends StatefulWidget {
  const TabsTablesScreen({super.key});

  @override
  State<TabsTablesScreen> createState() => _TabsTablesScreenState();
}

class _TabsTablesScreenState extends State<TabsTablesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _orderRepository = OrderRepositoryHybrid();
  final _tableLockService = TableLockService();
  List<EposOrder> _tables = [];
  List<EposOrder> _tabs = [];
  bool _isLoading = true;
  Map<String, List<TableSession>> _sessionsByOrderId = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOpenOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOpenOrders() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);

    final outlet = context.read<OutletProvider>().currentOutlet;
    final currentStaff = context.read<StaffProvider>().currentStaff;
    
    if (outlet == null || currentStaff == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    // Device builds: include offline-first pending orders
    // Web builds: online-only
    final includeOffline = !kIsWeb;
    
    final tables = await _orderRepository.getOpenTables(outlet.id, includeOffline: includeOffline);
    final tabs = await _orderRepository.getOpenTabs(outlet.id, includeOffline: includeOffline);

    // Load active sessions for each order
    final sessionsByOrderId = <String, List<TableSession>>{};
    for (final order in [...tables, ...tabs]) {
      final sessions = await _tableLockService.getOtherActiveSessions(
        order.id,
        currentStaff.id,
      );
      if (sessions.isNotEmpty) {
        sessionsByOrderId[order.id] = sessions;
      }
    }

    if (mounted) {
      setState(() {
        _tables = tables;
        _tabs = tabs;
        _sessionsByOrderId = sessionsByOrderId;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: const Text('Tabs & Tables'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOpenOrders,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.table_restaurant),
              text: 'Tables (${_tables.length})',
            ),
            Tab(
              icon: const Icon(Icons.receipt_long),
              text: 'Tabs (${_tabs.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _TablesView(
                  orders: _tables,
                  sessionsByOrderId: _sessionsByOrderId,
                  onTap: _resumeOrder,
                ),
                _TabsView(
                  orders: _tabs,
                  sessionsByOrderId: _sessionsByOrderId,
                  onTap: _resumeOrder,
                ),
              ],
            ),
    );
  }

  Future<void> _resumeOrder(EposOrder order) async {
    final outlet = context.read<OutletProvider>().currentOutlet;
    final currentStaff = context.read<StaffProvider>().currentStaff;
    
    if (outlet == null || currentStaff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No outlet or staff selected')),
      );
      return;
    }

    // Check for active sessions
    final otherSessions = await _tableLockService.getOtherActiveSessions(
      order.id,
      currentStaff.id,
    );

    if (!mounted) return;

    if (otherSessions.isNotEmpty) {
      // Show warning dialog
      _showTableLockWarning(order, otherSessions, outlet.id, currentStaff.id, currentStaff.fullName);
    } else {
      // No other sessions, proceed normally
      await _openOrder(order, outlet.id, currentStaff.id, currentStaff.fullName);
    }
  }

  void _showTableLockWarning(
    EposOrder order,
    List<TableSession> otherSessions,
    String outletId,
    String staffId,
    String staffName,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TableLockedDialog(
        otherSessions: otherSessions,
        onLogout: () => _handleLogout(),
      ),
    );
  }

  void _handleLogout() {
    final staffProvider = context.read<StaffProvider>();
    
    // Logout and navigate to login
    staffProvider.logout();
    context.go('/login');
  }

  Future<void> _openOrder(
    EposOrder order,
    String outletId,
    String staffId,
    String staffName,
  ) async {
    debugPrint('📱 TabsTablesScreen: Opening order ${order.id}');
    
    if (!mounted) return;
    
    // Load the order into OrderProvider
    final orderProvider = context.read<OrderProvider>();
    await orderProvider.resumeOrderFromSupabase(
      order.id,
      staffId: staffId,
      staffName: staffName,
    );
    
    if (!mounted) return;
    
    // Verify order was loaded
    if (orderProvider.currentOrder?.id != order.id) {
      debugPrint('❌ TabsTablesScreen: Failed to load order ${order.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open this order. Please check connection.'),
        ),
      );
      return;
    }
    
    debugPrint('✅ TabsTablesScreen: Order loaded successfully');
    
    // Navigate to till
    context.go('/');
  }
}

class _TablesView extends StatelessWidget {
  final List<EposOrder> orders;
  final Map<String, List<TableSession>> sessionsByOrderId;
  final Function(EposOrder) onTap;

  const _TablesView({
    required this.orders,
    required this.sessionsByOrderId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_restaurant, size: 64, color: Colors.grey),
            SizedBox(height: AppSpacing.md),
            Text(
              'No open tables',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: AppSpacing.paddingLg,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.0,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final sessions = sessionsByOrderId[order.id] ?? [];
        return _TableCard(
          order: order,
          otherSessions: sessions,
          onTap: () => onTap(order),
        );
      },
    );
  }
}

class _TabsView extends StatelessWidget {
  final List<EposOrder> orders;
  final Map<String, List<TableSession>> sessionsByOrderId;
  final Function(EposOrder) onTap;

  const _TabsView({
    required this.orders,
    required this.sessionsByOrderId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: AppSpacing.md),
            Text(
              'No open tabs',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: AppSpacing.paddingLg,
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final sessions = sessionsByOrderId[order.id] ?? [];
        return _TabCard(
          order: order,
          otherSessions: sessions,
          onTap: () => onTap(order),
        );
      },
    );
  }
}

class _TableCard extends StatelessWidget {
  final EposOrder order;
  final List<TableSession> otherSessions;
  final VoidCallback onTap;

  const _TableCard({
    required this.order,
    required this.otherSessions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isParked = order.status == 'parked';

    return Material(
      color: isParked ? colorScheme.surfaceContainerHigh : colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          children: [
            Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Icon(
                isParked ? Icons.pause_circle : Icons.table_restaurant,
                size: 48,
                color: isParked ? Colors.orange : colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                order.tableNumber ?? 'Table',
                style: theme.textTheme.titleLarge?.bold,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '£${order.totalDue.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.semiBold.copyWith(
                  color: colorScheme.primary,
                ),
              ),
              if (order.covers != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${order.covers} covers',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (isParked) ...[
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    'PARKED',
                    style: theme.textTheme.labelSmall?.bold.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
            // Badge showing other active users
            if (otherSessions.isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.error,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_alt_rounded,
                        size: 12,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${otherSessions.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

class _TabCard extends StatelessWidget {
  final EposOrder order;
  final List<TableSession> otherSessions;
  final VoidCallback onTap;

  const _TabCard({
    required this.order,
    required this.otherSessions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isParked = order.status == 'parked';

    return Card(
      margin: AppSpacing.verticalSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Row(
            children: [
              Icon(
                isParked ? Icons.pause_circle : Icons.receipt_long,
                size: 40,
                color: isParked ? Colors.orange : colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.tabName ?? order.customerName ?? 'Tab',
                      style: theme.textTheme.titleMedium?.bold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (order.customerName != null && order.tabName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        order.customerName!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Opened: ${_formatTime(order.openedAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isParked) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              'PARKED',
                              style: theme.textTheme.labelSmall?.bold.copyWith(
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (otherSessions.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.error,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_alt_rounded,
                            size: 12,
                            color: colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${otherSessions.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    '£${order.totalDue.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.bold.copyWith(
                      color: colorScheme.primary,
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

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
