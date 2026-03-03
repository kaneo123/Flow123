import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/providers/order_provider.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/models/order_item.dart';
import 'package:flowtill/theme.dart';

class OrderSummary extends StatefulWidget {
  final bool isCollapsed;
  
  const OrderSummary({
    super.key,
    this.isCollapsed = false,
  });

  @override
  State<OrderSummary> createState() => _OrderSummaryState();
}

class _OrderSummaryState extends State<OrderSummary> {
  bool _showDetails = false;
  bool _showTaxDetails = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Detect Android for compact mode (consistent with order_panel.dart)
    final isAndroid = defaultTargetPlatform == TargetPlatform.android && !kIsWeb;
    final compact = isAndroid;
    
    // Use widget.isCollapsed to determine if we should show minimal view
    final isCollapsed = widget.isCollapsed;
    
    // Limit OrderSummary to max 35% of screen height on non-compact, 15% on compact
    final maxHeight = compact ? screenHeight * 0.15 : screenHeight * 0.35;
    
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        final order = orderProvider.currentOrder;
        if (order == null) return const SizedBox.shrink();

        // Mobile/compact view - COLLAPSED: Show only minimal total
        if ((isMobile || compact) && isCollapsed) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: context.textStyles.titleMedium?.bold.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  '£${order.totalDue.toStringAsFixed(2)}',
                  style: context.textStyles.titleMedium?.bold.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          );
        }

        // EXPANDED view - Show full summary (both mobile and desktop)
        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Summary',
                    style: context.textStyles.titleSmall?.semiBold.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'Subtotal',
                value: '£${order.subtotal.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 4),
              // Collapsible Tax Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tax',
                    style: context.textStyles.bodyMedium,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '£${order.taxAmount.toStringAsFixed(2)}',
                        style: context.textStyles.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => setState(() => _showTaxDetails = !_showTaxDetails),
                        child: Icon(
                          _showTaxDetails ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Tax breakdown details
              if (_showTaxDetails && order.items.isNotEmpty) ...[
                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),
                ...() {
                  // Group items by tax rate
                  final Map<double, List<OrderItem>> itemsByRate = {};
                  for (final item in order.items) {
                    itemsByRate.putIfAbsent(item.taxRate, () => []).add(item);
                  }
                  
                  return itemsByRate.entries.map((entry) {
                    final rate = entry.key;
                    final items = entry.value;
                    final subtotal = items.fold(0.0, (sum, item) => sum + item.subtotal);
                    final tax = items.fold(0.0, (sum, item) => sum + item.taxAmount);
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryRow(
                          label: 'Rate ${(rate * 100).toStringAsFixed(1)}%',
                          value: '${subtotal.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 2),
                        _SummaryRow(
                          label: '  Tax',
                          value: '${tax.toStringAsFixed(2)}',
                          valueColor: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 6),
                      ],
                    );
                  }).toList();
                }(),
                const Divider(height: 1),
              ],
              if (order.promotionDiscount > 0) ...[
                const SizedBox(height: 4),
                const Divider(height: 8),
                Text(
                  'Promotions',
                  style: context.textStyles.labelSmall?.semiBold.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                ...order.appliedPromotions.map((promo) => Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: _SummaryRow(
                    label: '  • ${promo.name}',
                    value: '-£${promo.discountAmount.toStringAsFixed(2)}',
                    valueColor: Theme.of(context).colorScheme.primary,
                  ),
                )),
                const SizedBox(height: 2),
                _SummaryRow(
                  label: 'Total promo discount',
                  value: '-£${order.promotionDiscount.toStringAsFixed(2)}',
                  valueColor: Theme.of(context).colorScheme.primary,
                ),
                const Divider(height: 8),
              ],
              if (order.discountAmount > 0) ...[
                const SizedBox(height: 4),
                _SummaryRow(
                  label: order.loyaltyCustomerName != null
                      ? 'Loyalty Card (${order.loyaltyCustomerName})'
                      : 'Discount',
                  value: '-£${order.discountAmount.toStringAsFixed(2)}',
                  valueColor: Theme.of(context).colorScheme.error,
                ),
                if (order.loyaltyRewardName != null) ...[
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '${order.loyaltyRewardName}',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
              // Service Charge toggle (only if enabled in outlet settings)
              Consumer<OutletProvider>(
                builder: (context, outletProvider, _) {
                  final outlet = outletProvider.currentOutlet;
                  
                  debugPrint('📊 OrderSummary: Service Charge Section');
                  debugPrint('   Outlet: ${outlet?.name ?? "null"}');
                  debugPrint('   Outlet enableServiceCharge: ${outlet?.enableServiceCharge ?? false}');
                  debugPrint('   Outlet serviceChargePercent: ${outlet?.serviceChargePercent ?? 0.0}');
                  debugPrint('   Order serviceChargeRate: ${order.serviceChargeRate}');
                  debugPrint('   Order subtotal: £${order.subtotal.toStringAsFixed(2)}');
                  debugPrint('   Order serviceCharge: £${order.serviceCharge.toStringAsFixed(2)}');
                  debugPrint('   orderProvider.serviceChargeEnabled: ${orderProvider.serviceChargeEnabled}');
                  
                  if (outlet == null || !(outlet.enableServiceCharge ?? false)) {
                    debugPrint('   ⏭️  Hiding service charge section (outlet null or not enabled)');
                    return const SizedBox.shrink();
                  }

                  debugPrint('   ✅ Showing service charge toggle');

                  return Column(
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Service (${(outlet.serviceChargePercent ?? 0.0).toStringAsFixed(1)}%)',
                            style: context.textStyles.bodyMedium,
                          ),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: orderProvider.serviceChargeEnabled ?? false,
                              onChanged: (_) {
                                debugPrint('🎚️ Service Charge Switch toggled by user');
                                orderProvider.toggleServiceCharge(outlet.serviceChargePercent ?? 0.0);
                              },
                              activeColor: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (order.serviceCharge > 0) ...[
                        const SizedBox(height: 4),
                        _SummaryRow(
                          label: 'Service',
                          value: '£${order.serviceCharge.toStringAsFixed(2)}',
                        ),
                      ],
                    ],
                  );
                },
              ),
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: context.textStyles.titleLarge?.bold,
                  ),
                  Text(
                    '£${order.totalDue.toStringAsFixed(2)}',
                    style: context.textStyles.titleLarge?.bold.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool compact;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: compact
              ? context.textStyles.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                )
              : context.textStyles.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
        ),
        Text(
          value,
          style: compact
              ? context.textStyles.bodySmall?.semiBold.copyWith(
                  color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                  fontSize: 11,
                )
              : context.textStyles.titleMedium?.semiBold.copyWith(
                  color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                ),
        ),
      ],
    );
  }
}

class _CompactValue extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _CompactValue({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon, 
          size: 14, 
          color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 2),
        Text(
          '$label: $value',
          style: context.textStyles.bodySmall?.copyWith(
            fontSize: 11,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
