import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flowtill/providers/order_history_provider.dart';
import 'package:flowtill/theme.dart';

class OrderHistoryModal extends StatelessWidget {
  const OrderHistoryModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'Table Order History',
                      style: context.textStyles.headlineSmall?.semiBold,
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'All staff actions on this table order',
              style: context.textStyles.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            
            // History list
            Expanded(
              child: Consumer<OrderHistoryProvider>(
                builder: (context, historyProvider, _) {
                  if (historyProvider.isLoadingHistory) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (historyProvider.historyError != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            historyProvider.historyError!,
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final history = historyProvider.currentOrderHistory;

                  if (history.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'No history yet for this table',
                            style: context.textStyles.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Actions will appear here as staff work on the order',
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: history.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final activity = history[index];
                      final timeFormat = DateFormat('HH:mm');
                      final timeStr = timeFormat.format(activity.createdAt);

                      // Determine icon and color based on action type
                      IconData icon;
                      Color iconColor;
                      
                      switch (activity.actionType) {
                        case 'item_added':
                          icon = Icons.add_circle_outline;
                          iconColor = Colors.green;
                          break;
                        case 'item_removed':
                          icon = Icons.remove_circle_outline;
                          iconColor = Colors.red;
                          break;
                        case 'discount_applied':
                        case 'voucher_applied':
                        case 'loyalty_applied':
                          icon = Icons.discount_outlined;
                          iconColor = Colors.orange;
                          break;
                        case 'order_parked':
                          icon = Icons.pause_circle_outline;
                          iconColor = Colors.blue;
                          break;
                        case 'order_resumed':
                          icon = Icons.play_circle_outline;
                          iconColor = Colors.blue;
                          break;
                        case 'note_added':
                          icon = Icons.note_outlined;
                          iconColor = Colors.purple;
                          break;
                        default:
                          icon = Icons.info_outline;
                          iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
                      }

                      // Get staff name from meta if available
                      final staffName = activity.meta?['staff_name'] as String?;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            icon,
                            color: iconColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          activity.actionDescription,
                          style: context.textStyles.bodyMedium?.semiBold,
                        ),
                        subtitle: staffName != null
                            ? Text(
                                'By $staffName',
                                style: context.textStyles.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              )
                            : null,
                        trailing: Text(
                          timeStr,
                          style: context.textStyles.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
