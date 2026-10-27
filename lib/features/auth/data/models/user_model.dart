import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';

/// The shared `users` row: identity, contact details and the session token
/// returned by login.
class UserModel {
  const UserModel({
    required this.id,
    this.firstName,
    this.lastName,
    this.name,
    this.email,
    this.phone,
    this.image,
    this.language,
    this.status,
    this.jwt,
  });

  final int id;
  final String? firstName;
  final String? lastName;

  /// Some rows carry a single `name` instead of the split fields.
  final String? name;
  final String? email;

  /// Digits only, the `m_p` marker the server prepends is already stripped.
  final String? phone;
  final String? image;
  final String? language;
  final String? status;

  /// Only present on the login response.
  final String? jwt;

  String get fullName {
    final joined = [firstName, lastName].where((part) => part != null && part.trim().isNotEmpty).join(" ");
    if (joined.isNotEmpty) return joined;
    return name?.trim() ?? "";
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: JsonUtils.asInt(json["id"]) ?? 0,
      firstName: JsonUtils.asString(json["first_name"]),
      lastName: JsonUtils.asString(json["last_name"]),
      name: JsonUtils.asString(json["name"]),
      email: JsonUtils.asString(json["email"]),
      phone: stripPhoneMarker(JsonUtils.asString(json["phone"])),
      image: JsonUtils.asString(json["image"] ?? json["avatar"] ?? json["photo"]),
      language: JsonUtils.asString(json["language"] ?? json["lang"]),
      status: JsonUtils.asString(json["status"]),
      jwt: JsonUtils.asString(json["jwt"]),
    );
  }

  /// The login response prefixes the phone with the literal `m_p`.
  static String? stripPhoneMarker(String? phone) {
    if (phone == null) return null;
    return phone.startsWith("m_p") ? phone.substring(3) : phone;
  }
}
