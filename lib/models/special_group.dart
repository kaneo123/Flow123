class SpecialGroup {
  final String id;
  final String outletId;
  final String name;
  final String? description;
  final bool showOnTill;
  final bool active;
  final int sortOrder;
  final DateTime? createdAt;

  SpecialGroup({
    required this.id,
    required this.outletId,
    required this.name,
    this.description,
    required this.showOnTill,
    required this.active,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory SpecialGroup.fromJson(Map<String, dynamic> json) => SpecialGroup(
    id: json['id'] as String? ?? '',
    outletId: json['outlet_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    showOnTill: json['show_on_till'] as bool? ?? false,
    active: json['active'] as bool? ?? true,
    sortOrder: json['sort_order'] as int? ?? 0,
    createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'name': name,
    if (description != null) 'description': description,
    'show_on_till': showOnTill,
    'active': active,
    'sort_order': sortOrder,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };
}
