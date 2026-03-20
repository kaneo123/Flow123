import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/theme.dart';
import 'package:flowtill/services/mirror_content_sync_service.dart';
import 'package:flowtill/services/outlet_availability_service.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:intl/intl.dart';

/// Mirror Diagnostics Screen
/// Shows detailed per-table mirror status and provides manual sync controls
class MirrorDiagnosticsScreen extends StatefulWidget {
  const MirrorDiagnosticsScreen({super.key});

  @override
  State<MirrorDiagnosticsScreen> createState() => _MirrorDiagnosticsScreenState();
}

class _MirrorDiagnosticsScreenState extends State<MirrorDiagnosticsScreen> {
  final _mirrorService = MirrorContentSyncService();
  final _availabilityService = OutletAvailabilityService();
  
  MirrorDiagnostics? _diagnostics;
  OutletAvailabilityResult? _availability;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _currentAction;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() => _isLoading = true);

    try {
      final outletProvider = context.read<OutletProvider>();
      final outletId = outletProvider.currentOutlet?.id;

      debugPrint('[DEV_SYNC] Loading mirror diagnostics for outlet: $outletId');
      
      // Load both diagnostics and availability status
      final diagnostics = await _mirrorService.getMirrorDiagnostics(outletId);
      final availability = outletId != null 
          ? await _availabilityService.isOutletAvailableOffline(outletId)
          : null;

      if (mounted) {
        setState(() {
          _diagnostics = diagnostics;
          _availability = availability;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DEV_SYNC] ❌ Failed to load diagnostics: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackbar('Failed to load diagnostics: $e');
      }
    }
  }

  Future<void> _syncAllTables() async {
    final outletProvider = context.read<OutletProvider>();
    final outletId = outletProvider.currentOutlet?.id;

    if (outletId == null) {
      _showErrorSnackbar('No outlet selected');
      return;
    }

    setState(() {
      _isSyncing = true;
      _currentAction = 'Syncing all tables...';
    });

    try {
      debugPrint('[DEV_SYNC] Sync all tables requested');
      final result = await _mirrorService.syncAllMirrorContent(outletId);

      if (result.success) {
        _showSuccessSnackbar('✅ Synced ${result.totalRows} rows from ${result.tableResults.length} tables');
        await _loadDiagnostics();
      } else {
        _showErrorSnackbar('Sync failed: ${result.error}');
      }
    } catch (e) {
      debugPrint('[DEV_SYNC] ❌ Sync all failed: $e');
      _showErrorSnackbar('Sync failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _currentAction = null;
        });
      }
    }
  }

  Future<void> _clearAllTables() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Mirror Content?'),
        content: const Text(
          'This will remove all local mirror data. Schema tables will be preserved.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSyncing = true;
      _currentAction = 'Clearing all tables...';
    });

    try {
      debugPrint('[DEV_SYNC] Clear all tables requested');
      final result = await _mirrorService.clearAllMirrorContent();

      if (result.success) {
        _showSuccessSnackbar('✅ Cleared ${result.clearedTables} tables');
        await _loadDiagnostics();
      } else {
        _showErrorSnackbar('Clear failed: ${result.error}');
      }
    } catch (e) {
      debugPrint('[DEV_SYNC] ❌ Clear all failed: $e');
      _showErrorSnackbar('Clear failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _currentAction = null;
        });
      }
    }
  }

  Future<void> _syncSingleTable(String tableName) async {
    final outletProvider = context.read<OutletProvider>();
    final outletId = outletProvider.currentOutlet?.id;

    if (outletId == null) {
      _showErrorSnackbar('No outlet selected');
      return;
    }

    setState(() {
      _isSyncing = true;
      _currentAction = 'Syncing $tableName...';
    });

    try {
      debugPrint('[DEV_SYNC] Sync table requested: $tableName');
      final result = await _mirrorService.syncSingleTable(tableName, outletId);

      if (result.success) {
        _showSuccessSnackbar('✅ Synced ${result.rowsSynced} rows from $tableName');
        await _loadDiagnostics();
      } else {
        _showErrorSnackbar('Sync failed: ${result.error}');
      }
    } catch (e) {
      debugPrint('[DEV_SYNC] ❌ Sync table failed: $e');
      _showErrorSnackbar('Sync failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _currentAction = null;
        });
      }
    }
  }

  Future<void> _clearSingleTable(String tableName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear $tableName?'),
        content: Text('This will remove all local data from $tableName. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSyncing = true;
      _currentAction = 'Clearing $tableName...';
    });

    try {
      debugPrint('[DEV_SYNC] Clear table requested: $tableName');
      final result = await _mirrorService.clearSingleTable(tableName);

      if (result.success) {
        _showSuccessSnackbar('✅ Cleared $tableName');
        await _loadDiagnostics();
      } else {
        _showErrorSnackbar('Clear failed: ${result.error}');
      }
    } catch (e) {
      debugPrint('[DEV_SYNC] ❌ Clear table failed: $e');
      _showErrorSnackbar('Clear failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _currentAction = null;
        });
      }
    }
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: const Text('Local Mirror Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading || _isSyncing ? null : _loadDiagnostics,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Action Bar
          Container(
            padding: AppSpacing.paddingLg,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                // Current action indicator
                if (_isSyncing && _currentAction != null) ...[
                  Container(
                    padding: AppSpacing.paddingSm,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _currentAction!,
                            style: context.textStyles.bodyMedium?.semiBold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSyncing ? null : _syncAllTables,
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Sync All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSyncing ? null : _clearAllTables,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear All'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Outlet Availability Status
          if (_availability != null)
            Container(
              margin: AppSpacing.paddingMd,
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: _availability!.isAvailable 
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                border: Border.all(
                  color: _availability!.isAvailable 
                      ? Colors.green 
                      : Colors.orange,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _availability!.isAvailable 
                            ? Icons.check_circle 
                            : Icons.warning,
                        color: _availability!.isAvailable 
                            ? Colors.green 
                            : Colors.orange,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Offline Availability',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _availability!.isAvailable
                        ? 'This outlet is fully available for offline use'
                        : 'This outlet is NOT available for offline use',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (!_availability!.isAvailable && _availability!.emptyTables.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Missing data: ${_availability!.emptyTables.join(", ")}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Table list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _diagnostics == null
                    ? const Center(child: Text('No diagnostics data'))
                    : ListView.builder(
                        padding: AppSpacing.paddingMd,
                        itemCount: _diagnostics!.tables.length,
                        itemBuilder: (context, index) {
                          final table = _diagnostics!.tables[index];
                          return _TableDiagnosticCard(
                            table: table,
                            onSync: () => _syncSingleTable(table.tableName),
                            onClear: () => _clearSingleTable(table.tableName),
                            isDisabled: _isSyncing,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// Card widget showing diagnostics for a single table
class _TableDiagnosticCard extends StatelessWidget {
  final TableDiagnostic table;
  final VoidCallback onSync;
  final VoidCallback onClear;
  final bool isDisabled;

  const _TableDiagnosticCard({
    required this.table,
    required this.onSync,
    required this.onClear,
    required this.isDisabled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEmpty = table.localRowCount == 0;
    final hasSchema = table.localTableExists;
    final sourceColor = table.sourceCurrentlyUsed == 'local' 
        ? Colors.green 
        : table.sourceCurrentlyUsed == 'supabase fallback'
            ? Colors.orange
            : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      elevation: 2,
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        table.tableName,
                        style: context.textStyles.titleMedium?.bold,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _StatusChip(
                            label: hasSchema ? 'Schema ✓' : 'No Schema',
                            color: hasSchema ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(
                            label: isEmpty ? 'Empty' : '${table.localRowCount} rows',
                            color: isEmpty ? Colors.orange : Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Source indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: sourceColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: sourceColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        table.sourceCurrentlyUsed == 'local'
                            ? Icons.storage
                            : table.sourceCurrentlyUsed == 'supabase fallback'
                                ? Icons.cloud
                                : Icons.help_outline,
                        size: 14,
                        color: sourceColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        table.sourceCurrentlyUsed == 'local' 
                            ? 'Local'
                            : table.sourceCurrentlyUsed == 'supabase fallback'
                                ? 'Fallback'
                                : 'N/A',
                        style: context.textStyles.labelSmall?.copyWith(
                          color: sourceColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Details grid
            Row(
              children: [
                Expanded(
                  child: _DetailItem(
                    label: 'Local Rows',
                    value: table.localRowCount.toString(),
                    icon: Icons.storage,
                  ),
                ),
                Expanded(
                  child: _DetailItem(
                    label: 'Supabase Rows',
                    value: table.supabaseRowCount?.toString() ?? 'N/A',
                    icon: Icons.cloud,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // Last sync info
            if (table.lastContentSync != null)
              Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Last synced: ${DateFormat('MMM d, HH:mm').format(table.lastContentSync!)}',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(
                    Icons.warning,
                    size: 14,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Never synced',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: AppSpacing.md),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isDisabled ? null : onSync,
                    icon: const Icon(Icons.cloud_download, size: 16),
                    label: const Text('Sync Table'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isDisabled || !hasSchema ? null : onClear,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Clear Table'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(
                        color: Colors.red.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: context.textStyles.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: AppSpacing.paddingSm,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.textStyles.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: context.textStyles.titleSmall?.bold,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
