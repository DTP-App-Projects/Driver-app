import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:digital_trade_portal_driver/core/errors/api_error_messages.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/cache_keys.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_response.dart';

/// Kind of failure, so cubits can branch without parsing status codes.
enum FailureKind {
  /// Device offline or the request timed out; the action can be queued.
  network,

  /// `400 validation_error` — [Failure.bag] carries the field messages.
  validation,

  /// Invalid / expired session: the token was already cleared.
  unauthenticated,

  /// Authenticated user without a `fleet_drivers` row.
  notADriver,

  /// Any other 401/403/404/422 business rule the server refused.
  business,

  /// `429 Too Many Attempts.`
  rateLimited,

  /// 5xx, retryable.
  server,

  unknown,
}

abstract class Failure {
  Failure(
    this.errMessage, {
    this.kind = FailureKind.unknown,
    this.code,
    this.statusCode,
    this.bag = const {},
    this.body = const {},
  });

  /// Localized text, ready to show to the driver.
  final String errMessage;

  final FailureKind kind;

  /// Raw server `msg` code, e.g. `invalid_code`, `must_arrive_before_delivery`.
  final String? code;

  final int? statusCode;

  /// Field errors of a validation failure.
  final Map<String, List<String>> bag;

  /// Full response body, for endpoint specific extras such as
  /// `attempts_remaining` or `requires_generation`.
  final Map<String, dynamic> body;

  bool get isNetwork => kind == FailureKind.network;

  bool get isUnauthenticated => kind == FailureKind.unauthenticated;

  bool get isNotADriver => kind == FailureKind.notADriver;

  bool get isValidation => kind == FailureKind.validation;

  bool get isRateLimited => kind == FailureKind.rateLimited;

  /// Whether the action can be retried later without changing anything
  /// (offline, timeout, server hiccup).
  bool get isRetryable => isNetwork || kind == FailureKind.server;

  /// `pickup_failed` / `delivery_failed` embed the detail JSON as a string in
  /// `error`, often behind the reason (`barcode_validation_failed: [{…}]`);
  /// this decodes it when possible.
  dynamic get details {
    final raw = body["error"] ?? body["errors"] ?? body["details"];
    if (raw is String) {
      try {
        return jsonDecode(raw);
      } catch (_) {
        final start = raw.indexOf(RegExp(r"[\[{]"));
        if (start > 0) {
          try {
            return jsonDecode(raw.substring(start));
          } catch (_) {}
        }
        return raw;
      }
    }
    return raw;
  }

  /// The reason code at the head of `error`: `barcode_validation_failed` for
  /// `barcode_validation_failed: [...]`, `shipment_not_ready_for_pickup` for
  /// `shipment_not_ready_for_pickup:canceled`. Falls back to [code].
  String? get reason {
    final raw = body["error"];
    if (raw is String) {
      final head = raw.split(":").first.trim();
      if (RegExp(r"^[a-z0-9_]+$").hasMatch(head)) return head;
    }
    return code;
  }

  /// Per line problems the server listed (`{"item_id": 12, "error": "barcode_mismatch"}`),
  /// item id → reason code (null when the entry had none).
  Map<int, String?> get itemErrors {
    final errors = <int, String?>{};
    void collect(dynamic value) {
      if (value is Map) {
        final id = JsonUtils.asInt(value["item_id"]);
        if (id != null) errors[id] ??= JsonUtils.asString(value["error"] ?? value["reason"]);
        value.values.forEach(collect);
      } else if (value is List) {
        value.forEach(collect);
      }
    }

    collect(details);
    return errors;
  }

  /// Every human readable line inside [details] and [bag], for the UI to list.
  List<String> get detailLines {
    final lines = <String>[];
    void collect(dynamic value) {
      if (value == null) return;
      if (value is String) {
        if (value.trim().isNotEmpty) lines.add(value);
      } else if (value is List) {
        value.forEach(collect);
      } else if (value is Map) {
        value.forEach((key, item) {
          if (item is String || item is num) {
            lines.add("$key: $item");
          } else {
            collect(item);
          }
        });
      } else if (value is num || value is bool) {
        lines.add(value.toString());
      }
    }

    collect(details);
    bag.forEach((_, messages) => lines.addAll(messages));
    return lines;
  }

  /// Item ids the server pointed at in a pickup / delivery quantity or
  /// barcode failure, so the sheet can highlight those lines.
  Set<int> get failedItemIds => itemErrors.keys.toSet();

  @override
  String toString() => "Failure($kind, $statusCode, $code): $errMessage";
}

class ServerFailure extends Failure {
  ServerFailure(super.errMessage, {super.kind, super.code, super.statusCode, super.bag, super.body});

  factory ServerFailure.fromDioError(DioException dioException) {
    switch (dioException.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ServerFailure(tr("err_timeout"), kind: FailureKind.network, code: "timeout");
      case DioExceptionType.badResponse:
        final response = dioException.response;
        if (response == null) return ServerFailure(tr("err_unexpected"));
        return ServerFailure.fromApiResponse(ApiResponse.fromDio(response));
      case DioExceptionType.cancel:
        return ServerFailure(tr("err_request_canceled"), kind: FailureKind.network, code: "canceled");
      case DioExceptionType.connectionError:
        return ServerFailure(tr("err_no_internet"), kind: FailureKind.network, code: "no_internet");
      case DioExceptionType.badCertificate:
        return ServerFailure(tr("err_unexpected"), code: "bad_certificate");
      case DioExceptionType.unknown:
        final error = dioException.error?.toString() ?? "";
        if (error.contains("SocketException") || error.contains("Connection")) {
          return ServerFailure(tr("err_no_internet"), kind: FailureKind.network, code: "no_internet");
        }
        return ServerFailure(tr("err_unexpected"), code: "unknown");
    }
  }

  /// Builds the failure for a response the server refused, after the
  /// envelope has been normalised.
  factory ServerFailure.fromApiResponse(ApiResponse response) {
    final status = response.statusCode;
    final code = response.msg;
    final serverMessage = JsonUtils.asString(response.body["message"] ?? response.body["error"]);

    if ((status == 400 && code == "validation_error") || code == "validation_failed") {
      final firstFieldError = response.bag.values.expand((messages) => messages).firstOrNull;
      return ServerFailure(
        firstFieldError ?? tr("err_validation"),
        kind: FailureKind.validation,
        code: code,
        statusCode: status,
        bag: response.bag,
        body: response.body,
      );
    }

    if (status == 429) {
      return ServerFailure(tr("err_rate_limited"), kind: FailureKind.rateLimited, code: code, statusCode: status);
    }

    if (status >= 500) {
      // `arrival_failed` and friends have their own copy; a bare
      // "Server Error" does not and gets the generic server message.
      final key = "api_${code ?? ""}";
      return ServerFailure(
        code == null || !trExists(key) ? tr("err_server") : tr(key),
        kind: FailureKind.server,
        code: code,
        statusCode: status,
        body: response.body,
      );
    }

    if (code == "not_a_driver") {
      return ServerFailure(tr("api_not_a_driver"), kind: FailureKind.notADriver, code: code, statusCode: status);
    }

    if (status == 401 && isSessionInvalid(code, response.body)) {
      return ServerFailure(
        tr("err_unauthenticated"),
        kind: FailureKind.unauthenticated,
        code: code,
        statusCode: status,
      );
    }

    if (status == 404 && code == null) {
      return ServerFailure(tr("err_not_found"), kind: FailureKind.business, statusCode: status);
    }

    // `422 {msg: "<action>_refused", error, message_ar, message_en}`: the
    // server already wrote the sentence for the driver.
    final localized = localizedServerMessage(response.body);
    if (localized != null) {
      return ServerFailure(
        localized,
        kind: FailureKind.business,
        code: code,
        statusCode: status,
        bag: response.bag,
        body: response.body,
      );
    }

    return ServerFailure(
      ApiErrorMessages.forCode(code, serverMessage: serverMessage),
      kind: FailureKind.business,
      code: code,
      statusCode: status,
      bag: response.bag,
      body: response.body,
    );
  }

  /// `message_ar` / `message_en` in the app language, falling back to the
  /// other one when only one was sent.
  static String? localizedServerMessage(Map<String, dynamic> body) {
    final bool english = CacheKeysManger.getUserLanguage() == "en";
    final first = JsonUtils.asString(body[english ? "message_en" : "message_ar"]);
    if (first != null && first.trim().isNotEmpty) return first.trim();
    final second = JsonUtils.asString(body[english ? "message_ar" : "message_en"]);
    if (second != null && second.trim().isNotEmpty) return second.trim();
    return null;
  }

  /// A `401` means "session gone" only for these codes; `invalid_password`,
  /// `old_password_incorrect` and friends are ordinary business errors.
  static bool isSessionInvalid(String? code, Map<String, dynamic> body) {
    const sessionCodes = {
      "unauthenticated",
      "unauthenticated.",
      "unauthorized",
      "invalid_token",
      "token_expired",
      "invalid_jwt",
    };
    if (code == null) return body.isEmpty;
    return sessionCodes.contains(code.trim().toLowerCase());
  }
}

class CustomError extends Failure {
  CustomError(super.errMessage, {super.kind, super.code});

  static Failure getError(dynamic e) {
    if (e is DioException) {
      return ServerFailure.fromDioError(e);
    } else if (e is Failure) {
      return e;
    } else {
      return CustomError(tr("err_unexpected"), code: e.toString());
    }
  }
}
