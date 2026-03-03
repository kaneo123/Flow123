import 'package:flowtill/models/selected_modifier.dart';

class EposOrderItem {
  final String id;
  final String orderId;
  final String? productId;
  final String? inventoryItemId;
  final String? categoryId;
  final String productName;
  final String? plu;
  final String? course;
  final double quantity;
  final double unitPrice;
  final double grossLineTotal;
  final double discountAmount;
  final double netLineTotal;
  final double taxRate;
  final double taxAmount;
  final String? notes;
  final int sortOrder;
  final List<SelectedModifier> modifiers;

  EposOrderItem({
    required this.id,
    required this.orderId,
    this.productId,
    this.inventoryItemId,
    this.categoryId,
    required this.productName,
    this.plu,
    this.course,
    this.quantity = 1,
    this.unitPrice = 0.0,
    this.grossLineTotal = 0.0,
    this.discountAmount = 0.0,
    this.netLineTotal = 0.0,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    this.notes,
    this.sortOrder = 0,
    this.modifiers = const [],
  });

  EposOrderItem copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? inventoryItemId,
    String? categoryId,
    String? productName,
    String? plu,
    String? course,
    double? quantity,
    double? unitPrice,
    double? grossLineTotal,
    double? discountAmount,
    double? netLineTotal,
    double? taxRate,
    double? taxAmount,
    String? notes,
    int? sortOrder,
    List<SelectedModifier>? modifiers,
  }) => EposOrderItem(
    id: id ?? this.id,
    orderId: orderId ?? this.orderId,
    productId: productId ?? this.productId,
    inventoryItemId: inventoryItemId ?? this.inventoryItemId,
    categoryId: categoryId ?? this.categoryId,
    productName: productName ?? this.productName,
    plu: plu ?? this.plu,
    course: course ?? this.course,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    grossLineTotal: grossLineTotal ?? this.grossLineTotal,
    discountAmount: discountAmount ?? this.discountAmount,
    netLineTotal: netLineTotal ?? this.netLineTotal,
    taxRate: taxRate ?? this.taxRate,
    taxAmount: taxAmount ?? this.taxAmount,
    notes: notes ?? this.notes,
    sortOrder: sortOrder ?? this.sortOrder,
    modifiers: modifiers ?? this.modifiers,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_id': orderId,
    'product_id': productId,
    'inventory_item_id': inventoryItemId,
    'category_id': categoryId,
    'product_name': productName,
    'plu': plu,
    'course': course,
    'quantity': quantity,
    'unit_price': unitPrice,
    'gross_line_total': grossLineTotal,
    'discount_amount': discountAmount,
    'net_line_total': netLineTotal,
    'tax_rate': taxRate,
    'tax_amount': taxAmount,
    'notes': notes,
    'sort_order': sortOrder,
    'modifiers': modifiers.map((m) => m.toJson()).toList(),
  };

  factory EposOrderItem.fromJson(Map<String, dynamic> json) {
    final modifiersJson = json['modifiers'];
    final modifiers = <SelectedModifier>[];
    if (modifiersJson != null && modifiersJson is List) {
      modifiers.addAll(
        modifiersJson.map((m) => SelectedModifier.fromJson(m as Map<String, dynamic>)),
      );
    }

    return EposOrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String?,
      inventoryItemId: json['inventory_item_id'] as String?,
      categoryId: json['category_id'] as String?,
      productName: json['product_name'] as String,
      plu: json['plu'] as String?,
      course: json['course'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      grossLineTotal: (json['gross_line_total'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      netLineTotal: (json['net_line_total'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      modifiers: modifiers,
    );
  }
}
