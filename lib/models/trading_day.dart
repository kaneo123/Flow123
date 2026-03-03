import 'package:flutter/foundation.dart';

/// Represents a trading day session with opening/closing information
class TradingDay {
  final String id;
  final String outletId;
  final DateTime tradingDate;
  final DateTime openedAt;
  final String openedByStaffId;
  final double openingFloatAmount;
  final String openingFloatSource; // 'carry_forward', 'manual', 'zero'
  
  // Closing fields (nullable until end of day)
  final DateTime? closedAt;
  final String? closedByStaffId;
  final double? closingCashCounted;
  final double? cashVariance;
  final double? carryForwardCash;
  final bool? isCarryForward; // Whether to carry forward or remove cash

  // System totals (calculated from orders/transactions)
  final double? totalCashSales;
  final double? totalCardSales;
  final double? totalSales;

  const TradingDay({
    required this.id,
    required this.outletId,
    required this.tradingDate,
    required this.openedAt,
    required this.openedByStaffId,
    required this.openingFloatAmount,
    required this.openingFloatSource,
    this.closedAt,
    this.closedByStaffId,
    this.closingCashCounted,
    this.cashVariance,
    this.carryForwardCash,
    this.isCarryForward,
    this.totalCashSales,
    this.totalCardSales,
    this.totalSales,
  });

  /// Check if this trading day is still open
  bool get isOpen => closedAt == null;

  /// Check if this trading day is closed
  bool get isClosed => closedAt != null;

  factory TradingDay.fromJson(Map<String, dynamic> json) {
    try {
      return TradingDay(
        id: json['id']?.toString() ?? '',
        outletId: json['outlet_id']?.toString() ?? '',
        tradingDate: DateTime.parse(json['trading_date']?.toString() ?? DateTime.now().toIso8601String()),
        openedAt: DateTime.parse(json['opened_at']?.toString() ?? DateTime.now().toIso8601String()),
        openedByStaffId: json['opened_by_staff_id']?.toString() ?? '',
        openingFloatAmount: (json['opening_float_amount'] as num?)?.toDouble() ?? 0.0,
        openingFloatSource: json['opening_float_source']?.toString() ?? 'zero',
        closedAt: json['closed_at'] != null ? DateTime.parse(json['closed_at'].toString()) : null,
        closedByStaffId: json['closed_by_staff_id']?.toString(),
        closingCashCounted: (json['closing_cash_counted'] as num?)?.toDouble(),
        cashVariance: (json['cash_variance'] as num?)?.toDouble(),
        carryForwardCash: (json['carry_forward_cash'] as num?)?.toDouble(),
        isCarryForward: json['is_carry_forward'] as bool?,
        totalCashSales: (json['total_cash_sales'] as num?)?.toDouble(),
        totalCardSales: (json['total_card_sales'] as num?)?.toDouble(),
        totalSales: (json['total_sales'] as num?)?.toDouble(),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ TradingDay.fromJson: Parsing failed');
      debugPrint('   JSON: $json');
      debugPrint('   Error: $e');
      debugPrint('   Stack: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'trading_date': tradingDate.toIso8601String(),
    'opened_at': openedAt.toIso8601String(),
    'opened_by_staff_id': openedByStaffId,
    'opening_float_amount': openingFloatAmount,
    'opening_float_source': openingFloatSource,
    'closed_at': closedAt?.toIso8601String(),
    'closed_by_staff_id': closedByStaffId,
    'closing_cash_counted': closingCashCounted,
    'cash_variance': cashVariance,
    'carry_forward_cash': carryForwardCash,
    'is_carry_forward': isCarryForward,
    'total_cash_sales': totalCashSales,
    'total_card_sales': totalCardSales,
    'total_sales': totalSales,
  };

  TradingDay copyWith({
    String? id,
    String? outletId,
    DateTime? tradingDate,
    DateTime? openedAt,
    String? openedByStaffId,
    double? openingFloatAmount,
    String? openingFloatSource,
    DateTime? closedAt,
    String? closedByStaffId,
    double? closingCashCounted,
    double? cashVariance,
    double? carryForwardCash,
    bool? isCarryForward,
    double? totalCashSales,
    double? totalCardSales,
    double? totalSales,
  }) => TradingDay(
    id: id ?? this.id,
    outletId: outletId ?? this.outletId,
    tradingDate: tradingDate ?? this.tradingDate,
    openedAt: openedAt ?? this.openedAt,
    openedByStaffId: openedByStaffId ?? this.openedByStaffId,
    openingFloatAmount: openingFloatAmount ?? this.openingFloatAmount,
    openingFloatSource: openingFloatSource ?? this.openingFloatSource,
    closedAt: closedAt ?? this.closedAt,
    closedByStaffId: closedByStaffId ?? this.closedByStaffId,
    closingCashCounted: closingCashCounted ?? this.closingCashCounted,
    cashVariance: cashVariance ?? this.cashVariance,
    carryForwardCash: carryForwardCash ?? this.carryForwardCash,
    isCarryForward: isCarryForward ?? this.isCarryForward,
    totalCashSales: totalCashSales ?? this.totalCashSales,
    totalCardSales: totalCardSales ?? this.totalCardSales,
    totalSales: totalSales ?? this.totalSales,
  );
}
