class SpecialGroupItem {
  final String id;
  final String specialGroupId;
  final String outletId;
  final String? productId;
  final String? categoryId;
  final String? promotionId;
  final int sortOrder;
  final bool active;

  SpecialGroupItem({
    required this.id,
    required this.specialGroupId,
    required this.outletId,
    this.productId,
    this.categoryId,
    this.promotionId,
    this.sortOrder = 0,
    required this.active,
  });

  factory SpecialGroupItem.fromJson(Map<String, dynamic> json) => SpecialGroupItem(
    id: json['id'] as String? ?? '',
    specialGroupId: json['special_group_id'] as String? ?? '',
    outletId: json['outlet_id'] as String? ?? '',
    productId: json['product_id'] as String?,
    categoryId: json['category_id'] as String?,
    promotionId: json['promotion_id'] as String?,
    sortOrder: json['sort_order'] as int? ?? 0,
    active: json['active'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'special_group_id': specialGroupId,
    'outlet_id': outletId,
    if (productId != null) 'product_id': productId,
    if (categoryId != null) 'category_id': categoryId,
    if (promotionId != null) 'promotion_id': promotionId,
    'sort_order': sortOrder,
    'active': active,
  };
}
