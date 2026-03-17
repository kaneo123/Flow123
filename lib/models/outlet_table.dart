import 'package:flowtill/utils/sqlite_converters.dart';

class OutletTable {
  final String id;
  final String outletId;
  final String roomName;
  final int? roomNumber;
  final String tableNumber;
  final int? capacity;
  final bool active;
  final int sortOrder;
  final double? posX;
  final double? posY;
  final DateTime createdAt;
  final DateTime updatedAt;

  OutletTable({
    required this.id,
    required this.outletId,
    required this.roomName,
    this.roomNumber,
    required this.tableNumber,
    this.capacity,
    this.active = true,
    this.sortOrder = 0,
    this.posX,
    this.posY,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Returns the display name for this table
  String get displayName => tableNumber;

  OutletTable copyWith({
    String? id,
    String? outletId,
    String? roomName,
    int? roomNumber,
    String? tableNumber,
    int? capacity,
    bool? active,
    int? sortOrder,
    double? posX,
    double? posY,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => OutletTable(
    id: id ?? this.id,
    outletId: outletId ?? this.outletId,
    roomName: roomName ?? this.roomName,
    roomNumber: roomNumber ?? this.roomNumber,
    tableNumber: tableNumber ?? this.tableNumber,
    capacity: capacity ?? this.capacity,
    active: active ?? this.active,
    sortOrder: sortOrder ?? this.sortOrder,
    posX: posX ?? this.posX,
    posY: posY ?? this.posY,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson({bool includeId = true}) {
    final json = <String, dynamic>{
      'outlet_id': outletId,
      'room_name': roomName,
      'room_number': roomNumber,
      'table_number': tableNumber,
      'capacity': capacity,
      'active': active,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    
    // Only include id if specified and not empty (for updates)
    if (includeId && id.isNotEmpty) {
      json['id'] = id;
    }
    
    // Only include optional fields if they exist
    if (posX != null) json['pos_x'] = posX;
    if (posY != null) json['pos_y'] = posY;
    
    return json;
  }

  factory OutletTable.fromJson(Map<String, dynamic> json) {
    // Handle table_number which can be either int or String from database
    final tableNumberRaw = json['table_number'];
    final tableNumber = tableNumberRaw is String ? tableNumberRaw : tableNumberRaw.toString();
    
    return OutletTable(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      roomName: json['room_name'] as String,
      roomNumber: SQLiteConverters.toInt(json['room_number']),
      tableNumber: tableNumber,
      capacity: SQLiteConverters.toInt(json['capacity']),
      active: SQLiteConverters.toBool(json['active']) ?? true,
      sortOrder: SQLiteConverters.toInt(json['sort_order']) ?? 0,
      posX: SQLiteConverters.toDouble(json['pos_x']),
      posY: SQLiteConverters.toDouble(json['pos_y']),
      createdAt: SQLiteConverters.toDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: SQLiteConverters.toDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }
}
