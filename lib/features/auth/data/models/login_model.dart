import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/features/auth/data/models/user_model.dart';

/// `POST /api/auth/login` → `{ user: { …, id, jwt } }`.
class LoginModel {
  const LoginModel({required this.user, this.message});

  final UserModel user;
  final String? message;

  String get jwt => user.jwt ?? "";

  factory LoginModel.fromJson(Map<String, dynamic> json) {
    return LoginModel(
      user: UserModel.fromJson(JsonUtils.asMap(json["user"])),
      message: JsonUtils.asString(json["msg"] ?? json["message"]),
    );
  }
}
