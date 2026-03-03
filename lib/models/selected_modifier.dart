/// Represents a selected modifier for an order item
class SelectedModifier {
  final String groupId;
  final String groupName;
  final String optionId;
  final String optionName;
  final double priceDelta;

  SelectedModifier({
    required this.groupId,
    required this.groupName,
    required this.optionId,
    required this.optionName,
    required this.priceDelta,
  });

  factory SelectedModifier.fromJson(Map<String, dynamic> json) => SelectedModifier(
    groupId: json['group_id'] as String,
    groupName: json['group_name'] as String,
    optionId: json['option_id'] as String,
    optionName: json['option_name'] as String,
    priceDelta: (json['price_delta'] as num?)?.toDouble() ?? 0.0,
  );

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'group_name': groupName,
    'option_id': optionId,
    'option_name': optionName,
    'price_delta': priceDelta,
  };

  /// Get display text for this modifier (for basket and printing)
  String get displayText {
    if (priceDelta == 0) return optionName;
    final sign = priceDelta > 0 ? '+' : '';
    return '$optionName $sign£${priceDelta.abs().toStringAsFixed(2)}';
  }

  /// Get display text for kitchen (no price)
  String get kitchenDisplayText => optionName;
}
