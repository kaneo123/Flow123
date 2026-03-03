class Category {
  final String id;
  final String outletId;
  final String name;
  final String? description;
  final int sortOrder;
  final bool active;
  final DateTime? createdAt;
  final String? parentId;

  Category({
    required this.id,
    required this.outletId,
    required this.name,
    this.description,
    this.sortOrder = 0,
    this.active = true,
    this.createdAt,
    this.parentId,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String? ?? '',
      outletId: json['outlet_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      active: json['active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      parentId: json['parent_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'name': name,
    'description': description,
    'sort_order': sortOrder,
    'active': active,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    'parent_id': parentId,
  };

  Category copyWith({
    String? id,
    String? outletId,
    String? name,
    String? description,
    int? sortOrder,
    bool? active,
    DateTime? createdAt,
    String? parentId,
  }) => Category(
    id: id ?? this.id,
    outletId: outletId ?? this.outletId,
    name: name ?? this.name,
    description: description ?? this.description,
    sortOrder: sortOrder ?? this.sortOrder,
    active: active ?? this.active,
    createdAt: createdAt ?? this.createdAt,
    parentId: parentId ?? this.parentId,
  );
}
