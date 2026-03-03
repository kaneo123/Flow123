class ProductStockInfo {
  final String productId;
  final bool trackStock;
  final bool isBasicMode;
  final bool isEnhancedMode;
  final double? currentQty;        // basic mode raw qty (if available)
  final int? portionsRemaining;    // enhanced mode bottleneck count
  
  ProductStockInfo({
    required this.productId,
    required this.trackStock,
    this.isBasicMode = false,
    this.isEnhancedMode = false,
    this.currentQty,
    this.portionsRemaining,
  });
  
  /// Get the display quantity for UI badges
  String get displayQuantity {
    if (!trackStock) return '∞';
    
    if (isBasicMode && currentQty != null) {
      return currentQty!.round().toString();
    }
    
    if (isEnhancedMode) {
      if (portionsRemaining != null) {
        return portionsRemaining!.toString();
      }
      // Enhanced mode but portions is null = config issue
      return '!';
    }
    
    return '∞';
  }
  
  /// Check if product is out of stock
  bool get isOutOfStock {
    if (!trackStock) return false;
    
    if (isBasicMode) {
      return currentQty != null && currentQty! <= 0;
    }
    
    if (isEnhancedMode) {
      return portionsRemaining != null && portionsRemaining! <= 0;
    }
    
    return false;
  }
  
  /// Get numeric quantity for comparison
  double get numericQuantity {
    if (isBasicMode && currentQty != null) return currentQty!;
    if (isEnhancedMode && portionsRemaining != null) return portionsRemaining!.toDouble();
    return double.infinity;
  }
}
