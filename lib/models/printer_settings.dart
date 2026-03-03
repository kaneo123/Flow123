// lib/models/printer_settings.dart
import 'dart:convert';

class PrinterConfig {
  final String? name;
  final String? vendorId;
  final String? productId;
  final String? address;
  final String type; // 'usb' or 'bluetooth'

  const PrinterConfig({
    this.name,
    this.vendorId,
    this.productId,
    this.address,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'vendorId': vendorId,
    'productId': productId,
    'address': address,
    'type': type,
  };

  factory PrinterConfig.fromJson(Map<String, dynamic> json) => PrinterConfig(
    name: json['name'] as String?,
    vendorId: json['vendorId'] as String?,
    productId: json['productId'] as String?,
    address: json['address'] as String?,
    type: json['type'] as String? ?? 'usb',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterConfig &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          address == other.address &&
          vendorId == other.vendorId &&
          productId == other.productId;

  @override
  int get hashCode => Object.hash(name, address, vendorId, productId);
}

class PrinterSettings {
  final PrinterConfig? kitchenPrinter;
  final PrinterConfig? barPrinter;
  final int orderCopies;
  final int tableNumberSize;
  final int notesSize;
  final int modifiersSize;

  const PrinterSettings({
    this.kitchenPrinter,
    this.barPrinter,
    this.orderCopies = 1,
    this.tableNumberSize = 1,
    this.notesSize = 1,
    this.modifiersSize = 1,
  });

  Map<String, dynamic> toJson() => {
    'kitchenPrinter': kitchenPrinter?.toJson(),
    'barPrinter': barPrinter?.toJson(),
    'orderCopies': orderCopies,
    'tableNumberSize': tableNumberSize,
    'notesSize': notesSize,
    'modifiersSize': modifiersSize,
  };

  factory PrinterSettings.fromJson(Map<String, dynamic> json) {
    return PrinterSettings(
      kitchenPrinter: json['kitchenPrinter'] != null
          ? PrinterConfig.fromJson(json['kitchenPrinter'] as Map<String, dynamic>)
          : null,
      barPrinter: json['barPrinter'] != null
          ? PrinterConfig.fromJson(json['barPrinter'] as Map<String, dynamic>)
          : null,
      orderCopies: json['orderCopies'] as int? ?? 1,
      tableNumberSize: json['tableNumberSize'] as int? ?? 1,
      notesSize: json['notesSize'] as int? ?? 1,
      modifiersSize: json['modifiersSize'] as int? ?? 1,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory PrinterSettings.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return PrinterSettings.fromJson(json);
  }

  PrinterSettings copyWith({
    PrinterConfig? kitchenPrinter,
    PrinterConfig? barPrinter,
    int? orderCopies,
    int? tableNumberSize,
    int? notesSize,
    int? modifiersSize,
    bool clearKitchen = false,
    bool clearBar = false,
  }) {
    return PrinterSettings(
      kitchenPrinter: clearKitchen ? null : (kitchenPrinter ?? this.kitchenPrinter),
      barPrinter: clearBar ? null : (barPrinter ?? this.barPrinter),
      orderCopies: orderCopies ?? this.orderCopies,
      tableNumberSize: tableNumberSize ?? this.tableNumberSize,
      notesSize: notesSize ?? this.notesSize,
      modifiersSize: modifiersSize ?? this.modifiersSize,
    );
  }
}
