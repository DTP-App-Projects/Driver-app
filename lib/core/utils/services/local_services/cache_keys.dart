import 'package:digital_trade_portal_driver/core/utils/services/local_services/secure_cache_helper.dart';

import 'cache_helper.dart';

class CacheKeysManger {
  static const String _tokenKey = "token";
  static const String _userIdKey = "userId";
  static const String _driverIdKey = "driverId";
  static const String _deviceTokenKey = "deviceToken";
  static const String _langKey = "lang";
  static const String _termsAcceptedKey = "termsAccepted";

  static Future<bool> saveCompleteProfile(bool value) async =>
      await CacheHelper.saveData(key: 'isCompleteProfile', value: value);

  static bool getCompleteProfile() => CacheHelper.getData(key: 'isCompleteProfile') ?? false;

  /// The raw JWT, kept in secure storage. The `Bearer` prefix is added by the
  /// API client, so callers never deal with header formatting.
  static Future<void> saveToken({required String token}) async =>
      await SecureCacheHelper.saveData(key: _tokenKey, value: token);

  static Future<String> getToken() async {
    final token = await SecureCacheHelper.getData(key: _tokenKey);
    if (token == null) return "";
    // Tokens stored by earlier builds carried the header prefix.
    return token.toString().replaceFirst(RegExp(r"^Bearer\s+"), "").trim();
  }

  static Future<bool> isLoggedIn() async => (await getToken()).isNotEmpty;

  static Future<void> saveUserId(int id) async => await CacheHelper.saveData(key: _userIdKey, value: id);

  static int? getUserId() => CacheHelper.getData(key: _userIdKey) as int?;

  static Future<void> saveDriverId(int id) async => await CacheHelper.saveData(key: _driverIdKey, value: id);

  static int? getDriverId() => CacheHelper.getData(key: _driverIdKey) as int?;

  static Future<void> saveDeviceToken(String token) async =>
      await CacheHelper.saveData(key: _deviceTokenKey, value: token);

  static String? getDeviceToken() => CacheHelper.getData(key: _deviceTokenKey) as String?;

  static String getUserLanguage() => CacheHelper.getData(key: _langKey) ?? "";

  static Future<void> saveTermsAccepted(bool value) async =>
      await CacheHelper.saveData(key: _termsAcceptedKey, value: value);

  static bool getTermsAccepted() => CacheHelper.getData(key: _termsAcceptedKey) ?? false;

  /// Forgets everything tied to the signed in account. Language and device
  /// token stay: they belong to the device, not the driver.
  static Future<void> clearSession() async {
    await SecureCacheHelper.removeData(key: _tokenKey);
    await CacheHelper.removeData(key: _userIdKey);
    await CacheHelper.removeData(key: _driverIdKey);
    await CacheHelper.removeData(key: _termsAcceptedKey);
  }
}
