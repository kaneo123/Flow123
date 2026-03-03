import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/screens/printer_settings_screen.dart';
import 'package:flowtill/theme.dart';
import 'package:flowtill/models/outlet.dart';
import 'package:flowtill/services/printer/printer_service.dart';
import 'package:flowtill/services/sync_service.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/services/local_storage_service.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/config/admin_config.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
              child: Row(
                children: [
                  Icon(
                    Icons.settings,
                    size: 32,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Settings',
                    style: context.textStyles.headlineMedium?.bold,
                  ),
                ],
              ),
            ),

            // Settings content
            Expanded(
              child: ListView(
                padding: AppSpacing.paddingLg,
                children: [
                  // Display Section
                  _SectionHeader(title: 'Display'),
                  const SizedBox(height: AppSpacing.md),
                  _SettingsCard(
                    child: Column(
                      children: [
                        _HideTopAppBarSetting(),
                        Divider(
                          height: 1,
                          color: colorScheme.outline.withValues(alpha: 0.1),
                        ),
                        _TableModeSetting(),
                        Divider(
                          height: 1,
                          color: colorScheme.outline.withValues(alpha: 0.1),
                        ),
                        _TableViewModeSetting(),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Stock Display Section
                  _SectionHeader(title: 'Stock Display'),
                  const SizedBox(height: AppSpacing.md),
                  _SettingsCard(
                    child: _QuantityWatchSetting(),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Specials & Promotions Section
                  _SectionHeader(title: 'Specials & Promotions'),
                  const SizedBox(height: AppSpacing.md),
                  _SettingsCard(
                    child: _HighlightSpecialsSetting(),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Service Charge Section
                  _SectionHeader(title: 'Service Charge'),
                  const SizedBox(height: AppSpacing.md),
                  _SettingsCard(
                    child: _ServiceChargeSettings(),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Loyalty Integration Section
                  _SectionHeader(title: 'Loyalty Integration'),
                  const SizedBox(height: AppSpacing.md),
                  _SettingsCard(
                    child: _DiscountCardSettings(),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Hardware Section
                  _SectionHeader(title: 'Hardware'),
                  const SizedBox(height: AppSpacing.md),
                  _SettingsCard(
                    child: Column(
                      children: [
                        _PrinterSettingsTile(),
                        if (Theme.of(context).platform == TargetPlatform.android) ...[
                          Divider(
                            height: 1,
                            color: colorScheme.outline.withValues(alpha: 0.1),
                          ),
                          _TestCashDrawerTile(),
                          Divider(
                            height: 1,
                            color: colorScheme.outline.withValues(alpha: 0.1),
                          ),
                          _TestPoundSymbolTile(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Trading Hours Section
                  _SectionHeader(title: 'Trading Day Settings'),
                  const SizedBox(height: AppSpacing.md),
                  _SettingsCard(
                    child: _OperatingHoursSettings(),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Sync Status Section (only on mobile/desktop, not web)
                  if (!kIsWeb) ...[
                    _SectionHeader(title: 'Data Sync'),
                    const SizedBox(height: AppSpacing.md),
                    _SettingsCard(
                      child: _SyncStatusPanel(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: context.textStyles.titleMedium?.semiBold.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HideTopAppBarSetting extends StatefulWidget {
  @override
  State<_HideTopAppBarSetting> createState() => _HideTopAppBarSettingState();
}

class _HideTopAppBarSettingState extends State<_HideTopAppBarSetting> {
  final _localStorageService = LocalStorageService();
  late bool _hideTopAppBar;

  @override
  void initState() {
    super.initState();
    _hideTopAppBar = _localStorageService.getHideTopAppBar();
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: AppSpacing.paddingLg,
      secondary: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(
          Icons.fullscreen,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        'Compact Mode (Device-Specific)',
        style: context.textStyles.titleMedium?.semiBold,
      ),
      subtitle: Text(
        'Hide the top app bar to maximize space for products. Staff name and logout button will appear in the status bar.',
        style: context.textStyles.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      value: _hideTopAppBar,
      onChanged: (bool value) async {
        await _localStorageService.saveHideTopAppBar(value);
        setState(() => _hideTopAppBar = value);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value 
                    ? 'Compact mode enabled. Top app bar hidden on this device.' 
                    : 'Compact mode disabled. Top app bar restored.',
              ),
              action: SnackBarAction(
                label: 'Reload',
                onPressed: () {
                  // Trigger a rebuild by popping and re-opening
                  Navigator.of(context).pop();
                },
              ),
            ),
          );
        }
      },
    );
  }
}

class _TableModeSetting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final outletProvider = context.watch<OutletProvider>();
    final outlet = outletProvider.currentOutlet;
    final tableModeEnabled = outlet?.settings?['table_mode_enabled'] == true;

    return SwitchListTile(
      contentPadding: AppSpacing.paddingLg,
      secondary: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(
          Icons.restaurant_menu,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        'Table Mode',
        style: context.textStyles.titleMedium?.semiBold,
      ),
      subtitle: Text(
        'Enable table service mode for restaurant operations',
        style: context.textStyles.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      value: tableModeEnabled,
      onChanged: (bool value) async {
        if (outlet == null) return;

        await outletProvider.updateOutletSetting('table_mode_enabled', value);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Table mode ${value ? 'enabled' : 'disabled'}',
              ),
            ),
          );
        }
      },
    );
  }
}

class _TableViewModeSetting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final outletProvider = context.watch<OutletProvider>();
    final outlet = outletProvider.currentOutlet;
    final currentMode = outlet?.settings?['tableViewMode'] as String? ?? 'list';

    return Padding(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.table_restaurant,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tables View Mode',
                      style: context.textStyles.titleMedium?.semiBold,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Choose how tables are displayed in the Till view',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'list',
                  label: Text('Grid'),
                  icon: Icon(Icons.grid_view, size: 16),
                ),
                ButtonSegment(
                  value: 'layout',
                  label: Text('Layout'),
                  icon: Icon(Icons.map, size: 16),
                ),
              ],
              selected: {currentMode},
              onSelectionChanged: (Set<String> newSelection) async {
                if (outlet == null) return;

                final newMode = newSelection.first;
                final updatedSettings = Map<String, dynamic>.from(outlet.settings ?? {});
                updatedSettings['tableViewMode'] = newMode;

                await outletProvider.updateOutlet(outlet.id, {'settings': updatedSettings});

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Tables view mode updated to ${newMode == 'list' ? 'Grid' : 'Layout'}',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityWatchSetting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final outletProvider = context.watch<OutletProvider>();
    final outlet = outletProvider.currentOutlet;
    final quantityWatchEnabled = outletProvider.quantityWatchEnabled;

    return SwitchListTile(
      contentPadding: AppSpacing.paddingLg,
      secondary: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(
          Icons.inventory_2,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        'Show Quantity Watch on Product Tiles',
        style: context.textStyles.titleMedium?.semiBold,
      ),
      subtitle: Text(
        'Show remaining stock on each button if inventory is linked',
        style: context.textStyles.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      value: quantityWatchEnabled,
      onChanged: (bool value) async {
        if (outlet == null) return;

        await outletProvider.updateOutletSetting('quantity_watch_enabled', value);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Quantity Watch ${value ? 'enabled' : 'disabled'}',
              ),
            ),
          );
        }
      },
    );
  }
}

class _HighlightSpecialsSetting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final outletProvider = context.watch<OutletProvider>();
    final settings = outletProvider.outletSettings;
    final highlightEnabled = settings?.highlightSpecials ?? true;

    return SwitchListTile(
      contentPadding: AppSpacing.paddingLg,
      secondary: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(
          Icons.star,
          color: Theme.of(context).colorScheme.onTertiaryContainer,
        ),
      ),
      title: Text(
        'Highlight specials with a star icon',
        style: context.textStyles.titleMedium?.semiBold,
      ),
      subtitle: Text(
        'Show a star badge on product tiles for items in today\'s specials',
        style: context.textStyles.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      value: highlightEnabled,
      onChanged: (bool value) async {
        if (settings == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot update settings. Please try again.'),
            ),
          );
          return;
        }

        final success = await outletProvider.updateSettings({
          'highlight_specials': value,
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Special highlighting ${value ? 'enabled' : 'disabled'}'
                    : 'Failed to update setting',
              ),
            ),
          );
        }
      },
    );
  }
}

class _PrinterSettingsTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: AppSpacing.paddingLg,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(
          Icons.print,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        'Printer Configuration',
        style: context.textStyles.titleMedium?.semiBold,
      ),
      subtitle: Text(
        'Configure receipt printers and order ticket routing',
        style: context.textStyles.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PrinterSettingsScreen(),
          ),
        );
      },
    );
  }
}

class _ServiceChargeSettings extends StatefulWidget {
  @override
  State<_ServiceChargeSettings> createState() => _ServiceChargeSettingsState();
}

class _ServiceChargeSettingsState extends State<_ServiceChargeSettings> {
  final TextEditingController _percentController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _percentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outletProvider = context.watch<OutletProvider>();
    final outlet = outletProvider.currentOutlet;
    
    if (outlet == null) {
      return const Padding(
        padding: AppSpacing.paddingLg,
        child: Text('No outlet selected'),
      );
    }

    // Update controller when outlet changes
    if (_percentController.text.isEmpty && outlet.serviceChargePercent > 0) {
      _percentController.text = outlet.serviceChargePercent.toStringAsFixed(1);
    }

    return Column(
      children: [
        SwitchListTile(
          contentPadding: AppSpacing.paddingLg,
          secondary: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.percent,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
          ),
          title: Text(
            'Enable Service Charge',
            style: context.textStyles.titleMedium?.semiBold,
          ),
          subtitle: Text(
            'Apply service charge to all orders at this outlet',
            style: context.textStyles.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          value: outlet.enableServiceCharge,
          onChanged: _isSaving ? null : (bool value) async {
            debugPrint('🔄 Settings: Toggling service charge enabled');
            debugPrint('   Outlet ID: ${outlet.id}');
            debugPrint('   New value: $value');
            
            setState(() => _isSaving = true);
            
            final success = await outletProvider.updateOutlet(outlet.id, {
              'enable_service_charge': value,
            });
            
            debugPrint('   Update result: ${success ? "SUCCESS" : "FAILED"}');

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Service charge ${value ? 'enabled' : 'disabled'}'
                        : 'Failed to update service charge setting',
                  ),
                  backgroundColor: success ? null : Colors.red,
                ),
              );
            }
            
            setState(() => _isSaving = false);
          },
        ),
        if (outlet.enableServiceCharge) ...[
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
          Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service Charge Percentage',
                  style: context.textStyles.titleSmall?.semiBold,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _percentController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        enabled: !_isSaving,
                        decoration: InputDecoration(
                          hintText: '10.0',
                          suffixText: '%',
                          helperText: 'Recommended: 10-12.5%. Maximum: 30%',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    ElevatedButton(
                      onPressed: _isSaving ? null : () async {
                        final value = double.tryParse(_percentController.text) ?? 0.0;
                        
                        debugPrint('💾 Settings: Saving service charge percentage');
                        debugPrint('   Outlet ID: ${outlet.id}');
                        debugPrint('   Input text: "${_percentController.text}"');
                        debugPrint('   Parsed value: $value');
                        
                        if (value < 0 || value > 30) {
                          debugPrint('   ❌ VALIDATION FAILED: Value out of range (0-30)');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Service charge must be between 0% and 30%'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setState(() => _isSaving = true);
                        
                        final success = await outletProvider.updateOutlet(outlet.id, {
                          'service_charge_percent': value,
                        });
                        
                        debugPrint('   Update result: ${success ? "SUCCESS" : "FAILED"}');

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Service charge set to ${value.toStringAsFixed(1)}%'
                                    : 'Failed to save service charge percentage',
                              ),
                              backgroundColor: success ? null : Colors.red,
                            ),
                          );
                        }
                        
                        setState(() => _isSaving = false);
                      },
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OperatingHoursSettings extends StatefulWidget {
  @override
  State<_OperatingHoursSettings> createState() => _OperatingHoursSettingsState();
}

class _OperatingHoursSettingsState extends State<_OperatingHoursSettings> {
  final _openController = TextEditingController();
  final _closeController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _openController.dispose();
    _closeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outletProvider = context.watch<OutletProvider>();
    final settings = outletProvider.outletSettings;

    if (settings == null) {
      return const Padding(
        padding: AppSpacing.paddingLg,
        child: Text('No outlet settings available'),
      );
    }

    // Update controllers when settings change
    if (_openController.text.isEmpty && settings.operatingHoursOpen != null) {
      _openController.text = settings.operatingHoursOpen!;
    }
    if (_closeController.text.isEmpty && settings.operatingHoursClose != null) {
      _closeController.text = settings.operatingHoursClose!;
    }

    return Padding(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.access_time,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operating Hours',
                      style: context.textStyles.titleMedium?.semiBold,
                    ),
                    Text(
                      'Define when trading days begin and end',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Info banner
          Container(
            padding: AppSpacing.paddingSm,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Closing time can pass midnight (e.g., 02:00 for late-night venues)',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Opening Time
          Text(
            'Opening Time',
            style: context.textStyles.labelLarge?.semiBold,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _openController,
            enabled: !_isSaving,
            decoration: InputDecoration(
              hintText: '10:00',
              helperText: 'Format: HH:mm (24-hour)',
              prefixIcon: const Icon(Icons.wb_sunny),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: AppSpacing.md),

          // Closing Time
          Text(
            'Closing Time',
            style: context.textStyles.labelLarge?.semiBold,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _closeController,
            enabled: !_isSaving,
            decoration: InputDecoration(
              hintText: '02:00',
              helperText: 'Format: HH:mm (24-hour, can be next day)',
              prefixIcon: const Icon(Icons.nights_stay),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : () async {
                final openTime = _openController.text.trim();
                final closeTime = _closeController.text.trim();

                // Validate time format (HH:mm)
                final timeRegex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
                
                if (openTime.isNotEmpty && !timeRegex.hasMatch(openTime)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid opening time format. Use HH:mm (e.g., 10:00)'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (closeTime.isNotEmpty && !timeRegex.hasMatch(closeTime)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid closing time format. Use HH:mm (e.g., 02:00)'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState(() => _isSaving = true);

                final success = await outletProvider.updateSettings({
                  'operating_hours_open': openTime.isEmpty ? null : openTime,
                  'operating_hours_close': closeTime.isEmpty ? null : closeTime,
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Operating hours updated'
                            : 'Failed to update operating hours',
                      ),
                      backgroundColor: success ? null : Colors.red,
                    ),
                  );
                }

                setState(() => _isSaving = false);
              },
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Operating Hours'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestCashDrawerTile extends StatefulWidget {
  @override
  State<_TestCashDrawerTile> createState() => _TestCashDrawerTileState();
}

class _TestCashDrawerTileState extends State<_TestCashDrawerTile> {
  bool _isOpening = false;

  Future<void> _testCashDrawer() async {
    setState(() => _isOpening = true);

    try {
      await PrinterService.instance.openCashDrawer();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Cash drawer command sent successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Cash drawer test failed: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.toString().replaceFirst('Exception: ', ''),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: AppSpacing.paddingLg,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(
          Icons.point_of_sale,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        'Test Cash Drawer',
        style: context.textStyles.titleMedium?.semiBold,
      ),
      subtitle: Text(
        'Send open command to cash drawer via receipt printer',
        style: context.textStyles.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: _isOpening
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.play_arrow,
              color: Theme.of(context).colorScheme.primary,
            ),
      onTap: _isOpening ? null : _testCashDrawer,
    );
  }
}

class _TestPoundSymbolTile extends StatefulWidget {
  @override
  State<_TestPoundSymbolTile> createState() => _TestPoundSymbolTileState();
}

class _TestPoundSymbolTileState extends State<_TestPoundSymbolTile> {
  bool _isPrinting = false;

  Future<void> _testPoundSymbol() async {
    setState(() => _isPrinting = true);

    try {
      await PrinterService.instance.testPoundSymbolPrint();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('£ symbol test printed. Check if "£" displays correctly!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Pound symbol test failed: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.toString().replaceFirst('Exception: ', ''),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: AppSpacing.paddingLg,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(
          Icons.currency_pound,
          color: Theme.of(context).colorScheme.onTertiaryContainer,
        ),
      ),
      title: Text(
        'Test £ Symbol Print',
        style: context.textStyles.titleMedium?.semiBold,
      ),
      subtitle: Text(
        'Verify pound symbol prints correctly (not as "u")',
        style: context.textStyles.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: _isPrinting
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.print,
              color: Theme.of(context).colorScheme.primary,
            ),
      onTap: _isPrinting ? null : _testPoundSymbol,
    );
  }
}

/// Sync Status Panel - shows connection status, pending sync items, and manual sync button
class _SyncStatusPanel extends StatefulWidget {
  @override
  State<_SyncStatusPanel> createState() => _SyncStatusPanelState();
}

class _SyncStatusPanelState extends State<_SyncStatusPanel> {
  final _syncService = SyncService();
  final _connectionService = ConnectionService();
  final _db = AppDatabase.instance;
  
  int _pendingOutboxCount = 0;
  int _localOrdersCount = 0;
  bool _isOnline = true;
  bool _isSyncing = false;
  DateTime? _lastSyncAttempt;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _loadSyncStatus();
    
    // Listen to connection changes
    _connectionService.connectionStream.listen((isOnline) {
      if (mounted) {
        setState(() => _isOnline = isOnline);
      }
    });
    
    // Listen to sync status changes
    _syncService.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isSyncing = status == SyncStatus.syncing;
          if (status == SyncStatus.success || status == SyncStatus.error) {
            _lastSyncAttempt = DateTime.now();
            _syncError = status == SyncStatus.error ? 'Sync failed' : null;
          }
        });
        // Reload counts after sync completes
        if (status == SyncStatus.success) {
          _loadSyncStatus();
        }
      }
    });
  }

  Future<void> _loadSyncStatus() async {
    try {
      final db = await _db.database;
      
      // Count pending outbox items
      final outboxResult = await db.rawQuery('SELECT COUNT(*) as count FROM outbox_queue');
      final outboxCount = (outboxResult.first['count'] as int?) ?? 0;
      
      // Count local orders
      final ordersResult = await db.rawQuery('SELECT COUNT(*) as count FROM orders WHERE synced_at IS NULL');
      final ordersCount = (ordersResult.first['count'] as int?) ?? 0;
      
      // Get connection status
      final isOnline = _connectionService.isOnline;
      
      if (mounted) {
        setState(() {
          _pendingOutboxCount = outboxCount;
          _localOrdersCount = ordersCount;
          _isOnline = isOnline;
        });
      }
      
      debugPrint('📊 Sync Status Loaded:');
      debugPrint('   Pending outbox items: $outboxCount');
      debugPrint('   Unsynced orders: $ordersCount');
      debugPrint('   Connection: ${isOnline ? "Online" : "Offline"}');
    } catch (e) {
      debugPrint('❌ Error loading sync status: $e');
    }
  }

  Future<void> _forceSyncNow() async {
    if (_isSyncing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync already in progress')),
      );
      return;
    }
    
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot sync: Device is offline'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);
    
    try {
      debugPrint('🔄 Manual sync triggered by user');
      final outletProvider = context.read<OutletProvider>();
      final outletId = outletProvider.currentOutlet?.id;
      
      await _syncService.forceSyncNow(outletId);
      
      // Wait a moment for sync to complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Reload counts
      await _loadSyncStatus();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(_pendingOutboxCount == 0 
                    ? 'Sync complete! All data uploaded.' 
                    : 'Sync complete! $_pendingOutboxCount items still pending.'),
              ],
            ),
            backgroundColor: _pendingOutboxCount == 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Manual sync failed: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isOnline 
                      ? colorScheme.primaryContainer 
                      : colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  _isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: _isOnline 
                      ? colorScheme.onPrimaryContainer 
                      : colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Sync Status',
                      style: context.textStyles.titleMedium?.semiBold,
                    ),
                    Text(
                      _isOnline ? 'Connected & Syncing' : 'Offline Mode',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: _isOnline 
                            ? colorScheme.primary 
                            : colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Stats Grid
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.upload,
                  label: 'Pending Sync',
                  value: '$_pendingOutboxCount',
                  color: _pendingOutboxCount > 0 ? Colors.orange : Colors.green,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatCard(
                  icon: Icons.receipt_long,
                  label: 'Local Orders',
                  value: '$_localOrdersCount',
                  color: _localOrdersCount > 0 ? Colors.blue : Colors.grey,
                ),
              ),
            ],
          ),
          
          // Warning banner if items pending
          if (_pendingOutboxCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: AppSpacing.paddingSm,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, size: 16, color: Colors.orange),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '$_pendingOutboxCount transaction${_pendingOutboxCount == 1 ? '' : 's'} waiting to sync to cloud',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Last sync time
          if (_lastSyncAttempt != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  _syncError != null ? Icons.error : Icons.check_circle,
                  size: 14,
                  color: _syncError != null ? Colors.red : Colors.green,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Last sync: ${_formatLastSync(_lastSyncAttempt!)}',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_syncError != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '($_syncError)',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ],
          
          const SizedBox(height: AppSpacing.lg),
          
          // Force Sync Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSyncing ? null : _forceSyncNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync),
              label: Text(_isSyncing ? 'Syncing...' : 'Force Sync Now'),
            ),
          ),
          
          const SizedBox(height: AppSpacing.sm),
          
          // Help text
          Text(
            'Syncs local transactions to Supabase. Automatic sync occurs every 2 minutes when online.',
            style: context.textStyles.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatLastSync(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

/// Small stat card widget for sync panel
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: context.textStyles.headlineSmall?.bold.copyWith(color: color),
          ),
          Text(
            label,
            style: context.textStyles.bodySmall?.copyWith(
              color: color.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Discount Card settings widget
class _DiscountCardSettings extends StatefulWidget {
  @override
  State<_DiscountCardSettings> createState() => _DiscountCardSettingsState();
}

class _DiscountCardSettingsState extends State<_DiscountCardSettings> {
  final _restaurantIdController = TextEditingController();
  final _pointsPerPoundController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _restaurantIdController.dispose();
    _pointsPerPoundController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings(OutletProvider outletProvider) async {
    final settings = outletProvider.currentSettings;
    if (settings == null) return;

    final newPointsPerPound = double.tryParse(_pointsPerPoundController.text) ?? 1.0;
    final currentPointsPerPound = settings.loyaltyPointsPerPound ?? 1.0;
    
    // Check if points per pound has changed - if so, require password
    if ((newPointsPerPound - currentPointsPerPound).abs() > 0.001) {
      final passwordCorrect = await _showPasswordDialog();
      if (!passwordCorrect) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Incorrect password. Points per pound not updated.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final restaurantId = _restaurantIdController.text.trim();

      // Update settings using OutletProvider
      final success = await outletProvider.updateSettings({
        'loyalty_discount_card_restaurant_id': restaurantId.isEmpty ? null : restaurantId,
        'loyalty_points_per_pound': newPointsPerPound.clamp(0.0, 10.0),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
              ? '✅ Loyalty settings saved successfully'
              : 'Failed to save settings'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// Shows password dialog for loyalty points authorization
  /// Returns true if password is correct, false otherwise
  Future<bool> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    bool isPasswordCorrect = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock, color: Colors.orange),
              SizedBox(width: 12),
              Text('Authorization Required'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Changing loyalty points requires admin authorization.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Admin Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.password),
                ),
                onSubmitted: (value) {
                  isPasswordCorrect = AdminConfig.validateLoyaltyPassword(value);
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                isPasswordCorrect = AdminConfig.validateLoyaltyPassword(passwordController.text);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    passwordController.dispose();
    return isPasswordCorrect;
  }

  @override
  Widget build(BuildContext context) {
    final outletProvider = context.watch<OutletProvider>();
    final settings = outletProvider.currentSettings;

    if (settings == null) {
      return const Padding(
        padding: AppSpacing.paddingLg,
        child: Text('No outlet settings loaded'),
      );
    }

    // Initialize controllers with current values
    if (_restaurantIdController.text.isEmpty && settings.loyaltyDiscountCardRestaurantId != null) {
      _restaurantIdController.text = settings.loyaltyDiscountCardRestaurantId!;
    }
    if (_pointsPerPoundController.text.isEmpty) {
      _pointsPerPoundController.text = (settings.loyaltyPointsPerPound ?? 1.0).toString();
    }

    return Padding(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.card_giftcard,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loyalty & Discount Management',
                      style: context.textStyles.titleMedium?.semiBold,
                    ),
                    Text(
                      'Configure loyalty points and rewards integration',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Enable/Disable Loyalty
          _SettingRow(
            icon: Icons.loyalty,
            title: 'Enable Loyalty Program',
            subtitle: 'Award points for customer purchases',
            trailing: Switch(
              value: settings.loyaltyEnabled ?? true,
              onChanged: _isSaving ? null : (value) async {
                setState(() => _isSaving = true);
                await outletProvider.updateSettings({
                  'loyalty_enabled': value,
                });
                setState(() => _isSaving = false);
              },
            ),
          ),

          if (settings.loyaltyEnabled ?? true) ...[
            Divider(
              height: 32,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),

            // Points Per Pound
            Text(
              'Points Per Pound',
              style: context.textStyles.labelLarge?.semiBold,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Set how many points customers earn per £1 spent',
              style: context.textStyles.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _pointsPerPoundController,
              enabled: !_isSaving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '1.0',
                helperText: 'Typical: 0.5 to 2.0 points per £1',
                prefixIcon: const Icon(Icons.currency_pound),
                suffixText: 'points/£',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Double Points Mode
            _SettingRow(
              icon: Icons.auto_awesome,
              title: 'Double Points Mode',
              subtitle: 'Award 2x points on all purchases',
              trailing: Switch(
                value: settings.loyaltyDoublePointsEnabled ?? false,
                onChanged: _isSaving ? null : (value) async {
                  setState(() => _isSaving = true);
                  await outletProvider.updateSettings({
                    'loyalty_double_points_enabled': value,
                  });
                  setState(() => _isSaving = false);
                },
              ),
            ),

            Divider(
              height: 32,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),

            // Restaurant ID Field
            Text(
              'Discount Card Restaurant ID',
              style: context.textStyles.labelLarge?.semiBold,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Find this in your Discount Card (Oliver) dashboard',
              style: context.textStyles.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _restaurantIdController,
              enabled: !_isSaving,
              enableInteractiveSelection: true,
              autocorrect: false,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: 'e.g., 68ccdacc4c19b2344d711c20',
                prefixIcon: const Icon(Icons.store),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _saveSettings(outletProvider),
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Loyalty Settings'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyles.bodyMedium?.semiBold,
              ),
              Text(
                subtitle,
                style: context.textStyles.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}
