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
    isRequired: json['is_required'] as bool? ?? false,
    minSelect: json['min_select'] as int?,
    maxSelect: json['max_select'] as int?,
    sortOrder: json['sort_order'] as int? ?? 0,
    active: json['active'] as bool? ?? true,
    createdAt: json['created_at'] != null 
        ? DateTime.tryParse(json['created_at'] as String) 
        : null,
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
