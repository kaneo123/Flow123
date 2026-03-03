import 'package:flutter/foundation.dart';

class Outlet {
  final String id;
  final String name;
  final String? code;
  final String? addressLine1;
  final String? addressLine2;
  final String? town;
  final String? postcode;
  final String? phone;
  final bool active;
  final Map<String, dynamic>? settings;
  final bool enableServiceCharge;
  final double serviceChargePercent;
  final String receiptHeaderText;
  final String receiptFooterText;
  final bool receiptShowLogo;
  final String? receiptLogoUrl;
  final int receiptFontSize;
  final int receiptLineSpacing;
  final bool receiptShowVatBreakdown;
  final bool receiptShowServiceCharge;
  final bool receiptShowPromotions;
  final bool receiptUseCompactLayout;
  final String receiptCodepage;
  final bool receiptLargeTotalText;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Outlet({
    required this.id,
    required this.name,
    this.code,
    this.addressLine1,
    this.addressLine2,
    this.town,
    this.postcode,
    this.phone,
    this.active = true,
    this.settings,
    this.enableServiceCharge = false,
    this.serviceChargePercent = 0.0,
    this.receiptHeaderText = '',
    this.receiptFooterText = '',
    this.receiptShowLogo = false,
    this.receiptLogoUrl,
    this.receiptFontSize = 20,
    this.receiptLineSpacing = 4,
    this.receiptShowVatBreakdown = true,
    this.receiptShowServiceCharge = true,
    this.receiptShowPromotions = true,
    this.receiptUseCompactLayout = true,
    this.receiptCodepage = 'CP437',
    this.receiptLargeTotalText = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Computed full address for display
  String get fullAddress {
    final parts = [
      addressLine1,
      addressLine2,
      town,
      postcode,
    ].where((part) => part != null && part.isNotEmpty);
    return parts.isEmpty ? 'No address provided' : parts.join(', ');
  }

  factory Outlet.fromJson(Map<String, dynamic> json) {
    try {
      // Safe parsing with null handling for all fields
      final id = json['id']?.toString() ?? '';
      final name = json['name']?.toString() ?? 'Unnamed Outlet';
      final code = json['code']?.toString();
      final addressLine1 = json['address_line1']?.toString();
      final addressLine2 = json['address_line2']?.toString();
      final town = json['town']?.toString();
      final postcode = json['postcode']?.toString();
      final phone = json['phone']?.toString();
      final active = json['active'] == true;
      
      // Parse settings (JSONB field) - only if present
      Map<String, dynamic>? settings;
      if (json.containsKey('settings') && json['settings'] != null) {
        if (json['settings'] is Map) {
          settings = Map<String, dynamic>.from(json['settings'] as Map);
        }
      }
      
      // Parse service charge fields
      final enableServiceCharge = json['enable_service_charge'] == true;
      final serviceChargePercent = (json['service_charge_percent'] as num?)?.toDouble() ?? 0.0;
      
      // Parse receipt formatting fields
      final receiptHeaderText = json['receipt_header_text']?.toString() ?? '';
      final receiptFooterText = json['receipt_footer_text']?.toString() ?? '';
      final receiptShowLogo = json['receipt_show_logo'] == true;
      final receiptLogoUrl = json['receipt_logo_url']?.toString();
      final receiptFontSize = (json['receipt_font_size'] as num?)?.toInt() ?? 20;
      final receiptLineSpacing = (json['receipt_line_spacing'] as num?)?.toInt() ?? 4;
      final receiptShowVatBreakdown = json['receipt_show_vat_breakdown'] != false;
      final receiptShowServiceCharge = json['receipt_show_service_charge'] != false;
      final receiptShowPromotions = json['receipt_show_promotions'] != false;
      final receiptUseCompactLayout = json['receipt_use_compact_layout'] != false;
      final receiptCodepage = json['receipt_codepage']?.toString() ?? 'CP437';
      final receiptLargeTotalText = json['receipt_large_total_text'] != false;
      
      debugPrint('🏪 Outlet.fromJson: Parsing outlet "$name"');
      debugPrint('   enable_service_charge (raw): ${json['enable_service_charge']}');
      debugPrint('   enable_service_charge (parsed): $enableServiceCharge');
      debugPrint('   service_charge_percent (raw): ${json['service_charge_percent']}');
      debugPrint('   service_charge_percent (parsed): $serviceChargePercent');
      
      // Parse timestamps safely
      DateTime createdAt = DateTime.now();
      if (json['created_at'] != null) {
        try {
          createdAt = DateTime.parse(json['created_at'].toString());
        } catch (e) {
          debugPrint('⚠️ Outlet.fromJson: Invalid created_at timestamp: ${json['created_at']}');
        }
      }
      
      // Parse updated_at only if column exists
      DateTime? updatedAt;
      if (json.containsKey('updated_at') && json['updated_at'] != null) {
        try {
          updatedAt = DateTime.parse(json['updated_at'].toString());
        } catch (e) {
          debugPrint('⚠️ Outlet.fromJson: Invalid updated_at timestamp: ${json['updated_at']}');
        }
      }
      
      return Outlet(
        id: id,
        name: name,
        code: code,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        town: town,
        postcode: postcode,
        phone: phone,
        active: active,
        settings: settings,
        enableServiceCharge: enableServiceCharge,
        serviceChargePercent: serviceChargePercent,
        receiptHeaderText: receiptHeaderText,
        receiptFooterText: receiptFooterText,
        receiptShowLogo: receiptShowLogo,
        receiptLogoUrl: receiptLogoUrl,
        receiptFontSize: receiptFontSize,
        receiptLineSpacing: receiptLineSpacing,
        receiptShowVatBreakdown: receiptShowVatBreakdown,
        receiptShowServiceCharge: receiptShowServiceCharge,
        receiptShowPromotions: receiptShowPromotions,
        receiptUseCompactLayout: receiptUseCompactLayout,
        receiptCodepage: receiptCodepage,
        receiptLargeTotalText: receiptLargeTotalText,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Outlet.fromJson: Parsing failed for outlet data');
      debugPrint('   JSON: $json');
      debugPrint('   Error: $e');
      debugPrint('   Stack: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'name': name,
      'code': code,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'town': town,
      'postcode': postcode,
      'phone': phone,
      'active': active,
      'enable_service_charge': enableServiceCharge,
      'service_charge_percent': serviceChargePercent,
      'receipt_header_text': receiptHeaderText,
      'receipt_footer_text': receiptFooterText,
      'receipt_show_logo': receiptShowLogo,
      'receipt_logo_url': receiptLogoUrl,
      'receipt_font_size': receiptFontSize,
      'receipt_line_spacing': receiptLineSpacing,
      'receipt_show_vat_breakdown': receiptShowVatBreakdown,
      'receipt_show_service_charge': receiptShowServiceCharge,
      'receipt_show_promotions': receiptShowPromotions,
      'receipt_use_compact_layout': receiptUseCompactLayout,
      'receipt_codepage': receiptCodepage,
      'receipt_large_total_text': receiptLargeTotalText,
      'created_at': createdAt.toIso8601String(),
    };
    
    // Only include settings if present
    if (settings != null) {
      json['settings'] = settings;
    }
    
    // Only include updated_at if present
    if (updatedAt != null) {
      json['updated_at'] = updatedAt!.toIso8601String();
    }
    
    return json;
  }

  Outlet copyWith({
    String? id,
    String? name,
    String? code,
    String? addressLine1,
    String? addressLine2,
    String? town,
    String? postcode,
    String? phone,
    bool? active,
    Map<String, dynamic>? settings,
    bool? enableServiceCharge,
    double? serviceChargePercent,
    String? receiptHeaderText,
    String? receiptFooterText,
    bool? receiptShowLogo,
    String? receiptLogoUrl,
    int? receiptFontSize,
    int? receiptLineSpacing,
    bool? receiptShowVatBreakdown,
    bool? receiptShowServiceCharge,
    bool? receiptShowPromotions,
    bool? receiptUseCompactLayout,
    String? receiptCodepage,
    bool? receiptLargeTotalText,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Outlet(
    id: id ?? this.id,
    name: name ?? this.name,
    code: code ?? this.code,
    addressLine1: addressLine1 ?? this.addressLine1,
    addressLine2: addressLine2 ?? this.addressLine2,
    town: town ?? this.town,
    postcode: postcode ?? this.postcode,
    phone: phone ?? this.phone,
    active: active ?? this.active,
    settings: settings ?? this.settings,
    enableServiceCharge: enableServiceCharge ?? this.enableServiceCharge,
    serviceChargePercent: serviceChargePercent ?? this.serviceChargePercent,
    receiptHeaderText: receiptHeaderText ?? this.receiptHeaderText,
    receiptFooterText: receiptFooterText ?? this.receiptFooterText,
    receiptShowLogo: receiptShowLogo ?? this.receiptShowLogo,
    receiptLogoUrl: receiptLogoUrl ?? this.receiptLogoUrl,
    receiptFontSize: receiptFontSize ?? this.receiptFontSize,
    receiptLineSpacing: receiptLineSpacing ?? this.receiptLineSpacing,
    receiptShowVatBreakdown: receiptShowVatBreakdown ?? this.receiptShowVatBreakdown,
    receiptShowServiceCharge: receiptShowServiceCharge ?? this.receiptShowServiceCharge,
    receiptShowPromotions: receiptShowPromotions ?? this.receiptShowPromotions,
    receiptUseCompactLayout: receiptUseCompactLayout ?? this.receiptUseCompactLayout,
    receiptCodepage: receiptCodepage ?? this.receiptCodepage,
    receiptLargeTotalText: receiptLargeTotalText ?? this.receiptLargeTotalText,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
