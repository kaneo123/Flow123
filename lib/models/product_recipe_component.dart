class ProductRecipeComponent {
  final String id;
  final String recipeId;
  final String inventoryItemId;
  final double quantityPerUnit;
  final double? wastageFactor;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ProductRecipeComponent({
    required this.id,
    required this.recipeId,
    required this.inventoryItemId,
    required this.quantityPerUnit,
    this.wastageFactor,
    required this.createdAt,
    this.updatedAt,
  });

  factory ProductRecipeComponent.fromJson(Map<String, dynamic> json) {
    // Helper to parse numeric fields that may come as strings from Supabase
    double parseNumeric(dynamic value, {double defaultValue = 0.0}) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? defaultValue;
      }
      return defaultValue;
    }
    
    // Safe string parsing
    String safeString(dynamic value, String defaultValue) {
      if (value == null) return defaultValue;
      return value.toString();
    }
    
    return ProductRecipeComponent(
      id: safeString(json['id'], ''),
      recipeId: safeString(json['recipe_id'], ''),
      inventoryItemId: safeString(json['inventory_item_id'], ''),
      quantityPerUnit: parseNumeric(json['quantity_per_unit']),
      wastageFactor: json['wastage_factor'] != null ? parseNumeric(json['wastage_factor']) : null,
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
    'recipe_id': recipeId,
    'inventory_item_id': inventoryItemId,
    'quantity_per_unit': quantityPerUnit,
    if (wastageFactor != null) 'wastage_factor': wastageFactor,
    'created_at': createdAt.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };
}
