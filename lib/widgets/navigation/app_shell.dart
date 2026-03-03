import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/providers/navigation_provider.dart';
import 'package:flowtill/widgets/navigation/app_navigation_drawer.dart';
import 'package:flowtill/theme.dart';

/// App shell with top app bar and navigation drawer
/// Wraps all main screens in the app
class AppShell extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final Function(NavigationItem)? onNavigationItemSelected;
  final VoidCallback? onLogout;

  const AppShell({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.actions,
    this.onNavigationItemSelected,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final isLargeScreen = mediaQuery.size.width >= 1024;

    return Scaffold(
      key: const Key('app_shell_scaffold'),
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: isLargeScreen ? null : Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            iconSize: 28,
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        title: _buildAppBarTitle(context, navProvider),
        centerTitle: true,
        actions: [
          ...(actions ?? []),
          _buildStatusIndicators(context, navProvider),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      drawer: isLargeScreen ? null : Drawer(
        child: AppNavigationDrawer(
          onNavigationItemSelected: onNavigationItemSelected,
          onLogout: onLogout,
        ),
      ),
      body: Row(
        children: [
          // Side rail for large screens
          if (isLargeScreen)
            AppNavigationDrawer(
              onNavigationItemSelected: onNavigationItemSelected,
              onLogout: onLogout,
              isCollapsed: navProvider.isDrawerCollapsed,
            ),
          
          // Main content area
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle(BuildContext context, NavigationProvider navProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final displayTitle = title ?? navProvider.currentOutlet?.name ?? 'FlowTill';

    return Text(
      displayTitle,
      style: theme.textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildStatusIndicators(BuildContext context, NavigationProvider navProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Online/Offline indicator
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: navProvider.isOnline
                ? colorScheme.primary.withValues(alpha: 0.1)
                : colorScheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                navProvider.isOnline ? Icons.cloud_done : Icons.cloud_off,
                size: 16,
                color: navProvider.isOnline ? colorScheme.primary : colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                navProvider.isOnline ? 'Online' : 'Offline',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: navProvider.isOnline ? colorScheme.primary : colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Sync indicator
        if (navProvider.isSyncing) ...[
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
        ],

        // Staff name indicator
        if (navProvider.loggedInStaff != null) ...[
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  navProvider.loggedInStaff!.fullName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
