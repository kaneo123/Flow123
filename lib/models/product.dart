import 'package:flowtill/utils/sqlite_converters.dart';

class Product {
  final String id;
  final String outletId;
  final String? categoryId;
  final String name;
  final String? plu;
  final double price;
  final String? taxRateId;
  final String? course;
  final String? printerId;
  final bool active;
  final int sortOrder;
  final bool trackStock;
  final bool autoHideWhenOutOfStock;
  final String? linkedInventoryItemId;
  final DateTime? createdAt;
  final bool isCarvery;

  Product({
    required this.id,
    required this.outletId,
    this.categoryId,
    required this.name,
    this.plu,
    required this.price,
    this.taxRateId,
    this.course,
    this.printerId,
    this.active = true,
    this.sortOrder = 0,
    this.trackStock = false,
    this.autoHideWhenOutOfStock = false,
    this.linkedInventoryItemId,
    this.createdAt,
    this.isCarvery = false,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String? ?? '',
    outletId: json['outlet_id'] as String? ?? '',
    categoryId: json['category_id'] as String?,
    name: json['name'] as String? ?? '',
    plu: json['plu'] as String?,
    price: SQLiteConverters.toDouble(json['price']) ?? 0.0,
    taxRateId: json['tax_rate_id'] as String?,
    course: json['course'] as String?,
    printerId: json['printer_id'] as String?,
    active: SQLiteConverters.toBool(json['active']) ?? true,
    sortOrder: SQLiteConverters.toInt(json['sort_order']) ?? 0,
    trackStock: SQLiteConverters.toBool(json['track_stock']) ?? false,
    autoHideWhenOutOfStock: SQLiteConverters.toBool(json['auto_hide_when_out_of_stock']) ?? false,
    linkedInventoryItemId: json['linked_inventory_item_id'] as String?,
    createdAt: SQLiteConverters.toDateTime(json['created_at']),
    isCarvery: SQLiteConverters.toBool(json['is_carvery']) ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    if (categoryId != null) 'category_id': categoryId,
    'name': name,
    if (plu != null) 'plu': plu,
    'price': price,
    if (taxRateId != null) 'tax_rate_id': taxRateId,
    if (course != null) 'course': course,
    if (printerId != null) 'printer_id': printerId,
    'active': active,
    'sort_order': sortOrder,
    'track_stock': trackStock,
    'auto_hide_when_out_of_stock': autoHideWhenOutOfStock,
    if (linkedInventoryItemId != null) 'linked_inventory_item_id': linkedInventoryItemId,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    'is_carvery': isCarvery,
  };

  Product copyWith({
    String? id,
    String? outletId,
    String? categoryId,
    String? name,
    String? plu,
    double? price,
    String? taxRateId,
    String? course,
    String? printerId,
    bool? active,
    int? sortOrder,
    bool? trackStock,
    bool? autoHideWhenOutOfStock,
    String? linkedInventoryItemId,
    DateTime? createdAt,
    bool? isCarvery,
  }) => Product(
    id: id ?? this.id,
    outletId: outletId ?? this.outletId,
    categoryId: categoryId ?? this.categoryId,
    name: name ?? this.name,
    plu: plu ?? this.plu,
    price: price ?? this.price,
    taxRateId: taxRateId ?? this.taxRateId,
    course: course ?? this.course,
    printerId: printerId ?? this.printerId,
    active: active ?? this.active,
    sortOrder: sortOrder ?? this.sortOrder,
    trackStock: trackStock ?? this.trackStock,
    autoHideWhenOutOfStock: autoHideWhenOutOfStock ?? this.autoHideWhenOutOfStock,
    linkedInventoryItemId: linkedInventoryItemId ?? this.linkedInventoryItemId,
    createdAt: createdAt ?? this.createdAt,
    isCarvery: isCarvery ?? this.isCarvery,
  );
}
