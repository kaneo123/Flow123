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
    rate: (json['rate'] as num).toDouble(),
    isDefault: json['is_default'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
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
