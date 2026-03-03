import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flowtill/models/printer.dart' as models;
import 'package:flowtill/services/printer/printer_service.dart';
import 'package:flowtill/services/printer/printer_helper.dart';
import 'package:flowtill/providers/outlet_provider.dart';
import 'package:flowtill/theme.dart';
import 'package:flowtill/screens/printer_settings_screen_receipt_widget.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/flutter_pos_printer_platform_image_3_sdt.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterService _printerService = PrinterService.instance;
  bool _isLoading = false;
  String _deviceName = '';
  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    _loadPrinters();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    final deviceName = await _printerService.getDeviceName();
    final deviceId = await _printerService.getDeviceId();
    setState(() {
      _deviceName = deviceName;
      _deviceId = deviceId;
    });
  }

  Future<void> _loadPrinters() async {
    final outletProvider = context.read<OutletProvider>();
    final currentOutlet = outletProvider.currentOutlet;
    
    if (currentOutlet == null) {
      debugPrint('⚠️ No current outlet to load printers');
      return;
    }

    setState(() => _isLoading = true);
    await _printerService.loadPrinters(currentOutlet.id);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final allPrinters = [
      ..._printerService.getReceiptPrinters(),
      ..._printerService.getKitchenPrinters(),
      ..._printerService.getBarPrinters(),
    ];

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
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Icon(
                    Icons.print,
                    size: 32,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Printer Setup',
                    style: context.textStyles.headlineMedium?.bold,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isLoading ? null : _loadPrinters,
                  ),
                ],
              ),
            ),

            // Content
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (allPrinters.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: AppSpacing.paddingXl,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.print_disabled,
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'No Printers Found',
                          style: context.textStyles.headlineSmall?.bold,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Add printers in your Supabase "printers" table first.\n\n'
                          'Each printer represents a logical printer (Kitchen, Bar, Receipt, etc.) '
                          'that you can link to physical hardware using this setup wizard.',
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: AppSpacing.paddingLg,
                  children: [
                    // Device Info Card
                    if (_deviceName.isNotEmpty) ...[
                      _InfoCard(
                        icon: Icons.devices,
                        title: 'This Device',
                        message: '$_deviceName\n\nPrinter hardware configurations are stored locally on each device. '
                            'You can configure different physical printers for the same logical printer on different devices.',
                        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                        textColor: colorScheme.onSurface,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    // Platform notice for web
                    if (kIsWeb) ...[
                      _InfoCard(
                        icon: Icons.info_outline,
                        title: 'Platform Notice',
                        message: 'Hardware printer configuration requires Android or Windows. Not available in web preview.',
                        color: colorScheme.errorContainer,
                        textColor: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    // Printer Cards (Wizard Flow)
                    Text(
                      'Configure Your Printers',
                      style: context.textStyles.titleLarge?.bold,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Link each logical printer to a physical device on this terminal (USB, Bluetooth, or Network).',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    ...allPrinters.map((printer) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: _PrinterWizardCard(
                        printer: printer,
                        onUpdated: _loadPrinters,
                      ),
                    )),

                    const SizedBox(height: AppSpacing.xl),

                    // Order Tickets Settings
                    const _OrderTicketsSettings(),

                    const SizedBox(height: AppSpacing.xl),

                    // Order Ticket Font Sizes
                    const _OrderTicketFontSizes(),

                    const SizedBox(height: AppSpacing.xl),

                    // Receipt Formatting Settings
                    const ReceiptFormattingSettings(),

                    const SizedBox(height: AppSpacing.xl),

                    // Setup Guide
                    _InfoCard(
                      icon: Icons.help_outline,
                      title: 'How Printer Routing Works',
                      message: 
                          'Device-Specific Configuration:\n'
                          '• Hardware settings are stored locally on each device\n'
                          '• Different devices can use different physical printers\n'
                          '• Logical printer definitions are shared across your account\n\n'
                          'Order Tickets (Order Away):\n'
                          '• Items are routed by products.printer_id\n'
                          '• Multiple products can share the same printer\n'
                          '• Only enabled printers will print\n\n'
                          'Receipt Printing:\n'
                          '• Uses the receipt-type printer marked as default\n'
                          '• Prints after successful payment\n'
                          '• Shows all items with prices',
                      color: colorScheme.surfaceContainerHigh,
                      textColor: colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Wizard-based card for each printer
class _PrinterWizardCard extends StatefulWidget {
  final models.Printer printer;
  final Future<void> Function() onUpdated;

  const _PrinterWizardCard({
    required this.printer,
    required this.onUpdated,
  });

  @override
  State<_PrinterWizardCard> createState() => _PrinterWizardCardState();
}

class _PrinterWizardCardState extends State<_PrinterWizardCard> {
  bool _isExpanded = false;
  String? _selectedConnectionType;
  bool _isScanning = false;
  List<PrinterDeviceInfo> _scannedDevices = [];
  String? _manualIp;
  int? _manualPort;
  bool _hasHardwareLinked = false;
  String _hardwareStatus = 'Loading...';
  String _connectionType = 'other';

  @override
  void initState() {
    super.initState();
    _loadHardwareConfig();
  }

  Future<void> _loadHardwareConfig() async {
    final config = await PrinterService.instance.getHardwareConfig(widget.printer.id);
    setState(() {
      _hasHardwareLinked = config != null;
      _connectionType = config?.connectionType ?? 'other';
      if (config == null) {
        _hardwareStatus = 'Not configured on this device';
      } else {
        switch (config.connectionType) {
          case 'usb':
            _hardwareStatus = 'USB: ${config.hardwareName ?? 'Unknown Device'}';
            break;
          case 'bluetooth':
            _hardwareStatus = 'Bluetooth: ${config.hardwareName ?? 'Unknown Device'}';
            break;
          case 'network':
            _hardwareStatus = 'Network: ${config.ipAddress}:${config.port ?? 9100}';
            break;
          default:
            _hardwareStatus = 'Unknown connection type';
        }
      }
    });
  }

  IconData get _connectionIcon {
    switch (_connectionType) {
      case 'usb':
        return Icons.usb;
      case 'bluetooth':
        return Icons.bluetooth;
      case 'network':
        return Icons.network_wifi;
      default:
        return Icons.devices;
    }
  }

  Color _getTypeColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (widget.printer.type) {
      case 'receipt':
        return colorScheme.primaryContainer;
      case 'kitchen':
        return colorScheme.tertiaryContainer;
      case 'bar':
        return colorScheme.secondaryContainer;
      default:
        return colorScheme.surfaceContainerHigh;
    }
  }

  Color _getTypeTextColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (widget.printer.type) {
      case 'receipt':
        return colorScheme.onPrimaryContainer;
      case 'kitchen':
        return colorScheme.onTertiaryContainer;
      case 'bar':
        return colorScheme.onSecondaryContainer;
      default:
        return colorScheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: _hasHardwareLinked 
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outline.withValues(alpha: 0.2),
          width: _hasHardwareLinked ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // STEP 1: Details
          ListTile(
            contentPadding: AppSpacing.paddingLg,
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _getTypeColor(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                widget.printer.type == 'receipt' 
                    ? Icons.receipt_long 
                    : widget.printer.type == 'kitchen'
                        ? Icons.restaurant
                        : Icons.local_bar,
                size: 28,
                color: _getTypeTextColor(context),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.printer.name,
                    style: context.textStyles.titleLarge?.bold,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getTypeColor(context),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    widget.printer.type.toUpperCase(),
                    style: context.textStyles.labelSmall?.bold.copyWith(
                      color: _getTypeTextColor(context),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    _hasHardwareLinked ? Icons.check_circle : Icons.warning,
                    size: 16,
                    color: _hasHardwareLinked ? Colors.green : colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _hardwareStatus,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: _hasHardwareLinked 
                            ? Colors.green 
                            : colorScheme.error,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
            trailing: _hasHardwareLinked
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _connectionIcon,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon: const Icon(Icons.print),
                        tooltip: 'Test Print',
                        onPressed: () => _testPrint(),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          if (value == 'reconfigure') {
                            setState(() => _isExpanded = true);
                          } else if (value == 'unlink') {
                            await _unlinkHardware();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'reconfigure',
                            child: Row(
                              children: [
                                Icon(Icons.settings),
                                SizedBox(width: 8),
                                Text('Reconfigure'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'unlink',
                            child: Row(
                              children: [
                                Icon(Icons.link_off, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Unlink Hardware', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : IconButton(
                    icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  ),
          ),

          // Configuration Wizard (when expanded)
          if (_isExpanded) ...[
            Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),
            _buildWizardContent(context),
          ],
        ],
      ),
    );
  }

  Widget _buildWizardContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (kIsWeb) {
      return Padding(
        padding: AppSpacing.paddingLg,
        child: Text(
          'Printer configuration is only available on Android or Windows.',
          style: context.textStyles.bodyMedium?.copyWith(
            color: colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STEP 2: Select Connection Type
          Text(
            'Select Connection Type',
            style: context.textStyles.titleMedium?.bold,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _ConnectionTypeButton(
                  icon: Icons.usb,
                  label: 'USB',
                  isSelected: _selectedConnectionType == 'usb',
                  onTap: () => setState(() {
                    _selectedConnectionType = 'usb';
                    _scannedDevices = [];
                  }),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ConnectionTypeButton(
                  icon: Icons.bluetooth,
                  label: 'Bluetooth',
                  isSelected: _selectedConnectionType == 'bluetooth',
                  onTap: () => setState(() {
                    _selectedConnectionType = 'bluetooth';
                    _scannedDevices = [];
                  }),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ConnectionTypeButton(
                  icon: Icons.network_wifi,
                  label: 'Network',
                  isSelected: _selectedConnectionType == 'network',
                  onTap: () => setState(() {
                    _selectedConnectionType = 'network';
                    _scannedDevices = [];
                  }),
                ),
              ),
            ],
          ),

          // STEP 3: Scan & Select Device (or enter network details)
          if (_selectedConnectionType != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),
            const SizedBox(height: AppSpacing.lg),

            if (_selectedConnectionType == 'network')
              _buildNetworkConfig(context)
            else
              _buildDeviceScanner(context),
          ],
        ],
      ),
    );
  }

  Widget _buildNetworkConfig(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Network Printer Configuration',
          style: context.textStyles.titleMedium?.bold,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          decoration: InputDecoration(
            labelText: 'IP Address',
            hintText: '192.168.1.100',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.computer),
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) => _manualIp = value,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          decoration: InputDecoration(
            labelText: 'Port (default: 9100)',
            hintText: '9100',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.settings_ethernet),
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) => _manualPort = int.tryParse(value),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveNetworkPrinter,
            icon: const Icon(Icons.save),
            label: const Text('Save & Test Print'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceScanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scanType = _selectedConnectionType == 'usb' ? 'USB' : 'Bluetooth';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scan for $scanType Printers',
          style: context.textStyles.titleMedium?.bold,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isScanning ? null : _scanDevices,
            icon: _isScanning 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_selectedConnectionType == 'usb' ? Icons.usb : Icons.bluetooth),
            label: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),

        if (_scannedDevices.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Found ${_scannedDevices.length} device(s):',
            style: context.textStyles.titleSmall?.bold,
          ),
          const SizedBox(height: AppSpacing.md),
          ..._scannedDevices.map((device) => _buildDeviceTile(context, device)),
        ],
      ],
    );
  }

  Widget _buildDeviceTile(BuildContext context, PrinterDeviceInfo device) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: Icon(
          device.type == PrinterType.usb ? Icons.usb : Icons.bluetooth,
          color: colorScheme.primary,
        ),
        title: Text(
          device.name ?? 'Unknown Device',
          style: context.textStyles.titleSmall?.semiBold,
        ),
        subtitle: Text(
          device.address ?? 'No address',
          style: context.textStyles.bodySmall,
        ),
        trailing: const Icon(Icons.arrow_forward, size: 20),
        onTap: () => _selectDevice(device),
      ),
    );
  }

  Future<void> _scanDevices() async {
    setState(() {
      _isScanning = true;
      _scannedDevices = [];
    });

    try {
      final type = _selectedConnectionType == 'usb' ? PrinterType.usb : PrinterType.bluetooth;
      final devices = await PrinterHelper.discoverPrinters(
        type,
        timeout: const Duration(seconds: 8),
      );
      
      setState(() {
        _scannedDevices = devices;
        _isScanning = false;
      });

      if (devices.isEmpty && mounted) {
        _showDialog('No Devices Found', 'No $_selectedConnectionType printers were detected.');
      }
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        _showDialog('Scan Failed', 'Failed to scan for devices:\n\n$e');
      }
    }
  }

  Future<void> _selectDevice(PrinterDeviceInfo device) async {
    try {
      // Save hardware link to Supabase
      await PrinterService.instance.saveHardwareLink(
        printerId: widget.printer.id,
        connectionType: _selectedConnectionType!,
        hardwareVendorId: device.vendorId,
        hardwareProductId: device.productId,
        hardwareAddress: device.address,
        hardwareName: device.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${widget.printer.name} linked to ${device.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload and close wizard
      setState(() {
        _isExpanded = false;
        _selectedConnectionType = null;
        _scannedDevices = [];
      });
      await widget.onUpdated();
      await _loadHardwareConfig();

      // STEP 4: Test Print
      await _testPrint();
    } catch (e) {
      if (mounted) {
        _showDialog('Configuration Failed', 'Failed to configure printer:\n\n$e');
      }
    }
  }

  Future<void> _saveNetworkPrinter() async {
    if (_manualIp == null || _manualIp!.isEmpty) {
      _showDialog('Invalid Input', 'Please enter an IP address.');
      return;
    }

    try {
      await PrinterService.instance.saveHardwareLink(
        printerId: widget.printer.id,
        connectionType: 'network',
        ipAddress: _manualIp,
        port: _manualPort ?? 9100,
        hardwareName: 'Network Printer ($_manualIp)',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${widget.printer.name} configured for network printing'),
            backgroundColor: Colors.green,
          ),
        );
      }

      setState(() {
        _isExpanded = false;
        _selectedConnectionType = null;
      });
      await widget.onUpdated();
      await _loadHardwareConfig();

      // Test print
      await _testPrint();
    } catch (e) {
      if (mounted) {
        _showDialog('Configuration Failed', 'Failed to configure network printer:\n\n$e');
      }
    }
  }

  Future<void> _testPrint() async {
    try {
      await PrinterService.instance.testPrint(widget.printer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Test print sent to ${widget.printer.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showDialog('Print Failed', 'Failed to print test:\n\n$e');
      }
    }
  }

  Future<void> _unlinkHardware() async {
    // Confirm action
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Hardware'),
        content: Text(
          'Are you sure you want to unlink the hardware configuration for ${widget.printer.name} on this device?\n\n'
          'The logical printer will remain in your account, but you will need to reconfigure the physical hardware.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await PrinterService.instance.removeHardwareConfig(widget.printer.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Hardware unlinked for ${widget.printer.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadHardwareConfig();
      await widget.onUpdated();
    } catch (e) {
      if (mounted) {
        _showDialog('Error', 'Failed to unlink hardware:\n\n$e');
      }
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConnectionTypeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? colorScheme.primaryContainer 
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected 
                ? colorScheme.primary 
                : colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? colorScheme.onPrimaryContainer 
                  : colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: context.textStyles.labelMedium?.copyWith(
                color: isSelected 
                    ? colorScheme.onPrimaryContainer 
                    : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final Color textColor;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: context.textStyles.titleMedium?.bold.copyWith(color: textColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: context.textStyles.bodyMedium?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _OrderTicketsSettings extends StatefulWidget {
  const _OrderTicketsSettings();

  @override
  State<_OrderTicketsSettings> createState() => _OrderTicketsSettingsState();
}

class _OrderTicketsSettingsState extends State<_OrderTicketsSettings> {
  bool _isSaving = false;

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() => _isSaving = true);
    
    final outletProvider = context.read<OutletProvider>();
    final success = await outletProvider.updateSettings({key: value});
    
    setState(() => _isSaving = false);
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Settings saved successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to save settings'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final outletProvider = context.watch<OutletProvider>();
    final settings = outletProvider.currentSettings;

    if (settings == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: AppSpacing.paddingLg,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Order Tickets',
                  style: context.textStyles.titleLarge?.bold,
                ),
              ],
            ),
          ),

          // Settings
          Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configure printing behavior when pressing "Order Away" button',
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Toggle: Print order tickets
                SwitchListTile(
                  value: settings.printOrderTicketsOnOrderAway,
                  onChanged: _isSaving 
                      ? null 
                      : (value) => _updateSetting('print_order_tickets_on_order_away', value),
                  title: Text(
                    'Print order tickets when pressing Order Away',
                    style: context.textStyles.bodyLarge?.bold,
                  ),
                  subtitle: Text(
                    settings.printOrderTicketsOnOrderAway 
                        ? 'Kitchen/bar tickets will be printed automatically'
                        : 'Order Away will only park the order without printing',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: AppSpacing.md),

                // Copies stepper
                Opacity(
                  opacity: settings.printOrderTicketsOnOrderAway ? 1.0 : 0.5,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Copies per order',
                              style: context.textStyles.bodyLarge?.bold,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Number of ticket copies to print for each printer',
                              style: context.textStyles.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      // Stepper
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: (settings.printOrderTicketsOnOrderAway && 
                                         settings.orderTicketCopies > 1 && 
                                         !_isSaving)
                                  ? () => _updateSetting(
                                        'order_ticket_copies',
                                        settings.orderTicketCopies - 1,
                                      )
                                  : null,
                            ),
                            Container(
                              width: 40,
                              alignment: Alignment.center,
                              child: Text(
                                '${settings.orderTicketCopies}',
                                style: context.textStyles.titleLarge?.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: (settings.printOrderTicketsOnOrderAway && 
                                         settings.orderTicketCopies < 5 && 
                                         !_isSaving)
                                  ? () => _updateSetting(
                                        'order_ticket_copies',
                                        settings.orderTicketCopies + 1,
                                      )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Enabled Printers Section
                Opacity(
                  opacity: settings.printOrderTicketsOnOrderAway ? 1.0 : 0.5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enabled Printers',
                        style: context.textStyles.bodyLarge?.bold,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Select which printers should print order tickets. Products must also have a printer assigned.',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _EnabledPrintersSection(
                        enabled: settings.printOrderTicketsOnOrderAway,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section for enabling/disabling individual printers for order tickets
class _EnabledPrintersSection extends StatefulWidget {
  final bool enabled;

  const _EnabledPrintersSection({required this.enabled});

  @override
  State<_EnabledPrintersSection> createState() => _EnabledPrintersSectionState();
}

class _EnabledPrintersSectionState extends State<_EnabledPrintersSection> {
  final PrinterService _printerService = PrinterService.instance;
  Set<String> _enabledPrinters = {};

  @override
  void initState() {
    super.initState();
    _loadEnabledPrinters();
  }

  void _loadEnabledPrinters() {
    setState(() {
      _enabledPrinters = _printerService.getEnabledOrderPrinters();
    });
  }

  Future<void> _togglePrinter(String printerId) async {
    await _printerService.toggleOrderPrinterEnabled(printerId);
    _loadEnabledPrinters();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allPrinters = [
      ..._printerService.getKitchenPrinters(),
      ..._printerService.getBarPrinters(),
      ..._printerService.getReceiptPrinters(),
    ];

    if (allPrinters.isEmpty) {
      return Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          'No printers configured. Add printers in Supabase first.',
          style: context.textStyles.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: allPrinters.map((printer) {
          final isEnabled = _enabledPrinters.contains(printer.id);
          final IconData icon;
          switch (printer.type) {
            case 'kitchen':
              icon = Icons.restaurant;
              break;
            case 'bar':
              icon = Icons.local_bar;
              break;
            case 'receipt':
              icon = Icons.receipt_long;
              break;
            default:
              icon = Icons.print;
          }

          return CheckboxListTile(
            value: isEnabled,
            onChanged: widget.enabled 
                ? (value) => _togglePrinter(printer.id) 
                : null,
            title: Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.onSurface),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    printer.name,
                    style: context.textStyles.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    printer.type.toUpperCase(),
                    style: context.textStyles.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: isEnabled 
                ? Text(
                    'Will print items assigned to this printer',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: Colors.green,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                : Text(
                    'Disabled - will not print',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OrderTicketFontSizes extends StatefulWidget {
  const _OrderTicketFontSizes();

  @override
  State<_OrderTicketFontSizes> createState() => _OrderTicketFontSizesState();
}

class _OrderTicketFontSizesState extends State<_OrderTicketFontSizes> {
  bool _isSaving = false;

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() => _isSaving = true);
    
    final outletProvider = context.read<OutletProvider>();
    final success = await outletProvider.updateSettings({key: value});
    
    setState(() => _isSaving = false);
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Font size updated'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to update font size'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final outletProvider = context.watch<OutletProvider>();
    final settings = outletProvider.currentSettings;

    if (settings == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: AppSpacing.paddingLg,
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.format_size,
                  color: colorScheme.tertiary,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Order Ticket Font Sizes',
                  style: context.textStyles.titleLarge?.bold,
                ),
              ],
            ),
          ),

          // Settings
          Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customize font sizes for different elements on kitchen/bar order tickets',
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Table Number Size
                _FontSizeControl(
                  label: 'Table Number',
                  description: 'Size of the table number on order tickets',
                  currentSize: settings.tableNumberSize,
                  onChanged: _isSaving
                      ? null
                      : (value) => _updateSetting('table_number_size', value),
                ),

                const SizedBox(height: AppSpacing.lg),
                Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),
                const SizedBox(height: AppSpacing.lg),

                // Notes Size
                _FontSizeControl(
                  label: 'Notes',
                  description: 'Size of item notes/special instructions',
                  currentSize: settings.notesSize,
                  onChanged: _isSaving
                      ? null
                      : (value) => _updateSetting('notes_size', value),
                ),

                const SizedBox(height: AppSpacing.lg),
                Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),
                const SizedBox(height: AppSpacing.lg),

                // Modifiers Size
                _FontSizeControl(
                  label: 'Modifiers',
                  description: 'Size of modifier options (e.g., "No onions", "Extra cheese")',
                  currentSize: settings.modifiersSize,
                  onChanged: _isSaving
                      ? null
                      : (value) => _updateSetting('modifiers_size', value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FontSizeControl extends StatelessWidget {
  final String label;
  final String description;
  final int currentSize;
  final void Function(int)? onChanged;

  const _FontSizeControl({
    required this.label,
    required this.description,
    required this.currentSize,
    this.onChanged,
  });

  String _getSizeLabel(int size) {
    switch (size) {
      case 1:
        return 'Normal';
      case 2:
        return 'Large';
      case 3:
        return 'Extra Large';
      default:
        return 'Normal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.textStyles.bodyLarge?.bold,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description,
                style: context.textStyles.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        // Size selector
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SizeButton(
                label: '1',
                tooltip: 'Normal',
                isSelected: currentSize == 1,
                onTap: onChanged != null ? () => onChanged!(1) : null,
              ),
              Container(
                width: 1,
                height: 40,
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
              _SizeButton(
                label: '2',
                tooltip: 'Large',
                isSelected: currentSize == 2,
                onTap: onChanged != null ? () => onChanged!(2) : null,
              ),
              Container(
                width: 1,
                height: 40,
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
              _SizeButton(
                label: '3',
                tooltip: 'Extra Large',
                isSelected: currentSize == 3,
                onTap: onChanged != null ? () => onChanged!(3) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SizeButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SizeButton({
    required this.label,
    required this.tooltip,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 50,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected 
                ? colorScheme.primaryContainer 
                : Colors.transparent,
          ),
          child: Text(
            label,
            style: context.textStyles.titleMedium?.copyWith(
              color: isSelected 
                  ? colorScheme.onPrimaryContainer 
                  : colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
