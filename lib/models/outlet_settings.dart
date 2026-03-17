import 'package:flutter/foundation.dart';
import 'package:flowtill/utils/sqlite_converters.dart';

class OutletSettings {
  final String outletId;
  final bool printOrderTicketsOnOrderAway;
  final int orderTicketCopies;
  final int tableNumberSize; // 1-3 (PosTextSize.size1, size2, size3)
  final int notesSize; // 1-3
  final int modifiersSize; // 1-3
  final bool highlightSpecials;
  final String? operatingHoursOpen; // Format: "HH:mm" (e.g., "10:00")
  final String? operatingHoursClose; // Format: "HH:mm" (e.g., "02:00") - can pass midnight
  
  // Loyalty settings (nullable for backward compatibility)
  final bool? loyaltyEnabled;
  final double? loyaltyPointsPerPound;
  final bool? loyaltyDoublePointsEnabled;
  final String? loyaltyDiscountCardRestaurantId;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  OutletSettings({
    required this.outletId,
    required this.printOrderTicketsOnOrderAway,
    required this.orderTicketCopies,
    this.tableNumberSize = 1,
    this.notesSize = 1,
    this.modifiersSize = 1,
    this.highlightSpecials = true,
    this.operatingHoursOpen,
    this.operatingHoursClose,
    this.loyaltyEnabled = true,
    this.loyaltyPointsPerPound = 1.0,
    this.loyaltyDoublePointsEnabled = false,
    this.loyaltyDiscountCardRestaurantId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OutletSettings.fromJson(Map<String, dynamic> json) {
    try {
      final outletId = json['outlet_id']?.toString() ?? '';
      final printOrderTicketsOnOrderAway = SQLiteConverters.toBool(json['print_order_tickets_on_order_away']) ?? false;
      
      // Clamp orderTicketCopies between 1 and 5
      final orderTicketCopies = (SQLiteConverters.toInt(json['order_ticket_copies']) ?? 1).clamp(1, 5);

      final createdAt = SQLiteConverters.toDateTime(json['created_at']) ?? DateTime.now();
      final updatedAt = SQLiteConverters.toDateTime(json['updated_at']) ?? DateTime.now();

      final highlightSpecials = SQLiteConverters.toBool(json['highlight_specials']) ?? true;
      final operatingHoursOpen = json['operating_hours_open']?.toString();
      final operatingHoursClose = json['operating_hours_close']?.toString();

      // Parse loyalty settings with defaults
      final loyaltyEnabled = SQLiteConverters.toBool(json['loyalty_enabled']) ?? true;
      final loyaltyPointsPerPound = (SQLiteConverters.toDouble(json['loyalty_points_per_pound']) ?? 1.0).clamp(0.0, 10.0);
      final loyaltyDoublePointsEnabled = SQLiteConverters.toBool(json['loyalty_double_points_enabled']) ?? false;
      final loyaltyDiscountCardRestaurantId = json['loyalty_discount_card_restaurant_id']?.toString();

      // Clamp font sizes between 1 and 3
      final tableNumberSize = (SQLiteConverters.toInt(json['table_number_size']) ?? 1).clamp(1, 3);
      final notesSize = (SQLiteConverters.toInt(json['notes_size']) ?? 1).clamp(1, 3);
      final modifiersSize = (SQLiteConverters.toInt(json['modifiers_size']) ?? 1).clamp(1, 3);

      return OutletSettings(
        outletId: outletId,
        printOrderTicketsOnOrderAway: printOrderTicketsOnOrderAway,
        orderTicketCopies: orderTicketCopies,
        tableNumberSize: tableNumberSize,
        notesSize: notesSize,
        modifiersSize: modifiersSize,
        highlightSpecials: highlightSpecials,
        operatingHoursOpen: operatingHoursOpen,
        operatingHoursClose: operatingHoursClose,
        loyaltyEnabled: loyaltyEnabled,
        loyaltyPointsPerPound: loyaltyPointsPerPound,
        loyaltyDoublePointsEnabled: loyaltyDoublePointsEnabled,
        loyaltyDiscountCardRestaurantId: loyaltyDiscountCardRestaurantId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ OutletSettings.fromJson: Parsing failed');
      debugPrint('   JSON: $json');
      debugPrint('   Error: $e');
      debugPrint('   Stack: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
    'outlet_id': outletId,
    'print_order_tickets_on_order_away': printOrderTicketsOnOrderAway,
    'order_ticket_copies': orderTicketCopies.clamp(1, 5),
    'table_number_size': tableNumberSize.clamp(1, 3),
    'notes_size': notesSize.clamp(1, 3),
    'modifiers_size': modifiersSize.clamp(1, 3),
    'highlight_specials': highlightSpecials,
    'operating_hours_open': operatingHoursOpen,
    'operating_hours_close': operatingHoursClose,
    'loyalty_enabled': loyaltyEnabled ?? true,
    'loyalty_points_per_pound': (loyaltyPointsPerPound ?? 1.0).clamp(0.0, 10.0),
    'loyalty_double_points_enabled': loyaltyDoublePointsEnabled ?? false,
    'loyalty_discount_card_restaurant_id': loyaltyDiscountCardRestaurantId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  OutletSettings copyWith({
    String? outletId,
    bool? printOrderTicketsOnOrderAway,
    int? orderTicketCopies,
    int? tableNumberSize,
    int? notesSize,
    int? modifiersSize,
    bool? highlightSpecials,
    String? operatingHoursOpen,
    String? operatingHoursClose,
    bool? loyaltyEnabled,
    double? loyaltyPointsPerPound,
    bool? loyaltyDoublePointsEnabled,
    String? loyaltyDiscountCardRestaurantId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => OutletSettings(
    outletId: outletId ?? this.outletId,
    printOrderTicketsOnOrderAway: printOrderTicketsOnOrderAway ?? this.printOrderTicketsOnOrderAway,
    orderTicketCopies: (orderTicketCopies ?? this.orderTicketCopies).clamp(1, 5),
    tableNumberSize: (tableNumberSize ?? this.tableNumberSize).clamp(1, 3),
    notesSize: (notesSize ?? this.notesSize).clamp(1, 3),
    modifiersSize: (modifiersSize ?? this.modifiersSize).clamp(1, 3),
    highlightSpecials: highlightSpecials ?? this.highlightSpecials,
    operatingHoursOpen: operatingHoursOpen ?? this.operatingHoursOpen,
    operatingHoursClose: operatingHoursClose ?? this.operatingHoursClose,
    loyaltyEnabled: loyaltyEnabled ?? this.loyaltyEnabled,
    loyaltyPointsPerPound: (loyaltyPointsPerPound ?? this.loyaltyPointsPerPound ?? 1.0).clamp(0.0, 10.0),
    loyaltyDoublePointsEnabled: loyaltyDoublePointsEnabled ?? this.loyaltyDoublePointsEnabled,
    loyaltyDiscountCardRestaurantId: loyaltyDiscountCardRestaurantId ?? this.loyaltyDiscountCardRestaurantId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
