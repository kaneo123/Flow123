import 'package:flowtill/utils/sqlite_converters.dart';

class ModifierOption {
  final String id;
  final String groupId;
  final String outletId;
  final String name;
  final double priceDelta;
  final bool isDefault;
  final int sortOrder;
  final bool active;
  final DateTime? createdAt;

  ModifierOption({
    required this.id,
    required this.groupId,
    required this.outletId,
    required this.name,
    this.priceDelta = 0.0,
    this.isDefault = false,
    this.sortOrder = 0,
    this.active = true,
    this.createdAt,
  });

  factory ModifierOption.fromJson(Map<String, dynamic> json) => ModifierOption(
    id: json['id'] as String,
    groupId: json['group_id'] as String,
    outletId: json['outlet_id'] as String,
    name: json['name'] as String,
    priceDelta: SQLiteConverters.toDouble(json['price_delta']) ?? 0.0,
    isDefault: SQLiteConverters.toBool(json['is_default']) ?? false,
    sortOrder: SQLiteConverters.toInt(json['sort_order']) ?? 0,
    active: SQLiteConverters.toBool(json['active']) ?? true,
    createdAt: SQLiteConverters.toDateTime(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'group_id': groupId,
    'outlet_id': outletId,
    'name': name,
    'price_delta': priceDelta,
    'is_default': isDefault,
    'sort_order': sortOrder,
    'active': active,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };
}
