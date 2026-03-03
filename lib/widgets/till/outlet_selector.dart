import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/models/outlet.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/providers/catalog_provider.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/providers/staff_provider.dart';
import 'package:flowtill/services/printer/printer_service.dart';
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
    final printerService = PrinterService.instance;

    outletProvider.setCurrentOutlet(newOutlet);
    
    // Load catalog first, then set up promotions
    await catalogProvider.loadCatalog(newOutlet.id);
    
    // Load promotions for this outlet
    await orderProvider.loadPromotions(newOutlet.id);
    
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
    staffProvider.loadStaffForOutlet(newOutlet.id);
    printerService.loadPrinters(newOutlet.id);
  }
}
