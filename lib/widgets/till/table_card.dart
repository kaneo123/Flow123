import 'package:flutter/material.dart';
import 'package:flowtill/models/outlet_table.dart';
import 'package:flowtill/theme.dart';

class TableCard extends StatelessWidget {
  final OutletTable table;
  final String status;
  final VoidCallback onTap;

  const TableCard({
    super.key,
    required this.table,
    required this.status,
    required this.onTap,
  });

  Color _getStatusColor(BuildContext context) {
    switch (status) {
      case 'open':
        return Theme.of(context).colorScheme.tertiary;
      case 'parked':
        return Theme.of(context).colorScheme.secondary;
      case 'free':
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _getStatusLabel() {
    switch (status) {
      case 'open':
        return 'Open';
      case 'parked':
        return 'Away';
      case 'free':
      default:
        return 'Free';
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case 'open':
        return Icons.receipt_long;
      case 'parked':
        return Icons.pause_circle_outline;
      case 'free':
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context);
    final isFree = status == 'free';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isFree 
                  ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                  : statusColor,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Stack(
            children: [
              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Table icon
                    Icon(
                      Icons.table_restaurant,
                      size: 40,
                      color: isFree
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : statusColor,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Table name or number
                    Text(
                      table.displayName,
                      style: context.textStyles.titleLarge?.semiBold.copyWith(
                        color: isFree
                            ? Theme.of(context).colorScheme.onSurface
                            : statusColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (table.capacity != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${table.capacity}',
                            style: context.textStyles.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Status badge
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(),
                        size: 14,
                        color: isFree
                            ? Theme.of(context).colorScheme.onPrimary
                            : Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getStatusLabel(),
                        style: context.textStyles.labelSmall?.semiBold.copyWith(
                          color: isFree
                              ? Theme.of(context).colorScheme.onPrimary
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
