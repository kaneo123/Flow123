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
    requiredOverride: json['required_override'] as bool?,
    minSelectOverride: json['min_select_override'] as int?,
    maxSelectOverride: json['max_select_override'] as int?,
    sortOrder: json['sort_order'] as int? ?? 0,
    active: json['active'] as bool? ?? true,
    createdAt: json['created_at'] != null 
        ? DateTime.tryParse(json['created_at'] as String) 
        : null,
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
