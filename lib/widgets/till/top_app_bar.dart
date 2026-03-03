import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/providers/catalog_provider.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/providers/staff_provider.dart';
import 'package:flowtill/services/modifier_service.dart';
import 'package:flowtill/widgets/till/outlet_selector.dart';
import 'package:flowtill/widgets/till/search_bar_widget.dart';
import 'package:flowtill/widgets/till/staff_button.dart';
import 'package:flowtill/widgets/till/sync_status_indicator.dart';
import 'package:flowtill/theme.dart';

class TopAppBar extends StatelessWidget {
  final ModifierService modifierService;

  const TopAppBar({
    super.key,
    required this.modifierService,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final isMedium = constraints.maxWidth >= 600 && constraints.maxWidth < 1100;

          if (isMobile) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleHomeReset(context),
                        icon: const Icon(Icons.home, size: 18),
                        label: const Text('Home'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Expanded(child: OutletSelector()),
                    const SizedBox(width: AppSpacing.xs),
                    _RefreshStockButton(),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () => _showSettings(context),
                      iconSize: 20,
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () => _handleLogout(context),
                      iconSize: 20,
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      constraints: const BoxConstraints(),
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SearchBarWidget(modifierService: modifierService),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Expanded(child: StaffButton()),
                    SizedBox(width: AppSpacing.xs),
                    SyncStatusIndicator(),
                  ],
                ),
              ],
            );
          }

          final searchWidth = constraints.maxWidth.clamp(360.0, 600.0);
          final barChildren = [
            ElevatedButton.icon(
              onPressed: () => _handleHomeReset(context),
              icon: const Icon(Icons.home, size: 20),
              label: const Text('Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              ),
            ),
            SizedBox(width: isMedium ? AppSpacing.md : AppSpacing.lg),
            const OutletSelector(),
            SizedBox(width: isMedium ? AppSpacing.md : AppSpacing.lg),
            SizedBox(
              width: searchWidth,
              child: SearchBarWidget(modifierService: modifierService),
            ),
            SizedBox(width: isMedium ? AppSpacing.md : AppSpacing.lg),
            const StaffButton(),
            SizedBox(width: isMedium ? AppSpacing.sm : AppSpacing.md),
            _RefreshStockButton(),
            SizedBox(width: isMedium ? AppSpacing.xs : AppSpacing.sm),
            IconButton(
              icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => _showSettings(context),
              tooltip: 'Settings',
            ),
            SizedBox(width: isMedium ? AppSpacing.xs : AppSpacing.sm),
            IconButton(
              icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              onPressed: () => _handleLogout(context),
              tooltip: 'Logout',
            ),
            SizedBox(width: isMedium ? AppSpacing.xs : AppSpacing.sm),
            const SyncStatusIndicator(),
          ];

          if (isMedium) {
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: barChildren,
            );
          }

          // Desktop layout - use Wrap to prevent overflow
          return Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: barChildren,
          );
        },
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings features:'),
            SizedBox(height: AppSpacing.sm),
            Text('• Printer configuration'),
            Text('• Receipt settings'),
            Text('• Tax rate management'),
            Text('• User preferences'),
            Text('• System configuration'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    final staffProvider = context.read<StaffProvider>();
    final orderProvider = context.read<OrderProvider>();
    
    // Logout with callback to save current order before logging out
    staffProvider.logout(
      onParkOrder: (staffId) => orderProvider.parkOrderForStaff(staffId),
    );
    
    context.go('/staff-login');
  }

  void _handleHomeReset(BuildContext context) {
    debugPrint('🏠 TopAppBar: Home button pressed - resetting to home');
    final catalogProvider = context.read<CatalogProvider>();
    
    // Pop any sub-category screens
    while (context.canPop()) {
      context.pop();
    }
    
    // Clear navigation stack and reset to root (showing categories, not specific category)
    catalogProvider.resetNavigation();
    
    debugPrint('🏠 TopAppBar: Navigation reset complete');
  }
}

/// Manual refresh stock button
class _RefreshStockButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final catalogProvider = context.watch<CatalogProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      icon: catalogProvider.isRefreshingStock
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
              color: colorScheme.primary,
            ),
      onPressed: catalogProvider.isRefreshingStock
          ? null
          : () {
              debugPrint('🔄 User manually refreshing stock');
              catalogProvider.refreshStockOnly();
              
              // Show confirmation snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Stock levels refreshed'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: colorScheme.primary,
                ),
              );
            },
      tooltip: 'Refresh Stock',
      iconSize: 20,
      padding: const EdgeInsets.all(AppSpacing.xs),
      constraints: const BoxConstraints(),
    );
  }
}
