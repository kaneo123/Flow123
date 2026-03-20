import 'package:flowtill/utils/sqlite_converters.dart';

class ProductModifierGroupLink {
  final String id;
  final String outletId;
  final String productId;
  final String groupId;
  final bool? requiredOverride;
  final int? minSelectOverride;
  final int? maxSelectOverride;
  final int sortOrder;
  final bool active;
  final DateTime? createdAt;

  ProductModifierGroupLink({
    required this.id,
    required this.outletId,
    required this.productId,
    required this.groupId,
    this.requiredOverride,
    this.minSelectOverride,
    this.maxSelectOverride,
    this.sortOrder = 0,
    this.active = true,
    this.createdAt,
  });

  factory ProductModifierGroupLink.fromJson(Map<String, dynamic> json) => ProductModifierGroupLink(
    id: json['id'] as String,
    outletId: json['outlet_id'] as String,
    productId: json['product_id'] as String,
    groupId: json['group_id'] as String,
    requiredOverride: SQLiteConverters.toBool(json['required_override']),
    minSelectOverride: SQLiteConverters.toInt(json['min_select_override']),
    maxSelectOverride: SQLiteConverters.toInt(json['max_select_override']),
    sortOrder: SQLiteConverters.asInt(json['sort_order']),
    active: SQLiteConverters.asBool(json['active'], defaultValue: true),
    createdAt: SQLiteConverters.toDateTime(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'product_id': productId,
    'group_id': groupId,
    if (requiredOverride != null) 'required_override': requiredOverride,
    if (minSelectOverride != null) 'min_select_override': minSelectOverride,
    if (maxSelectOverride != null) 'max_select_override': maxSelectOverride,
    'sort_order': sortOrder,
    'active': active,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };
}
