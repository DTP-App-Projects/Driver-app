import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_call.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/endpoints.dart';
import 'package:digital_trade_portal_driver/features/auth/data/models/login_model.dart';
import 'package:digital_trade_portal_driver/features/auth/data/models/user_model.dart';
import 'package:digital_trade_portal_driver/features/auth/data/repos/auth_repo.dart';
import '../../../../core/utils/services/remote_services/api_service.dart';

class AuthRepoImpl implements AuthRepo {
  final ApiService apiService;

  AuthRepoImpl(this.apiService);

  @override
  Future<Either<Failure, Unit>> updateDeviceToken({required String token}) {
    return apiCall(
      () => apiService.putData(endPoint: EndPoints.deviceToken, sendToken: false, data: {"token": token}),
      (_) => unit,
    );
  }

  @override
  Future<Either<Failure, LoginModel>> login({
    required String email,
    required String password,
    required String deviceToken,
  }) async {
    final result = await apiCall(
      () => apiService.postData(
        endPoint: EndPoints.login,
        sendToken: false,
        data: {"token": deviceToken, "email": email, "password": password},
      ),
      (response) => LoginModel.fromJson(response.body),
    );

    return result.fold((failure) => left(failure), (model) {
      // A suspended account answers 200 without a user; never treat that as
      // a session.
      if (model.jwt.isEmpty) {
        return left(
          ServerFailure(
            model.message ?? tr("err_unexpected"),
            kind: FailureKind.business,
            code: model.message,
            statusCode: 200,
          ),
        );
      }
      return right(model);
    });
  }

  @override
  Future<Either<Failure, UserModel?>> updateBasicProfile({
    required int userId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    File? image,
  }) async {
    final fields = <String, dynamic>{
      "user_id": userId,
      "first_name": firstName,
      "last_name": lastName,
      "email": email,
      "phone": phone,
    };

    // Multipart only when the avatar travels with the request.
    final dynamic data = image == null
        ? fields
        : FormData.fromMap({...fields, "image": await MultipartFile.fromFile(image.path)});

    return apiCall(() => apiService.postData(endPoint: EndPoints.updateBasicProfile, data: data), (response) {
      final user = JsonUtils.asMapOrNull(response.body["user"] ?? response.body["data"]);
      return user == null || user["id"] == null ? null : UserModel.fromJson(user);
    });
  }

  @override
  Future<Either<Failure, Unit>> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) {
    return apiCall(
      () => apiService.patchData(
        endPoint: EndPoints.changePassword,
        data: {"user_id": userId, "old_password": oldPassword, "new_password": newPassword},
      ),
      (_) => unit,
    );
  }

  @override
  Future<Either<Failure, Unit>> forgotPassword({required String email}) {
    return apiCall(
      () => apiService.postData(endPoint: EndPoints.forgotPassword, sendToken: false, data: {"email": email}),
      (_) => unit,
    );
  }

  @override
  Future<Either<Failure, UserModel>> verifyResetCode({required String code}) {
    return apiCall(
      () => apiService.postData(endPoint: EndPoints.verifyResetCode, sendToken: false, data: {"code": code}),
      (response) =>
          UserModel.fromJson(JsonUtils.asMap(response.body["user"] ?? response.body["data"] ?? response.body)),
    );
  }

  @override
  Future<Either<Failure, Unit>> resetPassword({required int userId, required String password, required String jwt}) {
    return apiCall(
      () => apiService.postData(
        endPoint: EndPoints.resetPassword,
        sendToken: false,
        headers: {"Authorization": "Bearer $jwt"},
        data: {"user_id": userId, "password": password},
      ),
      (_) => unit,
    );
  }
}
