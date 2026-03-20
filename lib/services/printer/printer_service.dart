import 'dart:convert';

import 'package:esc_pos_utils_plus/esc_pos_utils.dart';
import 'package:flowtill/models/order.dart';
import 'package:flowtill/models/order_item.dart';
import 'package:flowtill/models/outlet.dart';
import 'package:flowtill/models/outlet_settings.dart';
import 'package:flowtill/models/printer.dart' as models;
import 'package:flowtill/services/local_storage_service.dart';
import 'package:flowtill/services/printer/printer_helper.dart';
import 'package:flowtill/services/printer/local_printer_config_service.dart';
import 'package:flowtill/services/connection_service.dart';
import 'package:flowtill/supabase/supabase_config.dart';
import 'package:flowtill/database/app_database.dart';
import 'package:flowtill/config/sync_config.dart';
import 'package:flowtill/services/outlet_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/flutter_pos_printer_platform_image_3_sdt.dart';
import 'package:intl/intl.dart';

/// Flattened order line used for routing/printing (keeps link to deal name)
class _PrintableOrderLine {
  final OrderItem item;
  final String? dealName;

  const _PrintableOrderLine({required this.item, this.dealName});
}

/// High-level printer service that manages printers from Supabase
/// Handles configuration, routing, and printing logic for receipts and order tickets
/// 
/// Hardware configurations are now stored locally per device using LocalPrinterConfigService.
/// Supabase only stores logical printer definitions (name, type, paper size, etc.)
class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  final LocalStorageService _storage = LocalStorageService();
  final LocalPrinterConfigService _localConfig = LocalPrinterConfigService.instance;
  final AppDatabase _db = AppDatabase.instance;

  // Storage keys
  static const String _autoPrintReceiptKey = 'printer_auto_print_receipt';
  static const String _enableOrderTicketsKey = 'printer_enable_order_tickets';
  static const String _enabledOrderPrintersKey = 'printer_enabled_order_printers';

  // In-memory cache
  Map<String, models.Printer> _printersById = {};
  List<models.Printer> _allPrinters = [];
  List<models.Printer> _receiptPrinters = [];
  List<models.Printer> _kitchenPrinters = [];
  List<models.Printer> _barPrinters = [];
  String? _currentOutletId;

  /// Load all printers for the current outlet (local-first when flag enabled)
  /// Also loads local hardware configurations for this device
  Future<void> loadPrinters(String outletId) async {
    try {
      debugPrint('🖨️ Loading printers for outlet: $outletId');

      List<Map<String, dynamic>>? printerData;

      // Check if we should use local-only mode (native + offline)
      final shouldUseLocalOnly = !kIsWeb && !ConnectionService().isOnline;

      // Step 3: LOCAL MIRROR FIRST (when feature flag is enabled)
      if (kUseLocalMirrorReads && !kIsWeb) {
        debugPrint('[LOCAL_MIRROR] PrinterService: Trying local mirror first');
        
        final localResult = await _getPrintersFromLocalMirror(outletId);
        if (localResult.isSuccess && localResult.data != null && localResult.data!.isNotEmpty) {
          debugPrint('[LOCAL_MIRROR] ✅ Using local data for printers (${localResult.data!.length} records, source=local)');
          printerData = localResult.data;
        } else if (shouldUseLocalOnly) {
          // Offline on native: Use empty list instead of Supabase fallback
          debugPrint('[LOCAL_MIRROR] ⚠️ Offline mode - local data empty, using empty list (no Supabase fallback)');
          printerData = [];
        } else {
          debugPrint('[LOCAL_MIRROR] Local data unavailable, falling back to Supabase for printers');
        }
      }

      // Load from Supabase if local mirror not used or empty
      if (printerData == null) {
        final result = await SupabaseService.select(
          'printers',
          filters: {'outlet_id': outletId, 'active': true},
          orderBy: 'name',
          ascending: true,
        );

        if (!result.isSuccess || result.data == null) {
          debugPrint('❌ Failed to load printers: ${result.error}');
          _clearCache();
          return;
        }

        debugPrint('🖨️ Loaded printers from Supabase (source=supabase)');
        printerData = result.data;
      }

      // Load local hardware configurations
      await _localConfig.loadConfigurations();

      // Migrate hardware configs from Supabase if this is first run
      await _localConfig.migrateFromSupabase(printerData!);

      _currentOutletId = outletId;
      _allPrinters = printerData.map((json) => models.Printer.fromJson(json)).toList();
      _printersById = {for (var p in _allPrinters) p.id: p};
      _receiptPrinters = _allPrinters.where((p) => p.type == 'receipt').toList();
      _kitchenPrinters = _allPrinters.where((p) => p.type == 'kitchen').toList();
      _barPrinters = _allPrinters.where((p) => p.type == 'bar').toList();

      debugPrint('✅ Loaded ${_allPrinters.length} printers:');
      debugPrint('   Receipt: ${_receiptPrinters.length}');
      debugPrint('   Kitchen: ${_kitchenPrinters.length}');
      debugPrint('   Bar: ${_barPrinters.length}');

      // Log local configurations
      final localConfigs = await _localConfig.getAllConfigs();
      debugPrint('📱 Device has ${localConfigs.length} local hardware configs');

      // Auto-enable all printers on first load if none are enabled
      final enabledPrinters = getEnabledOrderPrinters();
      if (enabledPrinters.isEmpty && _allPrinters.isNotEmpty) {
        debugPrint('🔧 First time setup: Enabling all printers by default');
        final allPrinterIds = _allPrinters.map((p) => p.id).toSet();
        await setEnabledOrderPrinters(allPrinterIds);
        debugPrint('✅ Enabled ${allPrinterIds.length} printers for order tickets');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading printers: $e');
      debugPrint('Stack: $stackTrace');
      _clearCache();
    }
  }

  /// Get printers from local mirror table
  Future<ServiceResult<List<Map<String, dynamic>>>> _getPrintersFromLocalMirror(String outletId) async {
    debugPrint('  📂 Reading from local mirror table: printers');

    try {
      final db = await _db.database;
      final results = await db.query(
        'printers',
        where: 'outlet_id = ? AND active = ?',
        whereArgs: [outletId, 1],
        orderBy: 'name',
      );

      if (results.isEmpty) {
        debugPrint('  ⚠️ Local mirror table empty: printers');
        return ServiceResult.failure('Local mirror table empty');
      }

      debugPrint('  ✅ Local mirror has ${results.length} printers');
      return ServiceResult.success(results);
    } catch (e) {
      debugPrint('  ❌ Failed to read from local mirror: $e');
      return ServiceResult.failure('Failed to read local mirror: ${e.toString()}');
    }
  }

  void _clearCache() {
    _printersById = {};
    _allPrinters = [];
    _receiptPrinters = [];
    _kitchenPrinters = [];
    _barPrinters = [];
    _currentOutletId = null;
  }

  /// Get printer by ID
  models.Printer? getById(String? printerId) {
    if (printerId == null) return null;
    return _printersById[printerId];
  }

  /// Get all receipt printers
  List<models.Printer> getReceiptPrinters() => _receiptPrinters;

  /// Get all kitchen printers
  List<models.Printer> getKitchenPrinters() => _kitchenPrinters;

  /// Get all bar printers
  List<models.Printer> getBarPrinters() => _barPrinters;

  /// Get default receipt printer (first with isDefaultReceipt == true, else first receipt printer)
  models.Printer? getDefaultReceiptPrinter() {
    final defaultPrinter = _receiptPrinters.where((p) => p.isDefaultReceipt).firstOrNull;
    if (defaultPrinter != null) return defaultPrinter;
    return _receiptPrinters.isNotEmpty ? _receiptPrinters.first : null;
  }

  /// Auto-print receipt setting
  bool get autoPrintReceiptEnabled => _storage.prefs.getBool(_autoPrintReceiptKey) ?? false;
  Future<void> setAutoPrintReceipt(bool enabled) async {
    await _storage.prefs.setBool(_autoPrintReceiptKey, enabled);
    debugPrint('✅ Auto-print receipt ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Order ticket printing enabled
  bool get orderTicketPrintingEnabled => _storage.prefs.getBool(_enableOrderTicketsKey) ?? true;
  Future<void> setOrderTicketPrinting(bool enabled) async {
    await _storage.prefs.setBool(_enableOrderTicketsKey, enabled);
    debugPrint('✅ Order ticket printing ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Get list of enabled order printer IDs
  Set<String> getEnabledOrderPrinters() {
    final json = _storage.getString(_enabledOrderPrintersKey);
    if (json == null || json.isEmpty) return {};
    try {
      final list = (jsonDecode(json) as List).cast<String>();
      return list.toSet();
    } catch (e) {
      debugPrint('❌ Error decoding enabled order printers: $e');
      return {};
    }
  }

  /// Set enabled order printers
  Future<void> setEnabledOrderPrinters(Set<String> printerIds) async {
    final json = jsonEncode(printerIds.toList());
    await _storage.saveString(_enabledOrderPrintersKey, json);
    debugPrint('✅ Enabled order printers updated: ${printerIds.length} printers');
  }

  /// Check if a specific printer is enabled for order tickets
  bool isOrderPrinterEnabled(String printerId) {
    final enabled = getEnabledOrderPrinters();
    return enabled.contains(printerId);
  }

  /// Toggle order printer enabled state
  Future<void> toggleOrderPrinterEnabled(String printerId) async {
    final enabled = getEnabledOrderPrinters();
    if (enabled.contains(printerId)) {
      enabled.remove(printerId);
    } else {
      enabled.add(printerId);
    }
    await setEnabledOrderPrinters(enabled);
  }

  /// Check if a printer has hardware configuration on this device
  Future<bool> hasHardwareConfig(String printerId) async {
    return await _localConfig.hasConfig(printerId);
  }

  /// Get hardware configuration for a printer on this device
  Future<LocalPrinterHardwareConfig?> getHardwareConfig(String printerId) async {
    return await _localConfig.getConfig(printerId);
  }

  /// Remove hardware configuration for a printer on this device
  Future<void> removeHardwareConfig(String printerId) async {
    await _localConfig.removeConfig(printerId);
    debugPrint('✅ Removed hardware config for printer $printerId');
  }

  /// Get device information
  Future<String> getDeviceName() async {
    return await _localConfig.getDeviceName();
  }

  Future<String> getDeviceId() async {
    return await _localConfig.getDeviceId();
  }

  /// Save hardware link for a printer (stores locally on this device only)
  /// Hardware configurations are device-specific and NOT synced to Supabase
  Future<void> saveHardwareLink({
    required String printerId,
    required String connectionType,
    String? ipAddress,
    int? port,
    String? hardwareVendorId,
    String? hardwareProductId,
    String? hardwareAddress,
    String? hardwareName,
  }) async {
    debugPrint('🖨️ Saving hardware link for printer $printerId (local only)...');

    final config = LocalPrinterHardwareConfig(
      printerId: printerId,
      connectionType: connectionType,
      ipAddress: ipAddress,
      port: port,
      hardwareVendorId: hardwareVendorId,
      hardwareProductId: hardwareProductId,
      hardwareAddress: hardwareAddress,
      hardwareName: hardwareName,
    );

    await _localConfig.saveConfig(config);

    // Reload printers to refresh cache
    if (_currentOutletId != null) {
      await loadPrinters(_currentOutletId!);
    }

    debugPrint('✅ Hardware link saved locally');
  }

  /// Print order tickets based on products.printer_id routing
  /// Groups items by printer_id and prints separate tickets for each printer
  Future<void> printOrderTickets({
    required Order order,
    String? staffName,
  }) async {
    if (kIsWeb) {
      throw Exception('Printing not available in web preview');
    }

    if (!orderTicketPrintingEnabled) {
      debugPrint('ℹ️ Order ticket printing is disabled');
      return;
    }

    debugPrint('🖨️ Routing order items to printers...');

    // Group items by printer_id
    final Map<String, List<_PrintableOrderLine>> groups = {};

    // Get default receipt printer as fallback
    final defaultPrinter = getDefaultReceiptPrinter();

    final printableItems = _expandItemsForRouting(order);

    for (final printable in printableItems) {
      final item = printable.item;
      String? printerId = item.product.printerId;
      
      // Default to front till (receipt) printer if no printer assigned
      if (printerId == null && defaultPrinter != null) {
        printerId = defaultPrinter.id;
        debugPrint('   ${item.product.name} → No printer assigned, defaulting to ${defaultPrinter.name}');
      } else if (printerId == null) {
        debugPrint('   ${item.product.name} → No printer assigned and no default printer, skipping');
        continue;
      }

      final printer = getById(printerId);
      if (printer == null) {
        debugPrint('   ${item.product.name} → Printer $printerId not found, skipping');
        continue;
      }

      if (!printer.active) {
        debugPrint('   ${item.product.name} → Printer ${printer.name} inactive, skipping');
        continue;
      }

      if (!isOrderPrinterEnabled(printerId)) {
        debugPrint('   ${item.product.name} → Printer ${printer.name} disabled in settings, skipping');
        continue;
      }

      groups.putIfAbsent(printerId, () => []);
      groups[printerId]!.add(printable);
    }

    if (groups.isEmpty) {
      debugPrint('ℹ️ No items to print (no printer assignments or all disabled)');
      return;
    }

    debugPrint('📋 Printing to ${groups.length} printer(s):');

    // Print ticket for each group
    for (final entry in groups.entries) {
      final printerId = entry.key;
      final items = entry.value;
      final printer = getById(printerId)!;

      debugPrint('   → ${printer.name} (${printer.type}): ${items.length} items');

      try {
        await _printOrderTicketForPrinter(
          printer: printer,
          order: order,
          items: items,
          staffName: staffName,
        );
        debugPrint('   ✅ Printed to ${printer.name}');
      } catch (e) {
        debugPrint('   ❌ Failed to print to ${printer.name}: $e');
        rethrow;
      }
    }

    debugPrint('✅ Order tickets printed successfully');
  }

  /// Print order ticket to a specific printer
  Future<void> _printOrderTicketForPrinter({
    required models.Printer printer,
    required Order order,
    required List<_PrintableOrderLine> items,
    String? staffName,
  }) async {
    // Convert printer to PrinterDeviceInfo
    final deviceInfo = await _printerToDeviceInfo(printer);
    if (deviceInfo == null) {
      throw Exception('No hardware configuration found for ${printer.name}');
    }

    // Convert items to KitchenTicketItem
    final ticketItems = items
        .map((line) => KitchenTicketItem(
              quantity: line.item.quantity,
              itemName: line.item.product.name,
              notes: _mergeDealNote(line.item.notes, line.dealName),
              modifiers: line.item.selectedModifiers
                  .map((mod) => mod.kitchenDisplayText)
                  .toList(),
            ))
        .toList();

    await PrinterHelper.printKitchenTicket(
      printer: deviceInfo,
      items: ticketItems,
      tableNumber: order.tableNumber,
      staffName: staffName,
    );
  }

  List<_PrintableOrderLine> _expandItemsForRouting(Order order) {
    final expanded = <_PrintableOrderLine>[];

    for (final item in order.items) {
      if (item.isPackagedDeal && item.dealComponentItems != null && item.dealComponentItems!.isNotEmpty) {
        for (final component in item.dealComponentItems!) {
          expanded.add(_PrintableOrderLine(item: component, dealName: item.product.name));
        }
      } else {
        expanded.add(_PrintableOrderLine(item: item));
      }
    }

    return expanded;
  }

  String _mergeDealNote(String existingNote, String? dealName) {
    if (dealName == null || dealName.isEmpty) return existingNote;
    if (existingNote.isEmpty) return 'Deal: $dealName';
    return '$existingNote | Deal: $dealName';
  }

  /// Print customer receipt (full order with prices)
  Future<void> printCustomerReceipt(Order order, {String? outletName, Outlet? outlet}) async {
    if (kIsWeb) {
      throw Exception('Printing not available in web preview');
    }

    final printer = getDefaultReceiptPrinter();
    if (printer == null) {
      throw Exception('No receipt printer configured');
    }

    debugPrint('🖨️ Printing customer receipt to ${printer.name}...');

    final deviceInfo = await _printerToDeviceInfo(printer);
    if (deviceInfo == null) {
      throw Exception('No hardware configuration found for ${printer.name}');
    }

    // Build ESC/POS bytes
    final bytes = await _buildFormattedReceiptBytes(
      order: order,
      outlet: outlet,
      outletName: outletName,
    );

    // Send to printer
    await PrinterHelper.sendToPrinter(deviceInfo, bytes);
    debugPrint('✅ Customer receipt printed successfully');
  }

  /// Build formatted receipt bytes using outlet receipt formatting settings
  Future<List<int>> _buildFormattedReceiptBytes({
    required Order order,
    Outlet? outlet,
    String? outletName,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // Initialize printer with CP1252 codepage
    bytes += PrinterHelper.applyPrinterInit(generator);

    // Header - use custom header text from outlet settings
    final headerText = (outlet?.receiptHeaderText.isNotEmpty == true)
        ? outlet!.receiptHeaderText
        : (outlet?.name ?? outletName ?? 'Receipt');
    
    bytes += generator.text(
      headerText,
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += generator.text(
      DateFormat('dd/MM/yyyy HH:mm').format(order.completedAt ?? DateTime.now()),
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      'Order: ${order.id.substring(0, 8).toUpperCase()}',
      styles: const PosStyles(align: PosAlign.center),
    );

    if (order.tableNumber != null) {
      bytes += generator.text(
        'Table: ${order.tableNumber}',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    }

    bytes += generator.feed(1);

    // Receipt title
    bytes += generator.text(
      'RECEIPT',
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size3,
        width: PosTextSize.size3,
      ),
    );

    bytes += generator.hr(ch: '-');

    // Combine identical items (same product, same modifiers, no notes) for receipt display
    final combinedItems = _combineIdenticalItems(order.items);

    // Items
    for (final item in combinedItems) {
      bytes += generator.row([
        PosColumn(text: '${item.quantity}x', width: 2, styles: const PosStyles(bold: true)),
        PosColumn(text: item.product.name, width: 7),
        PosColumn(
          text: _formatCurrency(item.total),
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      
      // Print modifiers if present (with prices)
      if (item.selectedModifiers.isNotEmpty) {
        for (final modifier in item.selectedModifiers) {
          bytes += generator.text(
            '  > ${modifier.displayText}',
            styles: const PosStyles(
              fontType: PosFontType.fontA,
              align: PosAlign.left,
            ),
          );
        }
      }
      
      // Print notes if present
      if (item.notes.isNotEmpty) {
        bytes += generator.text(
          '  Note: ${item.notes}',
          styles: const PosStyles(
            fontType: PosFontType.fontA,
            align: PosAlign.left,
          ),
        );
      }
    }

    bytes += generator.hr(ch: '-');

    // Totals
    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 8),
      PosColumn(text: _formatCurrency(order.subtotal), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);

    // Show VAT breakdown if enabled
    if (outlet?.receiptShowVatBreakdown != false) {
      bytes += generator.row([
        PosColumn(text: 'Tax', width: 8),
        PosColumn(text: _formatCurrency(order.taxAmount), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    // Show service charge if enabled and non-zero
    if ((outlet?.receiptShowServiceCharge != false) && order.serviceCharge > 0) {
      bytes += generator.row([
        PosColumn(text: 'Service Charge', width: 8),
        PosColumn(text: _formatCurrency(order.serviceCharge), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    // Show promotions/discounts if enabled and non-zero
    if ((outlet?.receiptShowPromotions != false) && order.totalDiscounts > 0) {
      bytes += generator.row([
        PosColumn(text: 'Discounts', width: 8),
        PosColumn(text: _formatCurrency(-order.totalDiscounts), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr(ch: '=');

    // Total - use receiptLargeTotalText setting
    final useLargeTotal = outlet?.receiptLargeTotalText != false;
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 8,
        styles: PosStyles(
          bold: true,
          height: useLargeTotal ? PosTextSize.size2 : PosTextSize.size1,
          width: useLargeTotal ? PosTextSize.size2 : PosTextSize.size1,
        ),
      ),
      PosColumn(
        text: _formatCurrency(order.totalDue),
        width: 4,
        styles: PosStyles(
          bold: true,
          align: PosAlign.right,
          height: useLargeTotal ? PosTextSize.size2 : PosTextSize.size1,
          width: useLargeTotal ? PosTextSize.size2 : PosTextSize.size1,
        ),
      ),
    ]);

    bytes += generator.hr(ch: '=');

    // Payment method
    if (order.paymentMethod != null) {
      bytes += generator.text(
        'Payment: ${order.paymentMethod!.toUpperCase()}',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    }

    if (order.changeDue > 0) {
      bytes += generator.text(
        'Change: ${_formatCurrency(order.changeDue)}',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    }

    bytes += generator.feed(1);

    // Footer - use custom footer text from outlet settings
    final footerText = (outlet?.receiptFooterText.isNotEmpty == true)
        ? outlet!.receiptFooterText
        : 'Thank you for your visit!';
    
    bytes += generator.text(
      footerText,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  /// Test print for a specific printer
  Future<void> testPrint(models.Printer printer) async {
    if (kIsWeb) {
      throw Exception('Printing not available in web preview');
    }

    final deviceInfo = await _printerToDeviceInfo(printer);
    if (deviceInfo == null) {
      throw Exception('No hardware configuration found for ${printer.name}');
    }

    debugPrint('🖨️ Test printing to ${printer.name}...');

    if (printer.type == 'receipt') {
      await PrinterHelper.printTestReceipt(deviceInfo);
    } else {
      // Kitchen/bar/other ticket format
      await PrinterHelper.printKitchenTicket(
        printer: deviceInfo,
        items: const [
          KitchenTicketItem(quantity: 2, itemName: 'Test Item 1'),
          KitchenTicketItem(quantity: 1, itemName: 'Test Item 2'),
        ],
        tableNumber: 'TEST',
        staffName: 'System',
      );
    }

    debugPrint('✅ Test print completed');
  }

  /// Print order tickets for Order Away with configurable copies
  /// Routes items by products.printer_id to logical printers in Supabase
  Future<void> printOrderTicketsForOrder({
    required Order order,
    required int copies,
    OutletSettings? settings,
  }) async {
    if (kIsWeb) {
      throw Exception('Printing not available in web preview');
    }

    debugPrint('🖨️ PrintOrderTicketsForOrder: Starting...');
    debugPrint('   Order ID: ${order.id.substring(0, 8)}');
    debugPrint('   Items: ${order.items.length}');
    debugPrint('   Copies: $copies');

    // Step 1: Load all active printers for current outlet
    final activePrinters = _allPrinters.where((p) => p.active).toList();

    if (activePrinters.isEmpty) {
      debugPrint('⚠️ No active printers configured');
      return;
    }

    // Log enabled printers
    final enabledPrinters = getEnabledOrderPrinters();
    debugPrint('📋 Enabled order printers: ${enabledPrinters.length} out of ${activePrinters.length} active');
    for (final printer in activePrinters) {
      final isEnabled = enabledPrinters.contains(printer.id);
      debugPrint('   ${isEnabled ? "✓" : "✗"} ${printer.name} (${printer.type})${isEnabled ? "" : " - DISABLED"}');
    }

    // Step 2: Build map printerId -> Printer
    final printerMap = {for (var p in activePrinters) p.id: p};

    // Step 3: Group order items by printer_id and build ticket sets
    // Each printer maps to a list of tickets; each ticket is a list of printable lines
    final Map<models.Printer, List<List<_PrintableOrderLine>>> ticketsByPrinter = {};
    final Map<models.Printer, List<_PrintableOrderLine>> groupedStandardItems = {};

    // Get default receipt printer as fallback for items without printer assignment
    final defaultPrinter = getDefaultReceiptPrinter();

    final printableItems = _expandItemsForRouting(order);

    for (final printable in printableItems) {
      final item = printable.item;
      // 🔍 Enhanced debugging for product printer assignment
      debugPrint('🔍 Checking printer for product: ${item.product.name}');
      debugPrint('   Product ID: ${item.product.id}');
      debugPrint('   Product printerId field: ${item.product.printerId}');
      debugPrint('   Product course: ${item.product.course}');
      debugPrint('   Product isCarvery: ${item.product.isCarvery}');
      
      final printerId = item.product.printerId;

      models.Printer? printer;

      if (printerId == null) {
        // No printer assigned - default to front till (receipt) printer
        if (defaultPrinter != null) {
          printer = defaultPrinter;
          debugPrint('   ⚠️ "${item.product.name}" has no printer_id, defaulting to ${printer.name}');
        } else {
          debugPrint('   ⚠️ Item "${item.product.name}" has no printer_id and no default printer available, skipping');
          continue;
        }
      } else if (!printerMap.containsKey(printerId)) {
        debugPrint('⚠️ Item "${item.product.name}" references unknown printer $printerId, skipping');
        continue;
      } else {
        printer = printerMap[printerId]!;
        debugPrint('   ✓ "${item.product.name}" → ${printer.name} (${printer.type})');
      }

      if (printer == null) {
        continue;
      }

      // Check if this printer is enabled for order tickets
      if (!isOrderPrinterEnabled(printer.id)) {
        debugPrint('   ⚠️ "${item.product.name}" → Printer ${printer.name} disabled in settings, skipping');
        continue;
      }

      final resolvedPrinter = printer;

      if (item.product.isCarvery) {
        final ticketList = ticketsByPrinter.putIfAbsent(resolvedPrinter, () => []);
        for (int i = 0; i < item.quantity; i++) {
          ticketList.add([
            _PrintableOrderLine(
              item: item.copyWith(quantity: 1),
              dealName: printable.dealName,
            ),
          ]);
        }
      } else {
        groupedStandardItems.putIfAbsent(resolvedPrinter, () => []).add(printable);
      }
    }

    // Add grouped standard items as single ticket per printer
    for (final entry in groupedStandardItems.entries) {
      if (entry.value.isEmpty) continue;
      ticketsByPrinter.putIfAbsent(entry.key, () => []).add(entry.value);
    }

    if (ticketsByPrinter.isEmpty) {
      debugPrint('⚠️ No items could be routed to printers');
      return;
    }

    debugPrint('📋 Printing to ${ticketsByPrinter.length} printer(s), $copies copies each');

    // Step 4: Print N copies for each printer and ticket
    for (final entry in ticketsByPrinter.entries) {
      final printer = entry.key;
      final tickets = entry.value;

      debugPrint('🖨️ Printer: ${printer.name} (${tickets.length} ticket(s))');

      for (final ticketItems in tickets) {
        for (int copy = 1; copy <= copies; copy++) {
          try {
            await _printKitchenTicketToPrinter(
              printer: printer,
              order: order,
              items: ticketItems,
              copyNumber: copy,
              totalCopies: copies,
              settings: settings,
            );
            debugPrint('   ✅ Copy $copy/$copies printed to ${printer.name}');
          } catch (e) {
            debugPrint('   ❌ Copy $copy/$copies failed for ${printer.name}: $e');
            // Continue with other copies/printers
          }
        }
      }
    }

    debugPrint('✅ PrintOrderTicketsForOrder: Completed');
  }

  /// Print a single kitchen ticket to a specific printer
  Future<void> _printKitchenTicketToPrinter({
    required models.Printer printer,
    required Order order,
    required List<_PrintableOrderLine> items,
    int? copyNumber,
    int? totalCopies,
    OutletSettings? settings,
  }) async {
    // Build ticket bytes
    final bytes = await _buildKitchenTicketBytes(
      printer: printer,
      order: order,
      items: items,
      copyNumber: copyNumber,
      totalCopies: totalCopies,
      settings: settings,
    );

    // Convert to PrinterDeviceInfo
    final deviceInfo = await _printerToDeviceInfo(printer);
    if (deviceInfo == null) {
      throw Exception('No hardware configuration found for ${printer.name}');
    }

    // Send to hardware using PrinterHelper
    await PrinterHelper.sendToPrinter(deviceInfo, bytes);
  }

  /// Build ESC/POS bytes for a kitchen ticket (no prices)
  Future<List<int>> _buildKitchenTicketBytes({
    required models.Printer printer,
    required Order order,
    required List<_PrintableOrderLine> items,
    int? copyNumber,
    int? totalCopies,
    OutletSettings? settings,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperSize = printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paperSize, profile);

    List<int> bytes = [];

    // Initialize printer with CP1252 codepage
    bytes += PrinterHelper.applyPrinterInit(generator);

    // Header with larger heading
    bytes += generator.text(
      'ORDER AWAY',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size3,
        width: PosTextSize.size3,
        bold: true,
      ),
    );
    bytes += generator.feed(1);

    // Table/Order info
    if (order.tableNumber != null && order.tableNumber!.isNotEmpty) {
      final tableSize = _mapToTextSize(settings?.tableNumberSize ?? 1);
      bytes += generator.text(
        'TABLE: ${order.tableNumber}',
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: tableSize,
          width: tableSize,
        ),
      );
    }

    bytes += generator.text(
      DateFormat('dd MMM yyyy  HH:mm').format(DateTime.now()),
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      'Order ID: ${order.id.substring(0, 8).toUpperCase()}',
      styles: const PosStyles(align: PosAlign.center),
    );

    if (copyNumber != null && totalCopies != null) {
      bytes += generator.text(
        'Copy $copyNumber of $totalCopies',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    bytes += generator.feed(1);
    bytes += generator.hr();
    bytes += generator.feed(1);

    // Items (NO PRICES - just quantity and name with larger text)
    for (final line in items) {
      final item = line.item;
      bytes += generator.text(
        '${item.quantity}  ${item.product.name}',
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      if (line.dealName != null && line.dealName!.isNotEmpty) {
        final dealNoteSize = _mapToTextSize(settings?.notesSize ?? 1);
        bytes += generator.text(
          '    Deal: ${line.dealName}',
          styles: PosStyles(
            align: PosAlign.left,
            height: dealNoteSize,
            width: dealNoteSize,
          ),
        );
      }

      // Modifiers (if any)
      if (item.selectedModifiers.isNotEmpty) {
        final modifierSize = _mapToTextSize(settings?.modifiersSize ?? 1);
        for (final modifier in item.selectedModifiers) {
          bytes += generator.text(
            '    ${modifier.displayText}',
            styles: PosStyles(
              align: PosAlign.left,
              height: modifierSize,
              width: modifierSize,
            ),
          );
        }
      }

      // Notes (if any)
      if (item.notes.isNotEmpty) {
        final noteSize = _mapToTextSize(settings?.notesSize ?? 1);
        bytes += generator.text(
          '    Note: ${item.notes}',
          styles: PosStyles(
            align: PosAlign.left,
            bold: true,
            height: noteSize,
            width: noteSize,
          ),
        );
      }

      bytes += generator.feed(1);
    }

    // Footer
    bytes += generator.hr();
    bytes += generator.text(
      printer.name.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  /// Map integer size (1-3) to PosTextSize enum
  PosTextSize _mapToTextSize(int size) {
    switch (size) {
      case 2:
        return PosTextSize.size2;
      case 3:
        return PosTextSize.size3;
      default:
        return PosTextSize.size1;
    }
  }

  /// Print formatted test receipt using outlet receipt formatting settings
  Future<void> printFormattedTestReceipt(Outlet outlet) async {
    if (kIsWeb) {
      throw Exception('Printing not available in web preview');
    }

    final printer = getDefaultReceiptPrinter();
    if (printer == null) {
      throw Exception('No receipt printer configured');
    }

    debugPrint('🖨️ Printing test receipt to ${printer.name}...');

    final deviceInfo = await _printerToDeviceInfo(printer);
    if (deviceInfo == null) {
      throw Exception('No hardware configuration found for ${printer.name}');
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // Initialize printer with CP1252 codepage
    bytes += PrinterHelper.applyPrinterInit(generator);

    // Header - use custom header text from outlet settings
    final headerText = (outlet.receiptHeaderText.isNotEmpty)
        ? outlet.receiptHeaderText
        : outlet.name;
    
    bytes += generator.text(
      headerText,
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += generator.text(
      'TEST RECEIPT',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size3,
        width: PosTextSize.size3,
      ),
    );

    bytes += generator.text(
      DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.hr(ch: '-');

    // Sample items
    bytes += generator.row([
      PosColumn(text: '2x', width: 2, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Sample Coffee', width: 7),
      PosColumn(text: _formatCurrencyStatic(6.00), width: 3, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.text(
      '  Note: Extra hot, no sugar',
      styles: const PosStyles(
        fontType: PosFontType.fontA,
        align: PosAlign.left,
      ),
    );
    bytes += generator.row([
      PosColumn(text: '1x', width: 2, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Sample Sandwich', width: 7),
      PosColumn(text: _formatCurrencyStatic(5.50), width: 3, styles: const PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.hr(ch: '-');

    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 8),
      PosColumn(text: _formatCurrencyStatic(11.50), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);

    // Show VAT breakdown if enabled
    if (outlet.receiptShowVatBreakdown) {
      bytes += generator.row([
        PosColumn(text: 'Tax (20%)', width: 8),
        PosColumn(text: _formatCurrencyStatic(2.30), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    // Show service charge if enabled
    if (outlet.receiptShowServiceCharge) {
      bytes += generator.row([
        PosColumn(text: 'Service Charge', width: 8),
        PosColumn(text: _formatCurrencyStatic(1.38), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    // Show promotions/discounts if enabled
    if (outlet.receiptShowPromotions) {
      bytes += generator.row([
        PosColumn(text: 'Discount', width: 8),
        PosColumn(text: _formatCurrencyStatic(-1.00), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr(ch: '=');

    // Total - use receiptLargeTotalText setting
    final useLargeTotal = outlet.receiptLargeTotalText;
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 8,
        styles: PosStyles(
          bold: true,
          height: useLargeTotal ? PosTextSize.size2 : PosTextSize.size1,
          width: useLargeTotal ? PosTextSize.size2 : PosTextSize.size1,
        ),
      ),
      PosColumn(
        text: _formatCurrencyStatic(14.18),
        width: 4,
        styles: PosStyles(
          bold: true,
          align: PosAlign.right,
          height: useLargeTotal ? PosTextSize.size2 : PosTextSize.size1,
          width: useLargeTotal ? PosTextSize.size2 : PosTextSize.size1,
        ),
      ),
    ]);

    bytes += generator.hr(ch: '=');

    bytes += generator.text('Payment: CARD', styles: const PosStyles(align: PosAlign.center, bold: true));

    bytes += generator.feed(1);

    // Footer - use custom footer text from outlet settings
    final footerText = (outlet.receiptFooterText.isNotEmpty)
        ? outlet.receiptFooterText
        : 'Thank you for your visit!';
    
    bytes += generator.text(
      footerText,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += generator.feed(3);
    bytes += generator.cut();

    // Send to printer
    await PrinterHelper.sendToPrinter(deviceInfo, bytes);
    debugPrint('✅ Test receipt printed successfully');
  }

  /// Convert Printer model to PrinterDeviceInfo for PrinterHelper
  /// Uses local hardware configuration for this device
  Future<PrinterDeviceInfo?> _printerToDeviceInfo(models.Printer printer) async {
    // Get local hardware configuration for this device
    final localConfig = await _localConfig.getConfig(printer.id);
    
    if (localConfig == null) {
      debugPrint('⚠️ No local hardware config for printer ${printer.name}');
      return null;
    }

    debugPrint('🔧 Hardware config for ${printer.name}:');
    debugPrint('   Connection type: ${localConfig.connectionType}');
    if (localConfig.connectionType == 'usb') {
      debugPrint('   USB Device: ${localConfig.hardwareName ?? "Unknown"}');
      debugPrint('   Vendor ID: ${localConfig.hardwareVendorId ?? "N/A"}');
      debugPrint('   Product ID: ${localConfig.hardwareProductId ?? "N/A"}');
    } else if (localConfig.connectionType == 'network') {
      debugPrint('   IP Address: ${localConfig.ipAddress ?? "N/A"}');
      debugPrint('   Port: ${localConfig.port ?? 9100}');
    } else if (localConfig.connectionType == 'bluetooth') {
      debugPrint('   Device: ${localConfig.hardwareName ?? "Unknown"}');
      debugPrint('   Address: ${localConfig.hardwareAddress ?? "N/A"}');
    }

    PrinterType? type;
    switch (localConfig.connectionType) {
      case 'usb':
        type = PrinterType.usb;
        break;
      case 'bluetooth':
        type = PrinterType.bluetooth;
        break;
      case 'network':
        type = PrinterType.network;
        break;
      default:
        debugPrint('⚠️ Unknown connection type: ${localConfig.connectionType}');
        return null;
    }

    return PrinterDeviceInfo(
      name: localConfig.hardwareName ?? printer.name,
      address: localConfig.hardwareAddress ?? localConfig.ipAddress,
      vendorId: localConfig.hardwareVendorId,
      productId: localConfig.hardwareProductId,
      type: type,
      ipAddress: localConfig.ipAddress,
      port: localConfig.port,
    );
  }

  /// Test print specifically for £ symbol verification
  /// Prints a simple receipt with various £ amounts to verify CP1252 codepage
  Future<void> testPoundSymbolPrint() async {
    if (kIsWeb) {
      throw Exception('Printing not available in web preview');
    }

    final printer = getDefaultReceiptPrinter();
    if (printer == null) {
      throw Exception('No default receipt printer configured');
    }

    debugPrint('🖨️ Testing £ symbol print to ${printer.name}...');

    final deviceInfo = await _printerToDeviceInfo(printer);
    if (deviceInfo == null) {
      throw Exception('No hardware configuration found for ${printer.name}');
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    final bytes = <int>[];
    
    // Initialize with CP1252 FIRST (before any text)
    bytes.addAll(PrinterHelper.applyPrinterInit(generator));

    // Only AFTER init, print text containing £
    bytes.addAll(generator.text(
      'POUND SYMBOL TEST',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.hr(ch: '-'));
    bytes.addAll(generator.text('Subtotal: £12.50'));
    bytes.addAll(generator.text('Card: £10.00'));
    bytes.addAll(generator.text('Change: £2.50'));
    bytes.addAll(generator.hr(ch: '-'));
    bytes.addAll(generator.text('Total: £15.00', styles: const PosStyles(bold: true)));
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(
      'If you see "£" correctly,',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text(
      'CP1252 is working!',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    await PrinterHelper.sendToPrinter(deviceInfo, bytes);
    debugPrint('✅ Pound symbol test print completed');
  }

  /// Currency formatter that always uses the pound symbol
  /// Combine identical items for receipt display
  /// Items are considered identical if they have the same product ID, same modifiers, and no notes
  List<OrderItem> _combineIdenticalItems(List<OrderItem> items) {
    final Map<String, OrderItem> combinedMap = {};

    for (final item in items) {
      // Create a unique key based on product ID and modifiers
      // Items with notes are never combined
      final hasNotes = item.notes.isNotEmpty;
      if (hasNotes) {
        // Items with notes get unique keys (never combined)
        combinedMap[item.id] = item;
        continue;
      }

      // Build key from product ID and sorted modifier IDs
      final modifierKey = item.selectedModifiers
          .map((m) => '${m.groupId}:${m.optionId}')
          .toList()
        ..sort();
      final key = '${item.product.id}|${modifierKey.join(',')}';

      if (combinedMap.containsKey(key)) {
        // Combine with existing item by increasing quantity
        final existing = combinedMap[key]!;
        combinedMap[key] = existing.copyWith(
          quantity: existing.quantity + item.quantity,
        );
      } else {
        // First occurrence of this item combination
        combinedMap[key] = item;
      }
    }

    return combinedMap.values.toList();
  }

  String _formatCurrency(num amount) {
    final sign = amount < 0 ? '-£' : '£';
    return '$sign${amount.abs().toStringAsFixed(2)}';
  }

  /// Static helper for const contexts (test receipt rows)
  static String _formatCurrencyStatic(num amount) {
    final sign = amount < 0 ? '-£' : '£';
    return '$sign${amount.abs().toStringAsFixed(2)}';
  }

  /// Open cash drawer via receipt printer's cash drawer port
  /// Sends ESC/POS pulse command to the default receipt printer
  /// Tries pin 2 first, then falls back to pin 5 if needed
  Future<void> openCashDrawer() async {
    if (kIsWeb) {
      throw Exception('Cash drawer control not available in web preview');
    }

    final printer = getDefaultReceiptPrinter();
    if (printer == null) {
      throw Exception('No default receipt printer configured');
    }

    debugPrint('💵 Opening cash drawer via ${printer.name}...');

    final deviceInfo = await _printerToDeviceInfo(printer);
    if (deviceInfo == null) {
      throw Exception('No hardware configuration found for ${printer.name}');
    }

    // ESC/POS cash drawer kick command: ESC p m t1 t2
    // ESC = 0x1B, p = 0x70
    // m = drawer pin (0 = pin 2, 1 = pin 5)
    // t1 = ON time (0x19 = 25ms)
    // t2 = OFF time (0xFA = 250ms)
    
    // Try pin 2 first (most common configuration)
    final pin2Command = [0x1B, 0x70, 0x00, 0x19, 0xFA];
    
    try {
      debugPrint('   Sending pulse to drawer pin 2...');
      await PrinterHelper.sendToPrinter(deviceInfo, pin2Command);
      debugPrint('✅ Cash drawer command sent successfully (pin 2)');
    } catch (e) {
      debugPrint('⚠️ Pin 2 failed, trying pin 5: $e');
      
      // Fallback to pin 5
      final pin5Command = [0x1B, 0x70, 0x01, 0x19, 0xFA];
      try {
        debugPrint('   Sending pulse to drawer pin 5...');
        await PrinterHelper.sendToPrinter(deviceInfo, pin5Command);
        debugPrint('✅ Cash drawer command sent successfully (pin 5)');
      } catch (e2) {
        debugPrint('❌ Both drawer pins failed');
        throw Exception('Failed to open cash drawer: $e2');
      }
    }
  }
}