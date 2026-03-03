class PackagedDealComponent {
  final String id;
  final String packagedDealId;
  final String componentName;
  final int quantity;
  final List<String> productIds;
  final Map<String, dynamic>? productQuantities;
  final DateTime createdAt;
  final DateTime updatedAt;

  PackagedDealComponent({
    required this.id,
    required this.packagedDealId,
    required this.componentName,
    required this.quantity,
    required this.productIds,
    this.productQuantities,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PackagedDealComponent.fromJson(Map<String, dynamic> json) {
    return PackagedDealComponent(
      id: json['id'] as String,
      packagedDealId: json['packaged_deal_id'] as String,
      componentName: json['component_name'] as String,
      quantity: json['quantity'] as int,
      productIds: (json['product_ids'] as List<dynamic>).cast<String>(),
      productQuantities: json['product_quantities'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'packaged_deal_id': packagedDealId,
    'component_name': componentName,
    'quantity': quantity,
    'product_ids': productIds,
    if (productQuantities != null) 'product_quantities': productQuantities,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  PackagedDealComponent copyWith({
    String? id,
    String? packagedDealId,
    String? componentName,
    int? quantity,
    List<String>? productIds,
    Map<String, dynamic>? productQuantities,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PackagedDealComponent(
    id: id ?? this.id,
    packagedDealId: packagedDealId ?? this.packagedDealId,
    componentName: componentName ?? this.componentName,
    quantity: quantity ?? this.quantity,
    productIds: productIds ?? this.productIds,
    productQuantities: productQuantities ?? this.productQuantities,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Get the quantity for a specific product ID
  int getProductQuantity(String productId) {
    if (productQuantities == null) return 1;
    final qty = productQuantities![productId];
    if (qty == null) return 1;
    if (qty is int) return qty;
    if (qty is num) return qty.toInt();
    return 1;
  }

  /// Check if a product ID is included in this component
  bool includesProduct(String productId) => productIds.contains(productId);
}
