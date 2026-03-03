import 'package:flutter/foundation.dart';

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
      final printOrderTicketsOnOrderAway = json['print_order_tickets_on_order_away'] == true;
      
      // Clamp orderTicketCopies between 1 and 5
      int orderTicketCopies = 1;
      if (json['order_ticket_copies'] != null) {
        final raw = json['order_ticket_copies'];
        if (raw is int) {
          orderTicketCopies = raw.clamp(1, 5);
        } else if (raw is String) {
          orderTicketCopies = (int.tryParse(raw) ?? 1).clamp(1, 5);
        }
      }

      DateTime createdAt = DateTime.now();
      if (json['created_at'] != null) {
        try {
          createdAt = DateTime.parse(json['created_at'].toString());
        } catch (e) {
          debugPrint('⚠️ OutletSettings.fromJson: Invalid created_at timestamp: ${json['created_at']}');
        }
      }

      DateTime updatedAt = DateTime.now();
      if (json['updated_at'] != null) {
        try {
          updatedAt = DateTime.parse(json['updated_at'].toString());
        } catch (e) {
          debugPrint('⚠️ OutletSettings.fromJson: Invalid updated_at timestamp: ${json['updated_at']}');
        }
      }

      final highlightSpecials = json['highlight_specials'] as bool? ?? true;
      final operatingHoursOpen = json['operating_hours_open']?.toString();
      final operatingHoursClose = json['operating_hours_close']?.toString();

      // Parse loyalty settings with defaults
      final loyaltyEnabled = json['loyalty_enabled'] as bool? ?? true;
      
      double loyaltyPointsPerPound = 1.0;
      if (json['loyalty_points_per_pound'] != null) {
        final raw = json['loyalty_points_per_pound'];
        if (raw is double) {
          loyaltyPointsPerPound = raw.clamp(0.0, 10.0);
        } else if (raw is int) {
          loyaltyPointsPerPound = raw.toDouble().clamp(0.0, 10.0);
        } else if (raw is String) {
          loyaltyPointsPerPound = (double.tryParse(raw) ?? 1.0).clamp(0.0, 10.0);
        }
      }
      
      final loyaltyDoublePointsEnabled = json['loyalty_double_points_enabled'] as bool? ?? false;
      final loyaltyDiscountCardRestaurantId = json['loyalty_discount_card_restaurant_id']?.toString();

      // Clamp font sizes between 1 and 3
      int tableNumberSize = 1;
      if (json['table_number_size'] != null) {
        final raw = json['table_number_size'];
        if (raw is int) {
          tableNumberSize = raw.clamp(1, 3);
        } else if (raw is String) {
          tableNumberSize = (int.tryParse(raw) ?? 1).clamp(1, 3);
        }
      }

      int notesSize = 1;
      if (json['notes_size'] != null) {
        final raw = json['notes_size'];
        if (raw is int) {
          notesSize = raw.clamp(1, 3);
        } else if (raw is String) {
          notesSize = (int.tryParse(raw) ?? 1).clamp(1, 3);
        }
      }

      int modifiersSize = 1;
      if (json['modifiers_size'] != null) {
        final raw = json['modifiers_size'];
        if (raw is int) {
          modifiersSize = raw.clamp(1, 3);
        } else if (raw is String) {
          modifiersSize = (int.tryParse(raw) ?? 1).clamp(1, 3);
        }
      }

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
