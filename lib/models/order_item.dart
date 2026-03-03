import 'package:flowtill/models/product.dart';
import 'package:flowtill/models/selected_modifier.dart';

class OrderItem {
  final String id;
  final Product product;
  int quantity;
  final List<SelectedModifier> selectedModifiers;
  final double taxRate;
  final String notes;
  final String? packagedDealId; // If set, this item represents a packaged deal
  final List<String>? dealComponentItemIds; // IDs of the original items that were combined into this deal
  final List<OrderItem>? dealComponentItems; // The actual items that were combined into this deal (for display)

  OrderItem({
    required this.id,
    required this.product,
    this.quantity = 1,
    this.selectedModifiers = const [],
    required this.taxRate,
    this.notes = '',
    this.packagedDealId,
    this.dealComponentItemIds,
    this.dealComponentItems,
  });

  /// Calculate unit price including modifier deltas
  double get unitPrice {
    final modifierTotal = selectedModifiers.fold<double>(
      0.0,
      (sum, mod) => sum + mod.priceDelta,
    );
    return product.price + modifierTotal;
  }

  double get subtotal => unitPrice * quantity;
  double get taxAmount => subtotal * taxRate;
  double get total => subtotal + taxAmount;

  /// Legacy getter for backward compatibility (returns modifier display texts)
  @Deprecated('Use selectedModifiers instead')
  List<String> get modifiers => selectedModifiers.map((m) => m.displayText).toList();

  /// Check if this item is a packaged deal
  bool get isPackagedDeal => packagedDealId != null;

  OrderItem copyWith({
    String? id,
    Product? product,
    int? quantity,
    List<SelectedModifier>? selectedModifiers,
    double? taxRate,
    String? notes,
    String? packagedDealId,
    List<String>? dealComponentItemIds,
    List<OrderItem>? dealComponentItems,
  }) => OrderItem(
    id: id ?? this.id,
    product: product ?? this.product,
    quantity: quantity ?? this.quantity,
    selectedModifiers: selectedModifiers ?? this.selectedModifiers,
    taxRate: taxRate ?? this.taxRate,
    notes: notes ?? this.notes,
    packagedDealId: packagedDealId ?? this.packagedDealId,
    dealComponentItemIds: dealComponentItemIds ?? this.dealComponentItemIds,
    dealComponentItems: dealComponentItems ?? this.dealComponentItems,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'product': product.toJson(),
    'quantity': quantity,
    'selected_modifiers': selectedModifiers.map((m) => m.toJson()).toList(),
    'tax_rate': taxRate,
    'notes': notes,
    if (packagedDealId != null) 'packaged_deal_id': packagedDealId,
    if (dealComponentItemIds != null) 'deal_component_item_ids': dealComponentItemIds,
    if (dealComponentItems != null) 'deal_component_items': dealComponentItems!.map((item) => item.toJson()).toList(),
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Handle both new and legacy format
    List<SelectedModifier> mods = [];
    
    if (json.containsKey('selected_modifiers')) {
      mods = (json['selected_modifiers'] as List<dynamic>)
          .map((m) => SelectedModifier.fromJson(m as Map<String, dynamic>))
          .toList();
    } else if (json.containsKey('modifiers')) {
      // Legacy format - skip (we can't reconstruct SelectedModifier from strings)
      // This is OK because old orders won't have the new modifier system
    }

    // Parse deal component items if present
    List<OrderItem>? componentItems;
    if (json['deal_component_items'] != null) {
      componentItems = (json['deal_component_items'] as List<dynamic>)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return OrderItem(
      id: json['id'] as String,
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: json['quantity'] as int,
      selectedModifiers: mods,
      taxRate: (json['tax_rate'] as num).toDouble(),
      notes: json['notes'] as String? ?? '',
      packagedDealId: json['packaged_deal_id'] as String?,
      dealComponentItemIds: json['deal_component_item_ids'] != null
          ? (json['deal_component_item_ids'] as List<dynamic>).cast<String>()
          : null,
      dealComponentItems: componentItems,
    );
  }
}
