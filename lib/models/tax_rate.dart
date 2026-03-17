import 'package:flowtill/utils/sqlite_converters.dart';

class TaxRate {
  final String id;
  final String name;
  final double rate;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaxRate({
    required this.id,
    required this.name,
    required this.rate,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaxRate.fromJson(Map<String, dynamic> json) => TaxRate(
    id: json['id'] as String,
    name: json['name'] as String,
    rate: SQLiteConverters.toDouble(json['rate']) ?? 0.0,
    isDefault: SQLiteConverters.toBool(json['is_default']) ?? false,
    createdAt: SQLiteConverters.toDateTime(json['created_at']) ?? DateTime.now(),
    updatedAt: SQLiteConverters.toDateTime(json['updated_at']) ?? 
               SQLiteConverters.toDateTime(json['created_at']) ?? 
               DateTime.now(), // Fallback to created_at if updated_at is missing
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rate': rate,
    'is_default': isDefault,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  TaxRate copyWith({
    String? id,
    String? name,
    double? rate,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TaxRate(
    id: id ?? this.id,
    name: name ?? this.name,
    rate: rate ?? this.rate,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
