import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/services/sync_service.dart';
import 'package:flowtill/providers/staff_provider.dart';
import 'package:flowtill/providers/order_provider.dart';

/// Widget that displays connection and sync status
class SyncStatusIndicator extends StatefulWidget {
  final bool showLogoutButton;
  
  const SyncStatusIndicator({
    super.key,
    this.showLogoutButton = false,
  });

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  final ConnectionService _connectionService = ConnectionService();
  final SyncService _syncService = SyncService();
  
  bool _isOnline = true;
  SyncStatus _syncStatus = SyncStatus.idle;

  @override
  void initState() {
    super.initState();
    _isOnline = _connectionService.isOnline;
    _syncStatus = _syncService.currentStatus;
    
    // Listen to connection changes
    _connectionService.connectionStream.listen((isOnline) {
      if (mounted) {
        setState(() => _isOnline = isOnline);
      }
    });
    
    // Listen to sync status changes
    _syncService.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() => _syncStatus = status);
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staffProvider = context.watch<StaffProvider>();
    final staffName = staffProvider.currentStaff?.fullName ?? 'Guest';
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (!_isOnline) {
      statusColor = Colors.orange;
      statusIcon = Icons.cloud_off;
      statusText = 'Offline';
    } else if (_syncStatus == SyncStatus.syncing) {
      statusColor = Colors.blue;
      statusIcon = Icons.sync;
      statusText = 'Syncing...';
    } else if (_syncStatus == SyncStatus.error) {
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
      statusText = 'Sync Error';
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.cloud_done;
      statusText = 'Online';
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Staff name (when logout button is shown)
        if (widget.showLogoutButton) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person, color: theme.colorScheme.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  staffName,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        
        // Sync status
        GestureDetector(
          onTap: () {
            // Force sync when tapped
            if (_isOnline && _syncStatus != SyncStatus.syncing) {
              _syncService.forceSyncNow();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Syncing data...'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              border: Border.all(color: statusColor, width: 1.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Logout button (when top bar is hidden)
        if (widget.showLogoutButton) ...[
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleLogout(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                  border: Border.all(color: theme.colorScheme.error, width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout, color: theme.colorScheme.error, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
