import 'package:easy_localization/easy_localization.dart';

/// Turns the backend `msg` codes into localized copy. Every known code has an
/// `api_<code>` key in the language files; unknown codes fall back to the
/// server's human message when it sent one, then to a generic error.
class ApiErrorMessages {
  const ApiErrorMessages._();

  static const String genericKey = "err_unexpected";

  /// Localized text for a server code such as `invalid_password`.
  static String forCode(String? code, {String? serverMessage}) {
    // `{"msg":"return_failed","error":"stop_is_not_a_return"}`: the sub code
    // in `error` says what actually went wrong, so it wins when we know it.
    final subCode = _normalize(serverMessage);
    if (subCode != null && _looksLikeCode(subCode) && trExists("api_$subCode")) return tr("api_$subCode");

    // `barcode_validation_failed: [{…}]`, `shipment_not_ready_for_pickup:canceled`:
    // the reason leads, the details follow the colon.
    final head = _normalize(serverMessage?.split(":").first);
    if (head != null && _looksLikeCode(head) && trExists("api_$head")) return tr("api_$head");

    final normalized = _normalize(code);
    if (normalized != null) {
      final key = "api_$normalized";
      if (trExists(key)) return tr(key);
    }

    // Some endpoints put an already localized sentence in `msg` (login does):
    // show it as is rather than hiding it behind the generic error.
    if (code != null && code.trim().isNotEmpty && !_looksLikeCode(code)) return code.trim();

    if (serverMessage != null && serverMessage.trim().isNotEmpty && !_looksLikeCode(serverMessage)) {
      return serverMessage;
    }

    return tr(genericKey);
  }

  /// Codes such as `cannot_mark_en_route_in_status_arrived` carry the status
  /// in the tail; collapse them onto the generic key of the family.
  static String? _normalize(String? code) {
    if (code == null) return null;
    final text = code.trim().toLowerCase().replaceAll(" ", "_").replaceAll(".", "");
    if (text.isEmpty) return null;
    if (text.startsWith("cannot_mark_en_route_in_status_")) return "cannot_mark_en_route";
    if (text.startsWith("unknown_action_type")) return "unknown_action_type";
    return text;
  }

  /// `invalid_code` is a code, "The given data was invalid." is a message.
  static bool _looksLikeCode(String value) => RegExp(r"^[a-z0-9_.\-]+$").hasMatch(value.trim());
}
