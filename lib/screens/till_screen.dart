import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/providers/catalog_provider.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/providers/staff_provider.dart';
import 'package:flowtill/services/printer/printer_service.dart';
import 'package:flowtill/services/modifier_service.dart';
import 'package:flowtill/services/local_storage_service.dart';
import 'package:flowtill/widgets/till/top_app_bar.dart';
import 'package:flowtill/widgets/till/product_grid_panel.dart';
import 'package:flowtill/widgets/till/order_panel.dart';
import 'package:flowtill/widgets/till/bottom_action_bar.dart';
import 'package:flowtill/widgets/till/tables_view.dart';
import 'package:flowtill/widgets/till/sync_status_indicator.dart';
import 'package:flowtill/theme.dart';

class TillScreen extends StatefulWidget {
  const TillScreen({super.key});

  @override
  State<TillScreen> createState() => _TillScreenState();
}

class _TillScreenState extends State<TillScreen> {
  bool _showTables = false;
  final _tablesViewKey = const ValueKey('tables_view'); // Stable key instead of UniqueKey
  final _modifierService = ModifierService();
  final _localStorageService = LocalStorageService();
  bool _hideTopAppBar = false;
  bool _isOrderPanelExpanded = false;
  String? _lastLayoutLog;
  final _orderPanelKey = GlobalKey();
  double _collapsedOrderPanelHeight = 110.0; // Default fallback

  // Auto-logout timer state
  Timer? _autoLogoutTimer;
  int _autoLogoutCountdown = 3;
  bool _showAutoLogout = false;
  String? _previousRoute;

  @override
  void initState() {
    super.initState();
    _loadDisplaySettings();
    _initializeData();
    _measureOrderPanelHeight();
  }

  void _loadDisplaySettings() {
    setState(() {
      _hideTopAppBar = _localStorageService.getHideTopAppBar();
    });
    debugPrint('📺 TillScreen: Hide top app bar: $_hideTopAppBar');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Detect if returning from payment screen using GoRouter location
    final router = GoRouter.of(context);
    final currentLocation =
        router.routerDelegate.currentConfiguration.uri.toString();

    // Start auto-logout if we just returned from payment screen
    if (_previousRoute == '/payment' && currentLocation == '/till') {
      _startAutoLogoutTimer();
    }
    _previousRoute = currentLocation;

    // Note: No need to recreate TablesView key - AutomaticKeepAliveClientMixin handles state preservation
  }

  @override
  void dispose() {
    _cancelAutoLogoutTimer();
    super.dispose();
  }

  void _startAutoLogoutTimer() {
    _cancelAutoLogoutTimer(); // Cancel any existing timer
    setState(() {
      _autoLogoutCountdown = 3;
      _showAutoLogout = true;
    });

    _autoLogoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_autoLogoutCountdown > 1) {
        setState(() => _autoLogoutCountdown--);
      } else {
        _cancelAutoLogoutTimer();
        _performLogout();
      }
    });
  }

  void _resetAutoLogoutTimer() {
    if (_showAutoLogout) {
      _cancelAutoLogoutTimer();
      setState(() => _showAutoLogout = false);
    }
  }

  void _cancelAutoLogoutTimer() {
    _autoLogoutTimer?.cancel();
    _autoLogoutTimer = null;
  }

  void _performLogout() {
    final staffProvider = context.read<StaffProvider>();
    staffProvider.logout();
    context.go('/staff-login');
  }

  void _measureOrderPanelHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox = _orderPanelKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final height = renderBox.size.height;
        if ((_collapsedOrderPanelHeight - height).abs() > 1.0) {
          setState(() => _collapsedOrderPanelHeight = height);
          debugPrint('📏 Measured collapsed OrderPanel height: $height');
        }
      }
    });
  }

  Future<void> _initializeData() async {
    final outletProvider = context.read<OutletProvider>();
    final catalogProvider = context.read<CatalogProvider>();
    final orderProvider = context.read<OrderProvider>();
    final staffProvider = context.read<StaffProvider>();
    final printerService = PrinterService.instance;

    // Outlets are already loaded in login screen
    final currentOutlet = outletProvider.currentOutlet;
    if (currentOutlet == null) {
      debugPrint('⚠️ TillScreen: No outlet selected');
      return;
    }

    debugPrint('🏪 TillScreen: Initializing for outlet: ${currentOutlet.name}');
    debugPrint('🔧 TillScreen: Loading modifiers for outlet: ${currentOutlet.id}');

    // ⚡ Catalog is already preloaded from login screen!
    // Only load staff, printers, promotions, and modifiers here
    await Future.wait([
      staffProvider.loadStaffForOutlet(currentOutlet.id),
      printerService.loadPrinters(currentOutlet.id),
      orderProvider.loadPromotions(currentOutlet.id),
      _modifierService.loadModifiersForOutlet(currentOutlet.id),
    ]);

    // Check if modifiers loaded successfully
    debugPrint('✅ TillScreen: Modifiers loaded, checking test product...');
    final testProductId = 'd6f42c99-16c8-4010-9b22-7c897265d2d3';
    final hasModifiers = _modifierService.hasModifiers(testProductId);
    debugPrint('🔧 TillScreen: Test product ($testProductId) has modifiers: $hasModifiers');
    if (hasModifiers) {
      final links = _modifierService.getLinksForProduct(testProductId);
      debugPrint('🔧 TillScreen: Found ${links.length} modifier links');
    }

    // Set product catalog for promotion calculation
    orderProvider.setProductCatalog(catalogProvider.products);
    
    // Set packaged deal service for deal detection
    orderProvider.setPackagedDealService(catalogProvider.packagedDealService);

    // Initialize order with service charge settings from outlet
    orderProvider.initializeOrder(
      currentOutlet.id,
      staffProvider.currentStaff?.id,
      autoEnableServiceCharge: currentOutlet.enableServiceCharge,
      outletServiceChargePercent: currentOutlet.serviceChargePercent,
    );

    debugPrint('✅ TillScreen: Initialization complete');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _resetAutoLogoutTimer(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                // Auto-logout countdown banner
                if (_showAutoLogout)
                  Container(
                    width: double.infinity,
                    padding: AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Logging out in $_autoLogoutCountdown seconds...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(Tap anywhere to cancel)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Top App Bar (conditionally shown based on device setting)
                if (!_hideTopAppBar)
                  TopAppBar(modifierService: _modifierService),

                // Compact status bar when top app bar is hidden
                if (_hideTopAppBar)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SyncStatusIndicator(showLogoutButton: true),
                      ],
                    ),
                  ),
                // Till / Tables Toggle
                Container(
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Till'),
                            icon: Icon(Icons.grid_view),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Tables'),
                            icon: Icon(Icons.table_restaurant),
                          ),
                        ],
                        selected: {_showTables},
                        onSelectionChanged: (Set<bool> selection) {
                          setState(() {
                            _showTables = selection.first;
                            _isOrderPanelExpanded = _showTables ? false : _isOrderPanelExpanded;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      final isTablet = constraints.maxWidth >= 600 &&
                          constraints.maxWidth < 1200;

                      final layoutClass = isMobile
                          ? 'mobile'
                          : isTablet
                              ? 'tablet'
                              : 'desktop';
                      final content = _showTables ? 'tables' : 'products';
                      final layoutSignature =
                          '$layoutClass|$content|${constraints.maxWidth.round()}x${constraints.maxHeight.round()}';

                      if (_lastLayoutLog != layoutSignature) {
                        _lastLayoutLog = layoutSignature;
                        debugPrint(
                          '🖥️ Till layout: $layoutClass ($content) '
                          '${constraints.maxWidth.toStringAsFixed(0)}x${constraints.maxHeight.toStringAsFixed(0)}',
                        );
                      }

                      // Main content based on toggle
                      final mainContent = _showTables
                          ? TablesView(
                              key: _tablesViewKey,
                              onTableSelected: () {
                                setState(() => _showTables = false);
                              },
                            )
                          : ProductGridPanel(
                              modifierService: _modifierService,
                              mobileBottomPadding: _collapsedOrderPanelHeight,
                            );

                      if (isMobile) {
                        if (_showTables) {
                          // Give tables full touch access on mobile; hide the order panel overlay
                          return mainContent;
                        }

                        final panelSpace = constraints.maxHeight;
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring: _isOrderPanelExpanded,
                                child: mainContent,
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: OrderPanel(
                                key: _orderPanelKey,
                                modifierService: _modifierService,
                                mobileExpandedListHeight: panelSpace,
                                onExpandedChanged: (expanded) {
                                  if (_isOrderPanelExpanded != expanded) {
                                    setState(() => _isOrderPanelExpanded = expanded);
                                    if (!expanded) {
                                      _measureOrderPanelHeight();
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      }

                      final leftFlex = isTablet ? 5 : 6;
                      final rightFlex = isTablet ? 5 : 4;

                      // On Android tablets: hide order panel when viewing tables
                      final isAndroid =
                          Theme.of(context).platform == TargetPlatform.android;
                      final hideOrderPanel = isAndroid && _showTables;

                      return Row(
                        children: [
                          Expanded(
                            flex: hideOrderPanel ? 1 : leftFlex,
                            child: mainContent,
                          ),
                          if (!hideOrderPanel)
                            Expanded(
                              flex: rightFlex,
                              child:
                                  OrderPanel(modifierService: _modifierService),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const BottomActionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
