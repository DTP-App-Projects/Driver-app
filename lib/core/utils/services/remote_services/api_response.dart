import 'package:dio/dio.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';

/// One normalised view over the two envelopes the backend uses:
///
/// * bare: `{"msg": "...", ...payload}` or `{"data": ...}` with real HTTP codes
///   (driver, auth, uploads, account deletion)
/// * wrapped: `{"status": <int>, "data": ...}` / `{"status": <int>, "message": "..."}`
///   (training, performance, incidents, push)
///
/// Repositories read [data], [msg] and [isSuccess] and never look at the raw
/// envelope, so the presentation layer does not care which shape came back.
class ApiResponse {
  const ApiResponse({
    required this.httpStatus,
    required this.statusCode,
    required this.body,
    required this.data,
    required this.msg,
    required this.bag,
  });

  /// HTTP status as sent by the server.
  final int httpStatus;

  /// Effective status: the wrapped envelope's `status` when present, the HTTP
  /// status otherwise.
  final int statusCode;

  /// The full decoded body. Empty map for non JSON responses (e.g. `204`).
  final Map<String, dynamic> body;

  /// `body["data"]` when the envelope carries one, the whole body otherwise.
  final dynamic data;

  /// `msg` (bare) or `message` (wrapped / Laravel default) when present.
  final String? msg;

  /// Field errors of a `validation_error` response.
  final Map<String, List<String>> bag;

  bool get isSuccess => statusCode >= 200 && statusCode < 300 && !_isFlaggedFailure;

  /// A few endpoints answer `200` with an explicit failure flag:
  /// barcode mismatch `{success:false}`, suspended login `{status:"failed"}`.
  bool get _isFlaggedFailure {
    if (body["success"] == false) return true;
    if (body["status"] is String && body["status"].toString().toLowerCase() == "failed") return true;
    return false;
  }

  /// `success` flag when the endpoint sends one (barcode, seals, OTP, terms).
  bool? get successFlag => body["success"] is bool ? body["success"] as bool : null;

  Map<String, dynamic> get dataMap => JsonUtils.asMap(data);

  List<dynamic> get dataList => JsonUtils.asList(data);

  factory ApiResponse.fromDio(Response response) {
    final raw = response.data;
    final body = raw is Map ? JsonUtils.asMap(raw) : <String, dynamic>{};
    final httpStatus = response.statusCode ?? 0;

    final bool isWrapped = body["status"] is int && (body.containsKey("data") || body.containsKey("message"));

    final bag = <String, List<String>>{};
    // `validation_error` sends the fields under `bag`, the van endpoints'
    // `validation_failed` under `errors`.
    final rawBag = body["bag"] ?? (body["msg"] == "validation_failed" ? body["errors"] : null);
    if (rawBag is Map) {
      rawBag.forEach((key, value) {
        bag[key.toString()] = value is List ? value.map((item) => item.toString()).toList() : [value.toString()];
      });
    }

    return ApiResponse(
      httpStatus: httpStatus,
      statusCode: isWrapped ? body["status"] as int : httpStatus,
      body: body,
      data: body.containsKey("data") ? body["data"] : (raw is List ? raw : body),
      msg: JsonUtils.asString(body["msg"] ?? body["message"]),
      bag: bag,
    );
  }
}
