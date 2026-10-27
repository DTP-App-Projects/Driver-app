import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';

/// Localised page returned by `/api/abouts` and `/api/terms`. The rows carry
/// a title and a body under a few possible column names, so both are read
/// tolerantly and the localised variant wins when present.
class ContentPageModel {
  const ContentPageModel({this.title, this.body, this.raw = const {}});

  final String? title;
  final String? body;
  final Map<String, dynamic> raw;

  bool get isEmpty => (body ?? "").trim().isEmpty;

  factory ContentPageModel.fromJson(dynamic value, {required String language}) {
    // `{data: {...}}`, `{data: [{...}]}`, a bare row, or a list of rows.
    dynamic node = value;
    if (node is Map && node.containsKey("data")) node = node["data"];
    if (node is List) node = node.isEmpty ? const {} : node.first;
    final json = JsonUtils.asMap(node);

    String? pick(List<String> keys) {
      for (final key in keys) {
        final text = JsonUtils.asString(json[key]);
        if (text != null && text.trim().isNotEmpty) return text;
      }
      return null;
    }

    return ContentPageModel(
      title: pick(["title_$language", "title", "name_$language", "name"]),
      body: pick([
        "content_$language",
        "description_$language",
        "body_$language",
        "text_$language",
        "content",
        "description",
        "body",
        "text",
        "about",
        "terms",
      ]),
      raw: json,
    );
  }
}

/// One support channel (phone, e-mail, WhatsApp…) from `/api/support`.
class SupportChannelModel {
  const SupportChannelModel({required this.label, required this.value, this.type});

  final String label;
  final String value;

  /// `phone`, `email`, `whatsapp`, `url` or null when unknown.
  final String? type;

  bool get isPhone => type == "phone" || type == "whatsapp";

  bool get isEmail => type == "email";

  bool get isUrl => type == "url";

  /// The support endpoint returns either a row of contact columns or a list
  /// of channel rows; both become a flat list of label/value pairs.
  static List<SupportChannelModel> listFromJson(dynamic value) {
    dynamic node = value;
    if (node is Map && node.containsKey("data")) node = node["data"];

    final channels = <SupportChannelModel>[];

    void addFromRow(Map<String, dynamic> row) {
      // A row shaped like {type/name/label, value/contact}
      final explicitValue = JsonUtils.asString(row["value"] ?? row["contact"] ?? row["link"]);
      if (explicitValue != null && explicitValue.trim().isNotEmpty) {
        final label = JsonUtils.asString(row["label"] ?? row["title"] ?? row["name"] ?? row["type"]) ?? "";
        channels.add(SupportChannelModel(label: label, value: explicitValue, type: _guessType(label, explicitValue)));
        return;
      }
      // A row of contact columns: {phone, email, whatsapp, ...}
      row.forEach((key, item) {
        if (item == null || item is Map || item is List) return;
        final text = item.toString().trim();
        if (text.isEmpty) return;
        final lower = key.toLowerCase();
        if (lower == "id" || lower.contains("created") || lower.contains("updated") || lower.contains("deleted")) {
          return;
        }
        channels.add(SupportChannelModel(label: key, value: text, type: _guessType(key, text)));
      });
    }

    if (node is List) {
      for (final item in JsonUtils.asMapList(node)) {
        addFromRow(item);
      }
    } else if (node is Map) {
      addFromRow(JsonUtils.asMap(node));
    }

    return channels;
  }

  static String? _guessType(String label, String value) {
    final lower = "$label ${value.toLowerCase()}";
    if (lower.contains("whatsapp")) return "whatsapp";
    if (lower.contains("@") || lower.contains("mail")) return "email";
    if (value.startsWith("http")) return "url";
    if (lower.contains("phone") ||
        lower.contains("mobile") ||
        lower.contains("tel") ||
        RegExp(r"^\+?\d{7,}$").hasMatch(value)) {
      return "phone";
    }
    return null;
  }
}

/// A row of `/api/countries`: countries have `type = main`, cities `type = sub`.
class CountryModel {
  const CountryModel({required this.id, required this.name, this.type, this.parentId, this.code});

  final int id;
  final String name;
  final String? type;
  final int? parentId;
  final String? code;

  bool get isCountry => type == null || type == "main";

  factory CountryModel.fromJson(Map<String, dynamic> json, {required String language}) => CountryModel(
    id: JsonUtils.asInt(json["id"]) ?? 0,
    name: JsonUtils.asString(json["name_$language"] ?? json["name"] ?? json["title"]) ?? "",
    type: JsonUtils.asString(json["type"]),
    parentId: JsonUtils.asInt(json["parent_id"] ?? json["country_id"]),
    code: JsonUtils.asString(json["code"] ?? json["phone_code"]),
  );

  static List<CountryModel> listFromJson(dynamic value, {required String language}) {
    dynamic node = value;
    if (node is Map && node.containsKey("data")) node = node["data"];
    return [for (final item in JsonUtils.asMapList(node)) CountryModel.fromJson(item, language: language)];
  }
}

/// `/api/v2/account/deletion_request` → `request`.
class DeletionRequestModel {
  const DeletionRequestModel({required this.id, this.status, this.reason, this.rejectionReason, this.createdAt});

  final int id;
  final String? status;
  final String? reason;
  final String? rejectionReason;
  final DateTime? createdAt;

  /// Pending / approved requests can still be cancelled; a rejected or
  /// cancelled one is history.
  bool get isActive => status == null || status == "pending" || status == "approved" || status == "active";

  factory DeletionRequestModel.fromJson(Map<String, dynamic> json) => DeletionRequestModel(
    id: JsonUtils.asInt(json["id"]) ?? 0,
    status: JsonUtils.asString(json["status"]),
    reason: JsonUtils.asString(json["reason"]),
    rejectionReason: JsonUtils.asString(json["rejection_reason"] ?? json["admin_notes"] ?? json["notes"]),
    createdAt: JsonUtils.asDate(json["created_at"] ?? json["requested_at"]),
  );
}
