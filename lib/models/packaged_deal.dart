import 'dart:convert';
import 'package:flowtill/utils/sqlite_converters.dart';

class PackagedDeal {
  final String id;
  final String outletId;
  final String name;
  final String? description;
  final double price;
  final Map<String, dynamic> components;
  final bool active;
  final List<int>? availableDays;
  final String? startTime;
  final String? endTime;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  PackagedDeal({
    required this.id,
    required this.outletId,
    required this.name,
    this.description,
    required this.price,
    required this.components,
    this.active = true,
    this.availableDays,
    this.startTime,
    this.endTime,
    this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PackagedDeal.fromJson(Map<String, dynamic> json) {
    // Parse available_days - database stores as strings, convert to ints
    List<int>? parsedDays;
    if (json['available_days'] != null) {
      final daysData = json['available_days'] as List<dynamic>;
      parsedDays = daysData.map((day) {
        if (day is int) return day;
        if (day is String) return int.parse(day);
        return 0; // fallback
      }).toList();
    }

    // Parse components - could be a JSON string or already a Map
    Map<String, dynamic> parsedComponents;
    final componentsData = json['components'];
    if (componentsData is String) {
      // Database stores as JSON string, need to decode
      try {
        final decoded = jsonDecode(componentsData);
        if (decoded is Map<String, dynamic>) {
          parsedComponents = decoded;
        } else if (decoded is List) {
          // If it's an empty array [], convert to empty map
          parsedComponents = {};
        } else {
          parsedComponents = {};
        }
      } catch (e) {
        parsedComponents = {};
      }
    } else if (componentsData is Map<String, dynamic>) {
      parsedComponents = componentsData;
    } else {
      parsedComponents = {};
    }

    return PackagedDeal(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: SQLiteConverters.toDouble(json['price']) ?? 0.0,
      components: parsedComponents,
      active: SQLiteConverters.toBool(json['active']) ?? true,
      availableDays: parsedDays,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      startDate: SQLiteConverters.toDateTime(json['start_date']),
      endDate: SQLiteConverters.toDateTime(json['end_date']),
      createdAt: SQLiteConverters.toDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: SQLiteConverters.toDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'name': name,
    if (description != null) 'description': description,
    'price': price,
    'components': components,
    'active': active,
    if (availableDays != null) 'available_days': availableDays,
    if (startTime != null) 'start_time': startTime,
    if (endTime != null) 'end_time': endTime,
    if (startDate != null) 'start_date': startDate!.toIso8601String().split('T')[0],
    if (endDate != null) 'end_date': endDate!.toIso8601String().split('T')[0],
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  PackagedDeal copyWith({
    String? id,
    String? outletId,
    String? name,
    String? description,
    double? price,
    Map<String, dynamic>? components,
    bool? active,
    List<int>? availableDays,
    String? startTime,
    String? endTime,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PackagedDeal(
    id: id ?? this.id,
    outletId: outletId ?? this.outletId,
    name: name ?? this.name,
    description: description ?? this.description,
    price: price ?? this.price,
    components: components ?? this.components,
    active: active ?? this.active,
    availableDays: availableDays ?? this.availableDays,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Check if this packaged deal is available at the given date/time
  bool isAvailableAt(DateTime dateTime) {
    if (!active) return false;

    // Check date range
    if (startDate != null && dateTime.isBefore(startDate!)) {
      return false;
    }
    if (endDate != null && dateTime.isAfter(endDate!.add(const Duration(days: 1)))) {
      return false;
    }

    // Check day of week (0 = Sunday, 6 = Saturday in database)
    if (availableDays != null && availableDays!.isNotEmpty) {
      final dayOfWeek = dateTime.weekday % 7; // Convert to 0=Sunday, 6=Saturday
      if (!availableDays!.contains(dayOfWeek)) {
        return false;
      }
    }

    // Check time range
    if (startTime != null || endTime != null) {
      final currentTime = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
      if (startTime != null && currentTime.compareTo(startTime!) < 0) {
        return false;
      }
      if (endTime != null && currentTime.compareTo(endTime!) > 0) {
        return false;
      }
    }

    return true;
  }
}
