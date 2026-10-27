import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug only request/response log. Secrets never reach the console: the
/// authorization header and any password / token / OTP field are masked.
class ApiLogger extends Interceptor {
  static const Set<String> _sensitiveKeys = {
    "password",
    "old_password",
    "new_password",
    "otp_code",
    "code",
    "token",
    "jwt",
    "authorization",
    "signature",
    "public_key",
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint("→ ${options.method} ${options.uri}");
      final body = options.data;
      if (body is FormData) {
        debugPrint("   multipart: ${body.fields.map((f) => f.key).join(", ")} + ${body.files.length} file(s)");
      } else if (body != null) {
        debugPrint("   body: ${_encode(sanitize(body))}");
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint("← ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}");
      debugPrint("   response: ${_encode(sanitize(response.data))}");
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint("✕ ${err.response?.statusCode ?? err.type} ${err.requestOptions.method} ${err.requestOptions.uri}");
      if (err.response?.data != null) debugPrint("   response: ${_encode(sanitize(err.response!.data))}");
    }
    handler.next(err);
  }

  static dynamic sanitize(dynamic value) {
    if (value is Map) {
      return value.map((key, item) {
        final name = key.toString().toLowerCase();
        return MapEntry(key, _sensitiveKeys.contains(name) ? "***" : sanitize(item));
      });
    }
    if (value is List) return value.map(sanitize).toList();
    return value;
  }

  static String _encode(dynamic value) {
    try {
      final text = jsonEncode(value);
      return text.length > 2000 ? "${text.substring(0, 2000)}… (${text.length} chars)" : text;
    } catch (_) {
      return value.toString();
    }
  }
}
