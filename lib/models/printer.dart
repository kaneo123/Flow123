import 'package:flowtill/utils/sqlite_converters.dart';

class Printer {
  final String id;
  final String outletId;
  final String name;
  final String type;            // 'kitchen' | 'receipt' | 'bar' | 'other'
  final String connectionType;  // 'network' | 'usb' | 'bluetooth' | 'other'
  final String? ipAddress;
  final int? port;
  final String? hardwareVendorId;   // USB vendor ID
  final String? hardwareProductId;  // USB product ID
  final String? hardwareAddress;    // Bluetooth MAC address or USB address
  final String? hardwareName;       // USB/Bluetooth device name
  final String paperSize;           // '80mm' | '58mm'
  final bool isDefaultReceipt;
  final bool active;
  final DateTime? createdAt;

  Printer({
    required this.id,
    required this.outletId,
    required this.name,
    required this.type,
    required this.connectionType,
    this.ipAddress,
    this.port,
    this.hardwareVendorId,
    this.hardwareProductId,
    this.hardwareAddress,
    this.hardwareName,
    this.paperSize = '80mm',
    this.isDefaultReceipt = false,
    this.active = true,
    this.createdAt,
  });

  factory Printer.fromJson(Map<String, dynamic> json) => Printer(
    id: json['id'] as String? ?? '',
    outletId: json['outlet_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? 'other',
    connectionType: json['connection_type'] as String? ?? 'other',
    ipAddress: json['ip_address'] as String?,
    port: SQLiteConverters.toInt(json['port']),
    hardwareVendorId: json['hardware_vendor_id'] as String?,
    hardwareProductId: json['hardware_product_id'] as String?,
    hardwareAddress: json['hardware_address'] as String?,
    hardwareName: json['hardware_name'] as String?,
    paperSize: json['paper_size'] as String? ?? '80mm',
    isDefaultReceipt: SQLiteConverters.toBool(json['is_default_receipt']) ?? false,
    active: SQLiteConverters.toBool(json['active']) ?? true,
    createdAt: SQLiteConverters.toDateTime(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'name': name,
    'type': type,
    'connection_type': connectionType,
    if (ipAddress != null) 'ip_address': ipAddress,
    if (port != null) 'port': port,
    if (hardwareVendorId != null) 'hardware_vendor_id': hardwareVendorId,
    if (hardwareProductId != null) 'hardware_product_id': hardwareProductId,
    if (hardwareAddress != null) 'hardware_address': hardwareAddress,
    if (hardwareName != null) 'hardware_name': hardwareName,
    'paper_size': paperSize,
    'is_default_receipt': isDefaultReceipt,
    'active': active,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };

  Printer copyWith({
    String? id,
    String? outletId,
    String? name,
    String? type,
    String? connectionType,
    String? ipAddress,
    int? port,
    String? hardwareVendorId,
    String? hardwareProductId,
    String? hardwareAddress,
    String? hardwareName,
    String? paperSize,
    bool? isDefaultReceipt,
    bool? active,
    DateTime? createdAt,
  }) => Printer(
    id: id ?? this.id,
    outletId: outletId ?? this.outletId,
    name: name ?? this.name,
    type: type ?? this.type,
    connectionType: connectionType ?? this.connectionType,
    ipAddress: ipAddress ?? this.ipAddress,
    port: port ?? this.port,
    hardwareVendorId: hardwareVendorId ?? this.hardwareVendorId,
    hardwareProductId: hardwareProductId ?? this.hardwareProductId,
    hardwareAddress: hardwareAddress ?? this.hardwareAddress,
    hardwareName: hardwareName ?? this.hardwareName,
    paperSize: paperSize ?? this.paperSize,
    isDefaultReceipt: isDefaultReceipt ?? this.isDefaultReceipt,
    active: active ?? this.active,
    createdAt: createdAt ?? this.createdAt,
  );
}
