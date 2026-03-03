class SpecialProductInfo {
  final String productId;
  final Set<String> groupIds;
  final bool hasLinkedPromotion;

  const SpecialProductInfo({
    required this.productId,
    required this.groupIds,
    required this.hasLinkedPromotion,
  });
}
