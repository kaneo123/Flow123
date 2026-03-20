import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/models/outlet.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/providers/catalog_provider.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/providers/staff_provider.dart';
import 'package:flowtill/providers/trading_day_provider.dart';
import 'package:flowtill/services/printer/printer_service.dart';
import 'package:flowtill/services/modifier_service.dart';
import 'package:flowtill/widgets/shared/outlet_sync_progress_dialog.dart';
import 'package:flowtill/theme.dart';

class OutletSelector extends StatelessWidget {
  const OutletSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OutletProvider>(
      builder: (context, outletProvider, _) {
        final currentOutlet = outletProvider.currentOutlet;
        final outlets = outletProvider.outlets;

        if (currentOutlet == null) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: AppSpacing.horizontalMd,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentOutlet.id,
              icon: Icon(Icons.store, color: Theme.of(context).colorScheme.primary),
              isExpanded: true,
              style: context.textStyles.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              items: outlets.map((outlet) => DropdownMenuItem(
                value: outlet.id,
                child: Text(
                  outlet.name,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              )).toList(),
              onChanged: (String? newOutletId) {
                if (newOutletId != null) {
                  final newOutlet = outlets.firstWhere((o) => o.id == newOutletId);
                  _switchOutlet(context, newOutlet);
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _switchOutlet(BuildContext context, Outlet newOutlet) async {
    final outletProvider = context.read<OutletProvider>();
    final catalogProvider = context.read<CatalogProvider>();
    final orderProvider = context.read<OrderProvider>();
    final staffProvider = context.read<StaffProvider>();
    final tradingDayProvider = context.read<TradingDayProvider>();
    final printerService = PrinterService.instance;
    final modifierService = ModifierService();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show rich progress dialog (mirroring startup sync UI)
    // This dialog passively observes the sync orchestrator's progress stream
    final dialogFuture = showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => OutletSyncProgressDialog(
        title: 'Switching to ${newOutlet.name}',
      ),
    );

    // Trigger the switch validation (which will run prepareOutletForUse internally)
    // CRITICAL: Pass reload callback to execute provider reload IMMEDIATELY after outlet commits
    // This ensures providers are loaded from the freshly synced local mirror
    final success = await outletProvider.setCurrentOutletWithValidation(
      newOutlet,
      onReloadComplete: () => _reloadProvidersAfterSwitch(
        context,
        newOutlet,
        catalogProvider,
        orderProvider,
        staffProvider,
        tradingDayProvider,
        printerService,
        modifierService,
      ),
    );

    // Wait for dialog to close (it auto-closes when sync completes)
    final dialogResult = await dialogFuture;

    if (!success) {
      // Show error dialog
      _showSwitchError(context, outletProvider);
      return;
    }

    debugPrint('✅ OutletSelector: Outlet switch complete');
    
    // Show success message
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Switched to ${newOutlet.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Reload all providers after outlet switch completes
  /// This is called synchronously as a callback during outlet commit
  /// Mirrors the exact initialization flow from TillScreen + AppShell
  void _reloadProvidersAfterSwitch(
    BuildContext context,
    Outlet newOutlet,
    CatalogProvider catalogProvider,
    OrderProvider orderProvider,
    StaffProvider staffProvider,
    TradingDayProvider tradingDayProvider,
    PrinterService printerService,
    ModifierService modifierService,
  ) {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🔄 OutletSelector: RELOADING PROVIDERS after outlet switch');
    debugPrint('   New Outlet: ${newOutlet.name} (${newOutlet.id})');
    debugPrint('═══════════════════════════════════════════════════════════');
    
    // Load all providers in parallel (mirroring TillScreen + AppShell initialization exactly)
    // CRITICAL: This must be async fire-and-forget to not block outlet commit
    Future.wait([
      catalogProvider.loadCatalog(newOutlet.id),
      orderProvider.loadPromotions(newOutlet.id),
      staffProvider.loadStaffForOutlet(newOutlet.id),
      tradingDayProvider.loadCurrentTradingDay(newOutlet.id),
      printerService.loadPrinters(newOutlet.id),
      modifierService.loadModifiersForOutlet(newOutlet.id),
    ]).then((_) {
      debugPrint('✅ OutletSelector: All providers reloaded successfully');
      
      // Set product catalog for promotion calculation
      orderProvider.setProductCatalog(catalogProvider.products);
      
      // Set packaged deal service for deal detection
      orderProvider.setPackagedDealService(catalogProvider.packagedDealService);
      
      // Clear and initialize order with service charge settings from outlet
      orderProvider.clearOrder(
        autoEnableServiceCharge: newOutlet.enableServiceCharge,
        outletServiceChargePercent: newOutlet.serviceChargePercent,
      );
      orderProvider.initializeOrder(
        newOutlet.id,
        staffProvider.currentStaff?.id,
        autoEnableServiceCharge: newOutlet.enableServiceCharge,
        outletServiceChargePercent: newOutlet.serviceChargePercent,
      );
      
      debugPrint('✅ OutletSelector: Provider reload complete');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');
    }).catchError((e, stackTrace) {
      debugPrint('❌ OutletSelector: Error reloading providers: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');
    });
  }

  void _showSwitchError(BuildContext context, OutletProvider outletProvider) {
    final errorMessage = outletProvider.errorMessage ?? 'Failed to switch outlet';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cannot Switch Outlet'),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
