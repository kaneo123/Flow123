import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/providers/navigation_provider.dart';
import 'package:flowtill/providers/catalog_provider.dart';
import 'package:flowtill/theme.dart';

/// Custom navigation drawer for the app
/// Follows MVVM pattern - consumes NavigationProvider for state
class AppNavigationDrawer extends StatelessWidget {
  final Function(NavigationItem)? onNavigationItemSelected;
  final VoidCallback? onLogout;
  final bool isCollapsed;

  const AppNavigationDrawer({
    super.key,
    this.onNavigationItemSelected,
    this.onLogout,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: isCollapsed ? 72 : 280,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          right: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer header with business info
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: isCollapsed ? _buildCollapsedHeader(theme, colorScheme, navProvider) : _buildExpandedHeader(theme, colorScheme, navProvider),
            ),

            // Navigation items
            Expanded(
              child: ListView(
                padding: AppSpacing.paddingSm,
                children: [
                  // Main navigation items
                  ...NavigationItem.values.map((item) {
                    final isSelected = navProvider.currentItem == item;
                    return _NavigationTile(
                      icon: navProvider.getNavigationItemIcon(item),
                      label: navProvider.getNavigationItemLabel(item),
                      isSelected: isSelected,
                      isCollapsed: isCollapsed,
                      onTap: () {
                        navProvider.setCurrentItem(item);
                        onNavigationItemSelected?.call(item);
                        navProvider.closeDrawer();
                      },
                    );
                  }),

                  // Manual Refresh Button
                  _RefreshButton(isCollapsed: isCollapsed),

                  // Divider
                  Padding(
                    padding: AppSpacing.verticalMd,
                    child: Divider(
                      color: colorScheme.outline.withValues(alpha: 0.2),
                      thickness: 1,
                    ),
                  ),

                  // Logout button
                  _NavigationTile(
                    icon: Icons.logout,
                    label: 'Logout',
                    isSelected: false,
                    isCollapsed: isCollapsed,
                    isDanger: true,
                    onTap: () {
                      navProvider.logout();
                      onLogout?.call();
                      navProvider.closeDrawer();
                    },
                  ),
                ],
              ),
            ),

            // Toggle collapse button (only on large screens)
            if (MediaQuery.of(context).size.width >= 1024)
              Container(
                padding: AppSpacing.paddingSm,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => navProvider.toggleDrawerCollapsed(),
                  tooltip: isCollapsed ? 'Expand' : 'Collapse',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedHeader(ThemeData theme, ColorScheme colorScheme, NavigationProvider navProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Business logo placeholder
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            Icons.storefront,
            color: colorScheme.onPrimary,
            size: 32,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        
        // Current outlet name
        Text(
          navProvider.currentOutlet?.name ?? 'No Outlet Selected',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final info = snapshot.data!;
              final versionLabel = '${info.version}+${info.buildNumber}';
              return Text(
                'Version $versionLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            }
            return const SizedBox.shrink();
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        
        // Logged-in staff info
        if (navProvider.loggedInStaff != null) ...[
          Text(
            navProvider.loggedInStaff!.fullName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            navProvider.loggedInStaff!.roleId ?? 'Staff',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ] else ...[
          Text(
            'Not logged in',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.error,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCollapsedHeader(ThemeData theme, ColorScheme colorScheme, NavigationProvider navProvider) {
    return Column(
      children: [
        // Business logo placeholder
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            Icons.storefront,
            color: colorScheme.onPrimary,
            size: 24,
          ),
        ),
      ],
    );
  }
}

/// Individual navigation tile
class _NavigationTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final bool isDanger;
  final VoidCallback onTap;

  const _NavigationTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isCollapsed = false,
    this.isDanger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final backgroundColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : Colors.transparent;

    final textColor = isDanger
        ? colorScheme.error
        : isSelected
            ? colorScheme.primary
            : colorScheme.onSurface;

    final iconColor = isDanger
        ? colorScheme.error
        : isSelected
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: isCollapsed ? Center(
              child: Icon(
                icon,
                size: 24,
                color: iconColor,
              ),
            ) : Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: iconColor,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: textColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Manual refresh catalog button
class _RefreshButton extends StatefulWidget {
  final bool isCollapsed;

  const _RefreshButton({required this.isCollapsed});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _isRefreshing = false;

  Future<void> _handleRefresh(BuildContext context) async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final catalogProvider = context.read<CatalogProvider>();
      final navProvider = context.read<NavigationProvider>();
      final outletId = navProvider.currentOutlet?.id;

      if (outletId != null) {
        await catalogProvider.loadCatalog(outletId);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Catalog refreshed successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to refresh: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: _isRefreshing ? null : () => _handleRefresh(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: widget.isCollapsed ? Center(
              child: _isRefreshing
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    )
                  : Icon(
                      Icons.refresh,
                      size: 24,
                      color: colorScheme.onSurfaceVariant,
                    ),
            ) : Row(
              children: [
                _isRefreshing
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                        ),
                      )
                    : Icon(
                        Icons.refresh,
                        size: 24,
                        color: colorScheme.onSurfaceVariant,
                      ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _isRefreshing ? 'Refreshing...' : 'Refresh Catalog',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
