import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/models/outlet_table.dart';
import 'package:flowtill/models/epos_order.dart';
import 'package:flowtill/models/table_session.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/providers/staff_provider.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/services/outlet_table_repository.dart';
import 'package:flowtill/services/order_repository_hybrid.dart';
import 'package:flowtill/services/table_lock_service.dart';
import 'package:flowtill/widgets/till/table_card.dart';
import 'package:flowtill/widgets/till/table_lock_warning.dart';
import 'package:flowtill/theme.dart';

enum TableViewMode { list, layout }

class TablesView extends StatefulWidget {
  final VoidCallback onTableSelected;

  const TablesView({
    super.key,
    required this.onTableSelected,
  });

  @override
  State<TablesView> createState() => _TablesViewState();
}

class _TablesViewState extends State<TablesView> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Preserve state even when parent rebuilds
  static const _logPrefix = '[TablesView]';
  final _tableRepository = OutletTableRepository();
  final _orderRepository = OrderRepositoryHybrid();
  final _tableLockService = TableLockService();
  final ConnectionService _connectionService = ConnectionService();
  StreamSubscription<bool>? _connectionSubscription;
  
  List<String> _rooms = [];
  Map<String, List<OutletTable>> _tablesByRoom = {};
  Map<String, EposOrder> _openOrdersByTable = {};
  Map<String, List<TableSession>> _sessionsByOrderId = {};
  bool _isOffline = false;
  
  TabController? _tabController;
  bool _isLoading = true;
  bool _isProcessingTable = false;
  bool _isRefreshing = false;
  String? _selectedRoom;
  int _lastTabIndex = 0; // Preserve tab position across rebuilds

  @override
  void initState() {
    super.initState();
    _isOffline = !_connectionService.isOnline;
    _connectionSubscription = _connectionService.connectionStream.listen((isOnline) {
      if (!mounted) return;
      setState(() => _isOffline = !isOnline);
    });
    // Defer loading until after the frame is built to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadTables();
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTables() async {
    if (!mounted) return;

    final outletId = context.read<OutletProvider>().currentOutlet?.id;
    if (outletId == null) {
      debugPrint('$_logPrefix Skipping table load: no outlet selected');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    debugPrint('$_logPrefix 🔄 Loading tables for outlet $outletId (current tab index: $_lastTabIndex)');
    debugPrint('$_logPrefix 📍 Stack trace: ${StackTrace.current}');

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // Load rooms and tables first so UI can render quickly
      final rooms = await _tableRepository.getRoomsForOutlet(outletId);
      final tablesByRoom = await _tableRepository.getTablesGroupedByRoom(outletId);

      final totalTables = tablesByRoom.values.fold<int>(0, (sum, tables) => sum + tables.length);
      debugPrint('$_logPrefix Rooms loaded: ${rooms.length}, tables loaded: $totalTables');

      if (mounted) {
        setState(() {
          _rooms = rooms;
          _tablesByRoom = tablesByRoom;
          _isLoading = false;

          _tabController?.dispose();
          _tabController = _rooms.isNotEmpty
              ? TabController(
                  length: _rooms.length,
                  vsync: this,
                  initialIndex: _lastTabIndex.clamp(0, _rooms.length - 1), // Restore previous tab
                )
              : null;

          if (_tabController != null) {
            final restoredIndex = _tabController!.index;
            _selectedRoom = _rooms[restoredIndex];
            debugPrint('$_logPrefix TabController initialized at index $restoredIndex (room: $_selectedRoom)');
            
            _tabController!.addListener(() {
              if (!_tabController!.indexIsChanging && mounted) {
                final newIndex = _tabController!.index;
                debugPrint('$_logPrefix Tab changed to index $newIndex (room: ${_rooms[newIndex]})');
                setState(() {
                  _selectedRoom = _rooms[newIndex];
                  _lastTabIndex = newIndex; // Save current tab index
                });
              }
            });
          }
        });
      }

      await _refreshOpenOrders(outletId);
      await _refreshTableSessions(outletId);
    } catch (e) {
      debugPrint('❌ Error loading tables: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshOpenOrders(String outletId) async {
    if (_isOffline) {
      debugPrint('$_logPrefix Skipping open orders refresh: offline freeze');
      return;
    }

    final startedAt = DateTime.now();
    debugPrint('$_logPrefix Refreshing open orders for outlet $outletId (platform: ${kIsWeb ? "web" : "device"})');

    // Device builds: include offline-first pending orders
    // Web builds: online-only
    final includeOffline = !kIsWeb;

    final openOrders = await _orderRepository
        .getOpenOrdersForOutlet(outletId, includeOffline: includeOffline)
        .timeout(const Duration(seconds: 6), onTimeout: () {
      debugPrint('⌛ TablesView: open orders fetch timed out, keeping existing badges');
      return _openOrdersByTable.values.toList();
    });

    final openOrdersByTable = <String, EposOrder>{};
    for (final order in openOrders) {
      if (order.tableId != null && order.orderType == 'table') {
        openOrdersByTable.putIfAbsent(order.tableId!, () => order);
      }
    }

    debugPrint(
      '$_logPrefix Loaded ${openOrdersByTable.length} active table orders in ${DateTime.now().difference(startedAt).inMilliseconds}ms',
    );

    if (mounted) {
      setState(() => _openOrdersByTable = openOrdersByTable);
    }
  }

  Future<void> _refreshTableSessions(String outletId) async {
    if (_isOffline) {
      debugPrint('$_logPrefix Skipping table sessions refresh: offline');
      return;
    }

    if (!mounted) return;

    final currentStaff = context.read<StaffProvider>().currentStaff;
    if (currentStaff == null) {
      debugPrint('$_logPrefix Skipping table sessions refresh: no staff selected');
      return;
    }

    debugPrint('$_logPrefix Refreshing table sessions');

    final sessionsByOrderId = <String, List<TableSession>>{};
    
    // Check sessions for each open order
    for (final order in _openOrdersByTable.values) {
      try {
        final sessions = await _tableLockService.getOtherActiveSessions(
          order.id,
          currentStaff.id,
        );
        if (sessions.isNotEmpty) {
          sessionsByOrderId[order.id] = sessions;
          debugPrint('$_logPrefix Found ${sessions.length} active sessions for order ${order.id}');
        }
      } catch (e) {
        debugPrint('$_logPrefix Error checking sessions for order ${order.id}: $e');
      }
    }

    if (mounted) {
      setState(() => _sessionsByOrderId = sessionsByOrderId);
    }

    debugPrint('$_logPrefix Found ${sessionsByOrderId.length} orders with active sessions');
  }

  Future<void> _handleTableTap(OutletTable table) async {
    if (_isOffline) {
      debugPrint('$_logPrefix Blocked table tap while offline for table ${table.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline mode: tables are locked until connection resumes.')),
      );
      return;
    }

    final outletId = context.read<OutletProvider>().currentOutlet?.id;
    if (outletId == null) {
      debugPrint('$_logPrefix Blocked table tap: no outlet selected');
      return;
    }

    if (_isProcessingTable) {
      debugPrint('$_logPrefix Ignoring tap for table ${table.id} because another tap is processing');
      return;
    }

    final startedAt = DateTime.now();
    debugPrint(
      '$_logPrefix ▶️ Handling tap for table ${table.tableNumber} (id: ${table.id}), cachedOpenOrder: ${_openOrdersByTable.containsKey(table.id)}',
    );
    debugPrint('[TABLE_FLOW] Selected table_id=${table.id}, table_number=${table.tableNumber}');

    setState(() => _isProcessingTable = true);

    try {
      // Always re-check the latest status for this table to avoid stale state
      EposOrder? existingOrder;
      try {
        existingOrder = await _orderRepository
            .getActiveOrderForTable(
              outletId: outletId,
              tableId: table.id,
              onlineOnly: true,
            )
            .timeout(const Duration(seconds: 8), onTimeout: () {
          debugPrint('$_logPrefix ⌛ Active order fetch timed out for table ${table.id}; using cached value');
          return _openOrdersByTable[table.id];
        });
        debugPrint(
          '$_logPrefix Active order refresh for table ${table.id}: ${existingOrder?.id ?? 'none'} (status: ${existingOrder?.status})',
        );
        if (mounted) {
          setState(() {
            if (existingOrder != null) {
              _openOrdersByTable[table.id] = existingOrder!;
            } else {
              _openOrdersByTable.remove(table.id);
            }
          });
        }
      } catch (e, st) {
        debugPrint('$_logPrefix ⚠️ Failed to refresh active order for table ${table.id}: $e\n$st');
        existingOrder = _openOrdersByTable[table.id];
      }

      existingOrder ??= _openOrdersByTable[table.id];
      
      // Check mounted after async operation
      if (!mounted) {
        debugPrint('$_logPrefix Widget unmounted after active order check for table ${table.id}');
        return;
      }
      
      final staffId = context.read<StaffProvider>().currentStaff?.id;

      // Show confirmation dialog
      debugPrint(
        '$_logPrefix 💬 Showing confirmation for table ${table.id}, existingOrder: ${existingOrder?.id ?? 'none'}, staff: ${staffId ?? 'none'}, currentTab: $_lastTabIndex',
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Open Table ${table.tableNumber}?'),
          content: Text(
            existingOrder != null
                ? 'There is already an order for this table. Do you want to resume it?'
                : 'Do you want to open a new order for this table?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(existingOrder != null ? 'Resume Order' : 'Open Table'),
            ),
          ],
        ),
      );

      debugPrint('$_logPrefix 💬 Dialog closed, confirmed: $confirmed, mounted: $mounted, currentTab: $_lastTabIndex');

      if (confirmed != true) {
        debugPrint('$_logPrefix User cancelled table open for ${table.id}');
        return;
      }

      // Check mounted after dialog
      if (!mounted) {
        debugPrint('$_logPrefix Widget unmounted after confirmation dialog for table ${table.id}');
        return;
      }

      // Check for active sessions before proceeding
      if (existingOrder != null) {
        final currentStaff = context.read<StaffProvider>().currentStaff;
        if (currentStaff != null) {
          try {
            final otherSessions = await _tableLockService.getOtherActiveSessions(
              existingOrder.id,
              currentStaff.id,
            );
            
            if (otherSessions.isNotEmpty && mounted) {
              debugPrint('$_logPrefix Found ${otherSessions.length} other users on order ${existingOrder.id}');
              // Show locked dialog (no takeover)
              await _showLockedDialog(otherSessions);
              debugPrint('$_logPrefix User cancelled - table is locked');
              return;
            }
          } catch (e) {
            debugPrint('$_logPrefix Error checking sessions: $e');
          }
        }
      }

      final orderProvider = context.read<OrderProvider>();

      if (existingOrder != null) {
        // Resume existing order
        debugPrint('$_logPrefix Resuming existing order ${existingOrder.id} for table ${table.id}');
        await orderProvider.resumeOrderFromSupabase(existingOrder.id);
        
        // Check mounted after resume operation
        if (!mounted) {
          debugPrint('$_logPrefix Widget unmounted after resume for table ${table.id}');
          return;
        }
        
        final resumedId = orderProvider.currentOrder?.id;
        if (resumedId != existingOrder.id) {
          debugPrint('$_logPrefix ❌ Resume failed. Provider order id: $resumedId, expected: ${existingOrder.id}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to resume this table. Please check connection.')),
            );
          }
          return;
        }
        if (mounted) {
          setState(() => _openOrdersByTable[table.id] = existingOrder!);
        }
        debugPrint('$_logPrefix Resume successful for table ${table.id}');
        
        // Start session for this order
        final currentStaff = context.read<StaffProvider>().currentStaff;
        if (currentStaff != null) {
          await _tableLockService.startSession(
            outletId: context.read<OutletProvider>().currentOutlet!.id,
            orderId: existingOrder.id,
            tableId: table.id,
            staffId: currentStaff.id,
            staffName: currentStaff.fullName,
          );
        }
      } else {
        // Create new table order in Supabase
        debugPrint('$_logPrefix Creating new order for table ${table.id} (tableNumber: ${table.displayName}, staff: ${staffId ?? 'none'})');
        debugPrint('[TABLE_FLOW] Creating order with table_id=${table.id}, table_number=${table.tableNumber}');
        EposOrder? newOrder;
        try {
          newOrder = await _orderRepository.createOrderHeaderForTable(
            outletId: outletId,
            tableId: table.id,
            tableNumber: table.tableNumber,
            staffId: staffId,
            covers: table.capacity,
          );
        } catch (e, st) {
          debugPrint('$_logPrefix ❌ Exception creating table order for ${table.id}: $e\n$st');
        }

        // Check mounted after create operation
        if (!mounted) {
          debugPrint('$_logPrefix Widget unmounted after create for table ${table.id}');
          return;
        }

        if (newOrder == null) {
          debugPrint('$_logPrefix ❌ createOrderHeaderForTable returned null for table ${table.id}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to open table online. Please retry.')),
            );
          }
          return;
        }

        // Initialize order provider with the new table order (use Supabase order ID)
        final outlet = context.read<OutletProvider>().currentOutlet;
        orderProvider.initializeTableOrder(
          orderId: newOrder.id,
          outletId: outletId,
          tableId: table.id,
          tableNumber: table.tableNumber,
          staffId: staffId,
          autoEnableServiceCharge: outlet?.enableServiceCharge ?? false,
          outletServiceChargePercent: outlet?.serviceChargePercent ?? 0.0,
        );

        debugPrint('$_logPrefix New order initialized: ${newOrder.id} for table ${table.id}');

        if (mounted) {
          setState(() => _openOrdersByTable[table.id] = newOrder!);
        }
        
        // Start session for this new order
        final currentStaff = context.read<StaffProvider>().currentStaff;
        if (currentStaff != null) {
          await _tableLockService.startSession(
            outletId: outletId,
            orderId: newOrder.id,
            tableId: table.id,
            staffId: currentStaff.id,
            staffName: currentStaff.fullName,
          );
        }
      }

      // Switch back to Till view
      widget.onTableSelected();
    } catch (e, st) {
      debugPrint('$_logPrefix ❌ Unhandled error in table tap for ${table.id}: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong opening this table.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingTable = false);
      debugPrint('$_logPrefix ⏱️ Tap handling complete for table ${table.id} in ${DateTime.now().difference(startedAt).inMilliseconds}ms');
    }
  }

  String _getTableStatus(OutletTable table) {
    final order = _openOrdersByTable[table.id];
    if (order == null) return 'free';
    if (order.status == 'parked') return 'parked';
    return 'open';
  }

  bool _isTableLocked(OutletTable table) {
    final order = _openOrdersByTable[table.id];
    if (order == null) return false;
    final sessions = _sessionsByOrderId[order.id] ?? [];
    return sessions.isNotEmpty;
  }

  Future<void> _showLockedDialog(List<TableSession> otherSessions) async {
    if (!mounted) return;
    
    await showDialog(
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
    final orderProvider = context.read<OrderProvider>();
    
    // Park current order if any
    staffProvider.logout(onParkOrder: (staffId) {
      if (orderProvider.currentOrder != null) {
        orderProvider.parkOrder();
      }
    });
    
    // Navigate to login
    context.go('/login');
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing || _isOffline) return;
    
    final outletId = context.read<OutletProvider>().currentOutlet?.id;
    if (outletId == null) return;
    
    setState(() => _isRefreshing = true);
    
    try {
      await _refreshOpenOrders(outletId);
      await _refreshTableSessions(outletId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Table status refreshed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('$_logPrefix Error refreshing tables: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to refresh table status'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  TableViewMode _getViewMode() {
    final outlet = context.read<OutletProvider>().currentOutlet;
    final viewModeSetting = outlet?.settings?['tableViewMode'] as String?;
    return viewModeSetting == 'layout' ? TableViewMode.layout : TableViewMode.list;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // MUST call super.build when using AutomaticKeepAliveClientMixin
    debugPrint('$_logPrefix 🔨 build() called - _isLoading: $_isLoading, currentTab: $_lastTabIndex, rooms: ${_rooms.length}');
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_restaurant,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No tables configured',
              style: context.textStyles.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Add tables in Table Settings',
              style: context.textStyles.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    final viewMode = _getViewMode();

    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Column(
          children: [
            // Room tabs with refresh button
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelStyle: context.textStyles.titleMedium?.semiBold,
                      unselectedLabelStyle: context.textStyles.titleMedium,
                      labelColor: colorScheme.primary,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      indicatorColor: colorScheme.primary,
                      tabs: _rooms.map((room) => Tab(text: room)).toList(),
                    ),
                  ),
                  // Refresh button
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: IconButton(
                      onPressed: _isRefreshing || _isOffline ? null : _handleRefresh,
                      icon: _isRefreshing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            )
                          : Icon(
                              Icons.refresh,
                              color: _isOffline
                                  ? colorScheme.onSurfaceVariant.withValues(alpha: 0.3)
                                  : colorScheme.primary,
                            ),
                      tooltip: _isOffline
                          ? 'Offline - cannot refresh'
                          : 'Refresh table status',
                    ),
                  ),
                ],
              ),
            ),
            // Tables view (grid or layout)
            Expanded(
              child: AbsorbPointer(
                absorbing: _isOffline,
                child: TabBarView(
                  controller: _tabController,
                  children: _rooms.map((room) {
                    final tables = _tablesByRoom[room] ?? [];
                    
                    if (viewMode == TableViewMode.layout) {
                      return _LayoutView(
                        tables: tables,
                        openOrdersByTable: _openOrdersByTable,
                        sessionsByOrderId: _sessionsByOrderId,
                        onTableTap: _handleTableTap,
                        getTableStatus: _getTableStatus,
                      );
                    }
                    
                    // Default: List/Grid view
                    return GridView.builder(
                      padding: AppSpacing.paddingLg,
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: tables.length,
                      itemBuilder: (context, index) {
                        final table = tables[index];
                        final status = _getTableStatus(table);
                        final isLocked = _isTableLocked(table);
                        
                        return Stack(
                          children: [
                            TableCard(
                              table: table,
                              status: status,
                              onTap: () => _handleTableTap(table),
                            ),
                            // Lock indicator badge
                            if (isLocked)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.errorContainer,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.error,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.lock,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        if (_isOffline)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              color: colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, color: colorScheme.onErrorContainer),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Offline: tables are locked until connection resumes.',
                      style: context.textStyles.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
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

/// Visual layout view showing tables positioned on canvas
class _LayoutView extends StatefulWidget {
  final List<OutletTable> tables;
  final Map<String, EposOrder> openOrdersByTable;
  final Map<String, List<TableSession>> sessionsByOrderId;
  final Future<void> Function(OutletTable) onTableTap;
  final String Function(OutletTable) getTableStatus;

  const _LayoutView({
    required this.tables,
    required this.openOrdersByTable,
    required this.sessionsByOrderId,
    required this.onTableTap,
    required this.getTableStatus,
  });

  @override
  State<_LayoutView> createState() => _LayoutViewState();
}

class _LayoutViewState extends State<_LayoutView> {
  double _zoomLevel = 1.0;
  final TransformationController _transformController = TransformationController();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Zoom controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => setState(() {
                    _zoomLevel = (_zoomLevel - 0.1).clamp(0.5, 2.0);
                    _transformController.value = Matrix4.identity()..scale(_zoomLevel);
                  }),
                  icon: const Icon(Icons.zoom_out),
                  tooltip: 'Zoom Out',
                ),
                Text(
                  '${(_zoomLevel * 100).toInt()}%',
                  style: context.textStyles.bodyMedium,
                ),
                IconButton(
                  onPressed: () => setState(() {
                    _zoomLevel = (_zoomLevel + 0.1).clamp(0.5, 2.0);
                    _transformController.value = Matrix4.identity()..scale(_zoomLevel);
                  }),
                  icon: const Icon(Icons.zoom_in),
                  tooltip: 'Zoom In',
                ),
              ],
            ),
          ),
          // Canvas
          Expanded(
            child: CustomPaint(
              painter: _GridPainter(colorScheme: colorScheme),
              child: InteractiveViewer(
                transformationController: _transformController,
                boundaryMargin: const EdgeInsets.all(100),
                minScale: 0.5,
                maxScale: 2.0,
                constrained: false,
                child: SizedBox(
                  width: 2000,
                  height: 2000,
                  child: Stack(
                    children: widget.tables.map((table) {
                      final status = widget.getTableStatus(table);
                      
                      final order = widget.openOrdersByTable[table.id];
                      final isLocked = order != null && widget.sessionsByOrderId[order.id]?.isNotEmpty == true;
                      
                      return Positioned(
                        left: table.posX ?? 100,
                        top: table.posY ?? 100,
                        child: GestureDetector(
                          onTap: () => widget.onTableTap(table),
                          child: Stack(
                            children: [
                              _TableLayoutCard(
                                table: table,
                                status: status,
                              ),
                              // Lock indicator badge
                              if (isLocked)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.errorContainer,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.error,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.lock,
                                      size: 12,
                                      color: Theme.of(context).colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }
}

/// Grid painter for canvas background
class _GridPainter extends CustomPainter {
  final ColorScheme colorScheme;

  _GridPainter({required this.colorScheme});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    const gridSize = 50.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Table card for layout view (read-only, no dragging)
class _TableLayoutCard extends StatelessWidget {
  final OutletTable table;
  final String status;

  const _TableLayoutCard({
    required this.table,
    required this.status,
  });

  (double, double) _getTableSize() {
    final capacity = table.capacity ?? 4;
    if (capacity == 2) return (100, 100); // Square
    if (capacity >= 3 && capacity <= 4) return (140, 80); // Rectangle
    return (160, 90); // Larger rectangle
  }

  Color _getStatusColor(BuildContext context) {
    switch (status) {
      case 'open':
        return Colors.red;
      case 'parked':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (width, height) = _getTableSize();
    final statusColor = _getStatusColor(context);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: statusColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Table name or number (large and bold)
            Flexible(
              child: Text(
                table.displayName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            // Capacity indicator
            if (table.capacity != null) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person,
                    size: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    table.capacity.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
            // Status badge (smaller, below capacity)
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                status.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
