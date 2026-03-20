import 'package:flutter/foundation.dart';

/// Safe conversion utilities for SQLite data types
/// SQLite stores booleans as INTEGER 0/1, and has different null handling
class SQLiteConverters {
  /// Safely convert a value to bool
  /// Handles: bool, int (0/1), String ('true'/'false'), null
  static bool? toBool(dynamic value) {
    if (value == null) return null;
    
    try {
      if (value is bool) return value;
      if (value is int) return value != 0;
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower == 'true' || lower == '1') return true;
        if (lower == 'false' || lower == '0') return false;
      }
    } catch (e) {
      debugPrint('⚠️ SQLiteConverters.toBool: Failed to convert $value (${value.runtimeType}): $e');
    }
    
    return null;
  }

  /// Safely convert a value to non-nullable bool with default
  /// Use this when you need a guaranteed bool value
  static bool asBool(dynamic value, {bool defaultValue = false}) {
    return toBool(value) ?? defaultValue;
  }

  /// Safely convert a value to String
  /// Handles: String, int, double, bool, null
  static String? toStringValue(dynamic value) {
    if (value == null) return null;
    
    try {
      if (value is String) return value;
      return value.toString();
    } catch (e) {
      debugPrint('⚠️ SQLiteConverters.toStringValue: Failed to convert $value (${value.runtimeType}): $e');
    }
    
    return null;
  }

  /// Safely convert a value to non-nullable String with default
  static String asString(dynamic value, {String defaultValue = ''}) {
    return toStringValue(value) ?? defaultValue;
  }

  /// Safely convert a value to non-nullable int with default
  static int asInt(dynamic value, {int defaultValue = 0}) {
    return toInt(value) ?? defaultValue;
  }

  /// Safely convert a value to non-nullable double with default
  static double asDouble(dynamic value, {double defaultValue = 0.0}) {
    return toDouble(value) ?? defaultValue;
  }

  /// Safely convert a value to int
  /// Handles: int, double, String, null
  static int? toInt(dynamic value) {
    if (value == null) return null;
    
    try {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
    } catch (e) {
      debugPrint('⚠️ SQLiteConverters.toInt: Failed to convert $value (${value.runtimeType}): $e');
    }
    
    return null;
  }

  /// Safely convert a value to double
  /// Handles: double, int, String, null
  static double? toDouble(dynamic value) {
    if (value == null) return null;
    
    try {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
    } catch (e) {
      debugPrint('⚠️ SQLiteConverters.toDouble: Failed to convert $value (${value.runtimeType}): $e');
    }
    
    return null;
  }

  /// Safely convert a value to DateTime
  /// Handles: String (ISO8601), int (milliseconds), DateTime, null
  static DateTime? toDateTime(dynamic value) {
    if (value == null) return null;
    
    try {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    } catch (e) {
      debugPrint('⚠️ SQLiteConverters.toDateTime: Failed to convert $value (${value.runtimeType}): $e');
    }
    
    return null;
  }

  /// Log parsing error with model and field context
  static void logParsingError(String modelName, String fieldName, dynamic value, Object error) {
    debugPrint('❌ $modelName.fromJson: Failed to parse field "$fieldName"');
    debugPrint('   Value: $value (${value?.runtimeType})');
    debugPrint('   Error: $error');
  }
}
