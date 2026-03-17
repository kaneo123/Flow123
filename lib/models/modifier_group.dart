import 'package:flowtill/utils/sqlite_converters.dart';

class ModifierGroup {
  final String id;
  final String outletId;
  final String name;
  final String? description;
  final String selectionType; // 'single' | 'multiple'
  final bool isRequired;
  final int? minSelect;
  final int? maxSelect;
  final int sortOrder;
  final bool active;
  final DateTime? createdAt;

  ModifierGroup({
    required this.id,
    required this.outletId,
    required this.name,
    this.description,
    required this.selectionType,
    this.isRequired = false,
    this.minSelect,
    this.maxSelect,
    this.sortOrder = 0,
    this.active = true,
    this.createdAt,
  });

  factory ModifierGroup.fromJson(Map<String, dynamic> json) => ModifierGroup(
    id: json['id'] as String,
    outletId: json['outlet_id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    selectionType: json['selection_type'] as String,
    isRequired: SQLiteConverters.toBool(json['is_required']) ?? false,
    minSelect: SQLiteConverters.toInt(json['min_select']),
    maxSelect: SQLiteConverters.toInt(json['max_select']),
    sortOrder: SQLiteConverters.toInt(json['sort_order']) ?? 0,
    active: SQLiteConverters.toBool(json['active']) ?? true,
    createdAt: SQLiteConverters.toDateTime(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'name': name,
    if (description != null) 'description': description,
    'selection_type': selectionType,
    'is_required': isRequired,
    if (minSelect != null) 'min_select': minSelect,
    if (maxSelect != null) 'max_select': maxSelect,
    'sort_order': sortOrder,
    'active': active,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };
}
