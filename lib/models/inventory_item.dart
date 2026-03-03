class InventoryItem {
  final String id;
  final String outletId;
  final String name;
  final String? sku;
  final String? category;
  final String? location;
  final double currentQty;
  final String unit;
  final double? parLevel;
  final String? linkedProductId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  InventoryItem({
    required this.id,
    required this.outletId,
    required this.name,
    this.sku,
    this.category,
    this.location,
    required this.currentQty,
    required this.unit,
    this.parLevel,
    this.linkedProductId,
    required this.createdAt,
    this.updatedAt,
  });

  InventoryItem copyWith({
    String? id,
    String? outletId,
    String? name,
    String? sku,
    String? category,
    String? location,
    double? currentQty,
    String? unit,
    double? parLevel,
    String? linkedProductId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => InventoryItem(
    id: id ?? this.id,
    outletId: outletId ?? this.outletId,
    name: name ?? this.name,
    sku: sku ?? this.sku,
    category: category ?? this.category,
    location: location ?? this.location,
    currentQty: currentQty ?? this.currentQty,
    unit: unit ?? this.unit,
    parLevel: parLevel ?? this.parLevel,
    linkedProductId: linkedProductId ?? this.linkedProductId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'name': name,
    'sku': sku,
    'category': category,
    'location': location,
    'current_qty': currentQty,
    'unit': unit,
    'par_level': parLevel,
    'linked_product_id': linkedProductId,
    'created_at': createdAt.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
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
    
    return InventoryItem(
      id: safeString(json['id'], ''),
      outletId: safeString(json['outlet_id'], ''),
      name: safeString(json['name'], 'Unknown Item'),
      sku: json['sku']?.toString(),
      category: json['category']?.toString(),
      location: json['location']?.toString(),
      currentQty: parseNumeric(json['current_qty']),
      unit: safeString(json['unit'], 'unit'),
      parLevel: json['par_level'] != null ? parseNumeric(json['par_level']) : null,
      linkedProductId: json['linked_product_id']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }
}
