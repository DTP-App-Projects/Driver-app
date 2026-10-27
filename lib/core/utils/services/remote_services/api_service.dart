import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/session_manager.dart';
import 'api_logger.dart';
import 'api_response.dart';
import '../local_services/cache_keys.dart';
import 'endpoints.dart';

/// The one HTTP client of the app. Owns the base URL, the `Accept` /
/// `Accept-Language` / `Authorization` headers, timeouts, the debug log and
/// the "token rejected → back to login" rule, so no repository repeats them.
class ApiService {
  final Dio _dio;

  static const String _sendTokenKey = "sendToken";

  ApiService(this._dio) {
    _dio.options = BaseOptions(
      baseUrl: EndPoints.baseUrl,
      headers: {"Accept": "application/json"},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      // Laravel style arrays in query strings: key[]=a&key[]=b
      listFormat: ListFormat.multiCompatible,
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final language = CacheKeysManger.getUserLanguage();
          options.headers["Accept-Language"] = language.isEmpty ? "ar" : language;

          if (options.extra[_sendTokenKey] == true) {
            final token = await CacheKeysManger.getToken();
            if (token.isNotEmpty) options.headers["Authorization"] = "Bearer $token";
          }
          handler.next(options);
        },
        onError: (error, handler) {
          _handleSessionExpiry(error);
          handler.next(error);
        },
      ),
    );

    if (kDebugMode) _dio.interceptors.add(ApiLogger());
  }

  /// Only a `401` whose `msg` says the session itself is invalid logs the
  /// driver out; `invalid_password` and friends are ordinary errors.
  void _handleSessionExpiry(DioException error) {
    final response = error.response;
    if (response == null || response.statusCode != 401) return;
    if (error.requestOptions.extra[_sendTokenKey] != true) return;

    final normalized = ApiResponse.fromDio(response);
    if (ServerFailure.isSessionInvalid(normalized.msg, normalized.body)) {
      SessionManager.expire();
    }
  }

  /// [headers] lets one call override a header, e.g. the password reset step
  /// that authenticates with the token returned by the code check.
  Options _options({required bool sendToken, Map<String, String>? headers}) =>
      Options(extra: {_sendTokenKey: sendToken}, headers: headers);

  Future<ApiResponse> get({
    required String endPoint,
    bool sendToken = true,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final response = await _dio.get(
      endPoint,
      queryParameters: query,
      options: _options(sendToken: sendToken, headers: headers),
    );
    return ApiResponse.fromDio(response);
  }

  /// [data] may be a JSON map or a [FormData] for the multipart endpoints.
  Future<ApiResponse> postData({
    required String endPoint,
    bool sendToken = true,
    dynamic data,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final response = await _dio.post(
      endPoint,
      data: data,
      queryParameters: query,
      options: _options(sendToken: sendToken, headers: headers),
    );
    return ApiResponse.fromDio(response);
  }

  Future<ApiResponse> putData({
    required String endPoint,
    bool sendToken = true,
    dynamic data,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final response = await _dio.put(
      endPoint,
      data: data,
      queryParameters: query,
      options: _options(sendToken: sendToken, headers: headers),
    );
    return ApiResponse.fromDio(response);
  }

  Future<ApiResponse> patchData({
    required String endPoint,
    bool sendToken = true,
    dynamic data,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final response = await _dio.patch(
      endPoint,
      data: data,
      queryParameters: query,
      options: _options(sendToken: sendToken, headers: headers),
    );
    return ApiResponse.fromDio(response);
  }

  Future<ApiResponse> deleteData({
    required String endPoint,
    bool sendToken = true,
    dynamic data,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final response = await _dio.delete(
      endPoint,
      data: data,
      queryParameters: query,
      options: _options(sendToken: sendToken, headers: headers),
    );
    return ApiResponse.fromDio(response);
  }
}
