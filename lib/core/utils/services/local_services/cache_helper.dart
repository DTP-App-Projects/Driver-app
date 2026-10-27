import 'package:shared_preferences/shared_preferences.dart';

class CacheHelper {
  static SharedPreferences? _sharedPreferences;

  /// Reads before [init] (unit tests, model parsing at import time) answer
  /// null instead of throwing.
  static SharedPreferences? get sharedPreferences => _sharedPreferences;

  static init() async {
    _sharedPreferences = await SharedPreferences.getInstance();
  }

  static Future<bool> saveData({required String key, required dynamic value}) async {
    final prefs = _sharedPreferences ?? await SharedPreferences.getInstance();
    if (value is String) return await prefs.setString(key, value);
    if (value is int) return await prefs.setInt(key, value);
    if (value is bool) return await prefs.setBool(key, value);
    if (value is double) return await prefs.setDouble(key, value);
    return await prefs.setStringList(key, value);
  }

  static dynamic getData({required String key}) {
    return _sharedPreferences?.get(key);
  }

  static dynamic getListOFData({required String key}) {
    return _sharedPreferences?.getStringList(key);
  }

  static Future<bool> removeData({required String key}) async {
    final prefs = _sharedPreferences ?? await SharedPreferences.getInstance();
    return await prefs.remove(key);
  }
}
