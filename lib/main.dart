import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flowtill/theme.dart';
import 'package:flowtill/services/local_storage_service.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/services/sync_service.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/providers/catalog_provider.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/providers/order_history_provider.dart';
import 'package:flowtill/providers/staff_provider.dart';
import 'package:flowtill/providers/navigation_provider.dart';
import 'package:flowtill/providers/login_provider.dart';
import 'package:flowtill/providers/table_layout_provider.dart';
import 'package:flowtill/providers/printer_provider.dart';
import 'package:flowtill/providers/trading_day_provider.dart';
import 'package:flowtill/services/outlet_settings_service.dart';
import 'package:flowtill/screens/till_screen.dart';
import 'package:flowtill/screens/staff_login_screen.dart';
import 'package:flowtill/screens/payment_screen.dart';
import 'package:flowtill/screens/receipt_screen.dart';
import 'package:flowtill/screens/settings_screen.dart';
import 'package:flowtill/screens/table_layout_screen.dart';
import 'package:flowtill/screens/order_history_screen.dart';
import 'package:flowtill/screens/reporting_screen.dart';
import 'package:flowtill/screens/adjustments_screen.dart';
import 'package:flowtill/screens/stock_adjustments_screen.dart';
import 'package:flowtill/screens/split_bill_screen.dart';
import 'package:flowtill/screens/end_of_day_screen.dart';
import 'package:flowtill/screens/splash_screen.dart';
import 'package:flowtill/screens/sub_categories_screen.dart';
import 'package:flowtill/widgets/navigation/app_shell.dart';
import 'package:flowtill/widgets/trading/start_of_day_modal.dart';

/// Main entry point for FlowTill EPOS application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure fullscreen kiosk mode for desktop platforms only
  // Use OS-level detection to prevent Android/iOS from calling desktop-only APIs
  final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  
  if (isDesktop) {
    await _configureDesktopWindow();
  }
  
  // Hide system UI (bottom navigation bar) on Android for fullscreen kiosk mode
  if (!kIsWeb && Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [], // Hide all system overlays (status bar + navigation bar)
    );
  }
  
  await LocalStorageService().init();
  await SupabaseConfig.initialize();
  
  // Initialize offline mode services (lazy loading - sync happens when outlet is selected)
  await ConnectionService().initialize();
  await SyncService().initialize();
  debugPrint('🔄 Offline mode initialized (lazy sync enabled)');
  
  runApp(const MyApp());
}

/// Configures window settings for desktop platforms (Windows, macOS, Linux)
Future<void> _configureDesktopWindow() async {
  await windowManager.ensureInitialized();
  
  const windowOptions = WindowOptions(
    size: Size.zero, // Will be overridden by fullscreen
    center: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Hide title bar for fullscreen
    fullScreen: true, // Launch in fullscreen
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setFullScreen(true);
    // Prevent accidental exits - users must use in-app logout
    await windowManager.setPreventClose(false); // Allow close but could be set to true for strict kiosk
  });
}

// Global flag to track if splash screen has been shown in current session
bool splashShown = false;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => OutletProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => OrderHistoryProvider()),
        ChangeNotifierProvider(create: (_) => StaffProvider()),
        ChangeNotifierProvider(create: (_) => LoginProvider()),
        ChangeNotifierProvider(create: (_) => TableLayoutProvider()),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
        ChangeNotifierProvider(create: (_) => TradingDayProvider()),
      ],
      child: Builder(
        builder: (context) {
          // Wire up OrderProvider logging callback to OrderHistoryProvider
          final orderProvider = context.read<OrderProvider>();
          final historyProvider = context.read<OrderHistoryProvider>();
          final outletProvider = context.read<OutletProvider>();
          final staffProvider = context.read<StaffProvider>();
          
          orderProvider.onLogAction = ({
            required String actionType,
            required String actionDescription,
            Map<String, dynamic>? meta,
          }) async {
            final order = orderProvider.currentOrder;
            if (order != null) {
              // Add staff name to meta for display in history
              final enrichedMeta = Map<String, dynamic>.from(meta ?? {});
              if (staffProvider.currentStaff != null) {
                enrichedMeta['staff_name'] = staffProvider.currentStaff!.fullName;
              }
              
              await historyProvider.logOrderAction(
                outletId: outletProvider.currentOutlet?.id ?? '',
                orderId: order.id,
                tableId: order.tableId,
                staffId: staffProvider.currentStaff?.id,
                actionType: actionType,
                actionDescription: actionDescription,
                meta: enrichedMeta,
              );
            }
          };
          
          return MaterialApp.router(
            title: 'FlowTill - EPOS System',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: ThemeMode.system,
            routerConfig: _createRouter(),
          );
        },
      ),
    );
  }

  GoRouter _createRouter() => GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final staffProvider = Provider.of<StaffProvider>(context, listen: false);
      final isLoggedIn = staffProvider.isLoggedIn;
      final isSplashRoute = state.matchedLocation == '/';
      final isLoginRoute = state.matchedLocation == '/login';

      debugPrint('🔀 Router redirect: location=${state.matchedLocation}, isLoggedIn=$isLoggedIn, splashShown=$splashShown');

      // Always show splash screen on first app launch
      if (!splashShown && !isSplashRoute) {
        debugPrint('🔀 Router: Splash not shown yet, redirecting to splash');
        return '/';
      }

      // Allow splash screen to load
      if (isSplashRoute) {
        debugPrint('🔀 Router: Allowing splash screen to load');
        return null;
      }

      // If not logged in and not on login/splash page, redirect to login
      if (!isLoggedIn && !isLoginRoute) {
        debugPrint('🔀 Router: Not logged in, redirecting to /login');
        return '/login';
      }

      // If logged in and on login page, redirect to till
      if (isLoggedIn && isLoginRoute) {
        debugPrint('🔀 Router: Logged in, redirecting to /till');
        return '/till';
      }

      debugPrint('🔀 Router: No redirect needed');
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => NoTransitionPage(
          child: StaffLoginScreen(
            onLoginSuccess: () => context.go('/till'),
          ),
        ),
      ),
      GoRoute(
        path: '/till',
        name: 'till',
        pageBuilder: (context, state) => NoTransitionPage(
          child: AppShellPage(
            child: const TillScreen(),
            onNavigationItemSelected: (item) => _handleNavigation(context, item),
          ),
        ),
      ),
      GoRoute(
        path: '/order-history',
        name: 'orderHistory',
        pageBuilder: (context, state) => NoTransitionPage(
          child: AppShellPage(
            child: const OrderHistoryScreen(),
            onNavigationItemSelected: (item) => _handleNavigation(context, item),
          ),
        ),
      ),
      GoRoute(
        path: '/reporting',
        name: 'reporting',
        pageBuilder: (context, state) => NoTransitionPage(
          child: AppShellPage(
            child: const ReportingScreen(),
            onNavigationItemSelected: (item) => _handleNavigation(context, item),
          ),
        ),
      ),
      GoRoute(
        path: '/adjustments',
        name: 'adjustments',
        pageBuilder: (context, state) => NoTransitionPage(
          child: AppShellPage(
            child: const AdjustmentsScreen(),
            onNavigationItemSelected: (item) => _handleNavigation(context, item),
          ),
        ),
      ),
      GoRoute(
        path: '/stock-adjustments',
        name: 'stockAdjustments',
        pageBuilder: (context, state) => NoTransitionPage(
          child: AppShellPage(
            child: const StockAdjustmentsScreen(),
            onNavigationItemSelected: (item) => _handleNavigation(context, item),
          ),
        ),
      ),
      GoRoute(
        path: '/end-of-day',
        name: 'endOfDay',
        pageBuilder: (context, state) => NoTransitionPage(
          child: AppShellPage(
            child: const EndOfDayScreen(),
            onNavigationItemSelected: (item) => _handleNavigation(context, item),
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => NoTransitionPage(
          child: AppShellPage(
            child: const SettingsScreen(),
            onNavigationItemSelected: (item) => _handleNavigation(context, item),
          ),
        ),
      ),
      GoRoute(
        path: '/settings/tables',
        name: 'tableLayout',
        pageBuilder: (context, state) => NoTransitionPage(
          child: AppShellPage(
            child: const TableLayoutScreen(),
            onNavigationItemSelected: (item) => _handleNavigation(context, item),
          ),
        ),
      ),
      GoRoute(
        path: '/payment',
        name: 'payment',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const PaymentScreen(),
        ),
      ),
      GoRoute(
        path: '/split-bill',
        name: 'splitBill',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const SplitBillScreen(),
        ),
      ),
      GoRoute(
        path: '/receipt',
        name: 'receipt',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const ReceiptScreen(),
        ),
      ),
      GoRoute(
        path: '/sub-categories/:categoryId',
        name: 'subCategories',
        pageBuilder: (context, state) {
          final categoryId = state.pathParameters['categoryId']!;
          return NoTransitionPage(
            child: SubCategoriesScreen(parentCategoryId: categoryId),
          );
        },
      ),
    ],
  );

  void _handleNavigation(BuildContext context, NavigationItem item) {
    switch (item) {
      case NavigationItem.till:
        context.go('/till');
      case NavigationItem.orderHistory:
        context.go('/order-history');
      case NavigationItem.reporting:
        context.go('/reporting');
      case NavigationItem.adjustments:
        context.go('/adjustments');
      case NavigationItem.stockAdjustments:
        context.go('/stock-adjustments');
      case NavigationItem.endOfDay:
        context.go('/end-of-day');
      case NavigationItem.tableLayout:
        context.go('/settings/tables');
      case NavigationItem.settings:
        context.go('/settings');
    }
  }
}

/// Wrapper for pages that use the app shell
class AppShellPage extends StatefulWidget {
  final Widget child;
  final Function(NavigationItem)? onNavigationItemSelected;

  const AppShellPage({
    super.key,
    required this.child,
    this.onNavigationItemSelected,
  });

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final navProvider = context.read<NavigationProvider>();
    final outletProvider = context.read<OutletProvider>();
    final staffProvider = context.read<StaffProvider>();
    final tradingDayProvider = context.read<TradingDayProvider>();

    debugPrint('🔄 AppShellPage: Initializing data...');

    // Set current outlet from provider
    if (outletProvider.outlets.isNotEmpty) {
      navProvider.setCurrentOutlet(outletProvider.currentOutlet);
      debugPrint('   Outlet: ${outletProvider.currentOutlet?.name}');
    }

    // Set logged-in staff from provider
    if (staffProvider.currentStaff != null) {
      navProvider.setLoggedInStaff(staffProvider.currentStaff);
      debugPrint('   Staff: ${staffProvider.currentStaff?.fullName}');
    }

    // Check if we need to start a new trading day based on operating hours
    if (outletProvider.currentOutlet != null) {
      debugPrint('📅 AppShellPage: Checking trading day for outlet ${outletProvider.currentOutlet!.id}');
      
      // Load outlet settings to get operating hours
      final settingsService = OutletSettingsService();
      final settingsResult = await settingsService.getSettingsForOutlet(outletProvider.currentOutlet!.id);
      final operatingHoursOpen = settingsResult.isSuccess ? settingsResult.data?.operatingHoursOpen : null;
      
      debugPrint('   Operating Hours Open: $operatingHoursOpen');
      
      // Load current trading day first
      await tradingDayProvider.loadCurrentTradingDay(outletProvider.currentOutlet!.id);
      
      // Check if we should start a new trading day based on operating hours
      final shouldStart = await tradingDayProvider.shouldStartNewTradingDay(
        outletProvider.currentOutlet!.id,
        operatingHoursOpen,
      );
      
      debugPrint('📅 AppShellPage: Trading day check complete');
      debugPrint('   Current trading day: ${tradingDayProvider.currentTradingDay?.id}');
      debugPrint('   Is open: ${tradingDayProvider.currentTradingDay?.isOpen}');
      debugPrint('   Should start new day: $shouldStart');
      
      // Show Start of Day modal if needed
      if (shouldStart && mounted) {
        debugPrint('⚠️ AppShellPage: Need to start new trading day - showing Start of Day modal');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            debugPrint('📅 AppShellPage: Displaying Start of Day modal now');
            _showStartOfDayModal();
          } else {
            debugPrint('⚠️ AppShellPage: Widget not mounted, cannot show modal');
          }
        });
      } else {
        debugPrint('✅ AppShellPage: Trading day is active and valid - no modal needed');
      }
    } else {
      debugPrint('⚠️ AppShellPage: No outlet selected');
    }
  }

  void _showStartOfDayModal() {
    final outletProvider = context.read<OutletProvider>();
    if (outletProvider.currentOutlet == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StartOfDayModal(
        outletId: outletProvider.currentOutlet!.id,
        canCancel: false, // Force staff to start the day
        onStarted: () {
          // Modal will close itself, nothing more needed
          debugPrint('✅ Trading day started via modal');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      onNavigationItemSelected: widget.onNavigationItemSelected,
      onLogout: () {
        final staffProvider = context.read<StaffProvider>();
        final orderProvider = context.read<OrderProvider>();
        staffProvider.logout(
          onParkOrder: (staffId) => orderProvider.parkOrderForStaff(staffId),
        );
        context.go('/login');
      },
      child: widget.child,
    );
  }
}

/// Placeholder screen for pages not yet implemented
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This page is under construction',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
