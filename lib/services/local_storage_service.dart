import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('LocalStorageService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  /// Check if the service is initialized
  bool get isInitialized => _prefs != null;

  /// Try to get a bool value safely without throwing if not initialized
  bool? tryGetBool(String key) {
    if (_prefs == null) return null;
    return _prefs!.getBool(key);
  }

  /// Try to set a bool value safely without throwing if not initialized
  Future<bool> trySetBool(String key, bool value) async {
    if (_prefs == null) return false;
    return await _prefs!.setBool(key, value);
  }

  Future<void> saveList(String key, List<Map<String, dynamic>> data) async {
    try {
      final jsonString = jsonEncode(data);
      await prefs.setString(key, jsonString);
    } catch (e) {
      debugPrint('Error saving list to storage: $e');
    }
  }

  List<Map<String, dynamic>> getList(String key) {
    try {
      final jsonString = prefs.getString(key);
      if (jsonString == null) return [];
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error reading list from storage: $e');
      return [];
    }
  }

  Future<void> saveString(String key, String value) async {
    await prefs.setString(key, value);
  }

  String? getString(String key) => prefs.getString(key);

  Future<void> remove(String key) async {
    await prefs.remove(key);
  }

  Future<void> clear() async {
    await prefs.clear();
  }

  // Device-specific display settings
  Future<void> saveHideTopAppBar(bool hide) async {
    await prefs.setBool('hide_top_app_bar', hide);
  }

  bool getHideTopAppBar() => prefs.getBool('hide_top_app_bar') ?? false;
}
