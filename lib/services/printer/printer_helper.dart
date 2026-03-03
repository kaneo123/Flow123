// lib/services/printer/printer_helper.dart
import 'dart:async';

import 'package:esc_pos_utils_plus/esc_pos_utils.dart';
import 'package:flutter_pos_printer_platform_image_3_sdt/flutter_pos_printer_platform_image_3_sdt.dart';

/// Simple item model for kitchen tickets
class KitchenTicketItem {
  final int quantity;
  final String itemName;
  final String notes;
  final List<String> modifiers;

  const KitchenTicketItem({
    required this.quantity,
    required this.itemName,
    this.notes = '',
    this.modifiers = const [],
  });
}

/// Simple model you can pass around in your app.
class PrinterDeviceInfo {
  final String? name;
  final String? address;
  final String? vendorId;
  final String? productId;
  final PrinterType type;
  final String? ipAddress;  // For network printers
  final int? port;          // For network printers

  const PrinterDeviceInfo({
    required this.name,
    required this.address,
    required this.vendorId,
    required this.productId,
    required this.type,
    this.ipAddress,
    this.port,
  });

  @override
  String toString() {
    return 'PrinterDeviceInfo(name: $name, addr: $address, vid: $vendorId, pid: $productId, type: $type, ip: $ipAddress, port: $port)';
  }
}

/// Helper class you can drop into *any* Flutter project (e.g. Dreamflow).
///
/// All printing logic lives here so I can reuse this file later.
class PrinterHelper {
  PrinterHelper._();

  static final PrinterManager _printerManager = PrinterManager.instance;

  /// Scan for printers of a specific type.
  ///
  /// - type: PrinterType.usb or PrinterType.bluetooth
  /// - isBle: only relevant for BLE bluetooth.
  static Future<List<PrinterDeviceInfo>> discoverPrinters(
    PrinterType type, {
    bool isBle = false,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final List<PrinterDeviceInfo> devices = [];
    late final StreamSubscription<PrinterDevice> sub;

    final completer = Completer<List<PrinterDeviceInfo>>();

    sub = _printerManager
        .discovery(type: type, isBle: isBle)
        .listen((PrinterDevice d) {
      devices.add(
        PrinterDeviceInfo(
          name: d.name,
          address: d.address,
          vendorId: d.vendorId,
          productId: d.productId,
          type: type,
        ),
      );
    }, onDone: () {
      if (!completer.isCompleted) completer.complete(devices);
    }, onError: (e) {
      if (!completer.isCompleted) completer.completeError(e);
    });

    // Stop scanning after [timeout]
    Future.delayed(timeout, () async {
      await sub.cancel();
      if (!completer.isCompleted) completer.complete(devices);
    });

    return completer.future;
  }

  /// Convenience: scan USB printers and return the first one (for quick tests).
  static Future<PrinterDeviceInfo?> findFirstUsbPrinter({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final list = await discoverPrinters(
      PrinterType.usb,
      timeout: timeout,
      isBle: false,
    );
    if (list.isEmpty) return null;
    return list.first;
  }

  /// Initialize printer with CP1252 codepage for proper £ symbol support
  /// Must be called at the start of every print job (before any text)
  static List<int> applyPrinterInit(Generator generator) {
    final bytes = <int>[];

    // Best-practice init
    bytes.addAll([0x1B, 0x40]); // ESC @ (initialize)

    // Force Windows-1252 (CP1252)
    bytes.addAll(generator.setGlobalCodeTable('CP1252'));

    // Also explicitly set ESC/POS code table to 17 (CP1252)
    bytes.addAll([0x1B, 0x74, 0x11]); // ESC t 17

    return bytes;
  }

  /// High-level: prints a test ESC/POS receipt to the given printer.
  static Future<void> printTestReceipt(
    PrinterDeviceInfo printer, {
    bool isBle = false,
  }) async {
    // Build ESC/POS bytes
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];

    // Initialize printer with CP1252 codepage
    bytes += applyPrinterInit(generator);

    bytes += generator.text(
      'MUNBYN ESC/POS TEST',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      '------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text('Item A                1 x £1.50');
    bytes += generator.text('Item B                2 x £2.00');
    bytes += generator.text('------------------------------');
    bytes += generator.text(
      'TOTAL                     £5.50',
      styles: const PosStyles(bold: true),
    );

    bytes += generator.text('');
    bytes += generator.text(
      'Thank you for testing!',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(3);
    bytes += generator.cut();

    await sendToPrinter(printer, bytes, isBle: isBle);
  }

  /// Prints a kitchen ticket (Order Away format)
  /// Used for kitchen preparation - no prices, just items and quantities
  static Future<void> printKitchenTicket({
    required PrinterDeviceInfo printer,
    required List<KitchenTicketItem> items,
    String? tableNumber,
    String? staffName,
    bool isBle = false,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];

    // Initialize printer with CP1252 codepage
    bytes += applyPrinterInit(generator);

    // Large bold title with increased size
    bytes += generator.text(
      'ORDER AWAY',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size3,
        width: PosTextSize.size3,
      ),
    );

    bytes += generator.feed(1);

    // Table number or Tab name if applicable
    if (tableNumber != null && tableNumber.isNotEmpty) {
      bytes += generator.text(
        'Table: $tableNumber',
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
        ),
      );
      bytes += generator.feed(1);
    }

    bytes += generator.hr();
    bytes += generator.feed(1);

    // Items in kitchen format: QTY   ITEM NAME (no price)
    for (final item in items) {
      final qtyStr = item.quantity.toString().padRight(3);
      bytes += generator.text(
        '$qtyStr ${item.itemName}',
        styles: const PosStyles(
          align: PosAlign.left,
          bold: true,
          height: PosTextSize.size2,
        ),
      );
      
      // Print modifiers if present (no prices on kitchen tickets)
      if (item.modifiers.isNotEmpty) {
        for (final modifier in item.modifiers) {
          bytes += generator.text(
            '    > $modifier',
            styles: const PosStyles(
              align: PosAlign.left,
              fontType: PosFontType.fontA,
            ),
          );
        }
      }
      
      // Print notes if present
      if (item.notes.isNotEmpty) {
        bytes += generator.text(
          '    Note: ${item.notes}',
          styles: const PosStyles(
            align: PosAlign.left,
            fontType: PosFontType.fontA,
          ),
        );
      }
    }

    bytes += generator.feed(1);
    bytes += generator.hr();
    bytes += generator.feed(1);

    // Staff member name
    if (staffName != null && staffName.isNotEmpty) {
      bytes += generator.text('Staff: $staffName');
    }

    // Timestamp
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    bytes += generator.text('Time: $timeStr');

    bytes += generator.feed(3);
    bytes += generator.cut();

    await sendToPrinter(printer, bytes, isBle: isBle);
  }

  /// Low-level send wrapper. You can reuse this later for real receipts.
  static Future<void> sendToPrinter(
    PrinterDeviceInfo printer,
    List<int> bytes, {
    bool isBle = false,
  }) async {
    // Always disconnect any previous connection
    await _printerManager.disconnect(type: printer.type);

    switch (printer.type) {
      case PrinterType.usb:
        await _printerManager.connect(
          type: PrinterType.usb,
          model: UsbPrinterInput(
            name: printer.name,
            productId: printer.productId,
            vendorId: printer.vendorId,
          ),
        );
        break;

      case PrinterType.bluetooth:
        await _printerManager.connect(
          type: PrinterType.bluetooth,
          model: BluetoothPrinterInput(
            name: printer.name,
            address: printer.address ?? '',
            isBle: isBle,
            autoConnect: false,
          ),
        );
        break;

      case PrinterType.network:
        if (printer.ipAddress == null) {
          throw ArgumentError('Network printer requires IP address');
        }
        await _printerManager.connect(
          type: PrinterType.network,
          model: TcpPrinterInput(
            ipAddress: printer.ipAddress!,
            port: printer.port ?? 9100,
          ),
        );
        break;
    }

    await _printerManager.send(type: printer.type, bytes: bytes);
    await _printerManager.disconnect(type: printer.type);
  }
}
