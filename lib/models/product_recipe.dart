class ProductRecipe {
  final String id;
  final String outletId;
  final String productId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ProductRecipe({
    required this.id,
    required this.outletId,
    required this.productId,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory ProductRecipe.fromJson(Map<String, dynamic> json) {
    String safeString(dynamic value, String defaultValue) {
      if (value == null) return defaultValue;
      return value.toString();
    }
    
    return ProductRecipe(
      id: safeString(json['id'], ''),
      outletId: safeString(json['outlet_id'], ''),
      productId: safeString(json['product_id'], ''),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'product_id': productId,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };
}
