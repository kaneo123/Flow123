import 'package:flutter/material.dart';
import 'package:flowtill/models/table_session.dart';

/// Warning banner shown when a table/tab is already open by another user
class TableLockWarningBanner extends StatelessWidget {
  final List<TableSession> otherSessions;
  final VoidCallback onLogout;
  final VoidCallback? onCancel;

  const TableLockWarningBanner({
    super.key,
    required this.otherSessions,
    required this.onLogout,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (otherSessions.isEmpty) return const SizedBox.shrink();

    final otherUser = otherSessions.first;
    final additionalCount = otherSessions.length - 1;

    return Material(
      color: colorScheme.errorContainer,
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: colorScheme.onErrorContainer,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Table Already Open',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    additionalCount > 0
                        ? '${otherUser.staffName} and $additionalCount other${additionalCount > 1 ? 's' : ''} currently have this table open'
                        : '${otherUser.staffName} currently has this table open (${otherUser.timeSinceStarted})',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This table is currently in use. Please speak with the operator for assistance.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: onLogout,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Log Out'),
                ),
                if (onCancel != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onErrorContainer,
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact indicator showing who else has the table open (for app bar)
class TableLockIndicator extends StatelessWidget {
  final List<TableSession> otherSessions;
  final VoidCallback? onTap;

  const TableLockIndicator({
    super.key,
    required this.otherSessions,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (otherSessions.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(20),
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
              size: 16,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 6),
            Text(
              otherSessions.length == 1
                  ? otherSessions.first.staffName
                  : '${otherSessions.length} users',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.info_outline,
              size: 14,
              color: colorScheme.onErrorContainer.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to inform user table is locked and suggest contacting operator
class TableLockedDialog extends StatelessWidget {
  final List<TableSession> otherSessions;
  final VoidCallback onLogout;

  const TableLockedDialog({
    super.key,
    required this.otherSessions,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      icon: Icon(
        Icons.lock_person_rounded,
        size: 48,
        color: colorScheme.error,
      ),
      title: const Text('Table Currently In Use'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This table is being used by:',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...otherSessions.map((session) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${session.staffName} (${session.timeSinceStarted})',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please speak with the operator for assistance.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onLogout();
          },
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Log Out'),
        ),
      ],
    );
  }
}

/// Dialog showing details about who has the table open
class TableSessionDetailsDialog extends StatelessWidget {
  final List<TableSession> sessions;
  final VoidCallback? onLogout;

  const TableSessionDetailsDialog({
    super.key,
    required this.sessions,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.people_alt_rounded,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          const Text('Active Users'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No other users have this table open',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              ListView.builder(
                shrinkWrap: true,
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(session.staffName),
                    subtitle: Text('Opened ${session.timeSinceStarted}'),
                    trailing: session.isStale
                        ? Chip(
                            label: const Text('Inactive'),
                            backgroundColor: colorScheme.errorContainer,
                            labelStyle: TextStyle(
                              color: colorScheme.onErrorContainer,
                              fontSize: 12,
                            ),
                          )
                        : Icon(
                            Icons.circle,
                            size: 12,
                            color: colorScheme.tertiary,
                          ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please speak with the operator for assistance.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (onLogout != null && sessions.isNotEmpty)
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onLogout!();
            },
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Log Out'),
          ),
      ],
    );
  }
}
