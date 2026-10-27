import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/features/auth/data/models/login_model.dart';
import 'package:digital_trade_portal_driver/features/auth/data/models/user_model.dart';

/// 00 · Session & Auth.
abstract class AuthRepo {
  /// `PUT /api/auth/device_token` — registers the push token before login.
  Future<Either<Failure, Unit>> updateDeviceToken({required String token});

  /// `POST /api/auth/login`.
  Future<Either<Failure, LoginModel>> login({
    required String email,
    required String password,
    required String deviceToken,
  });

  /// `POST /api/auth/profile` — multipart when [image] is set.
  Future<Either<Failure, UserModel?>> updateBasicProfile({
    required int userId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    File? image,
  });

  /// `PATCH /api/auth/password`.
  Future<Either<Failure, Unit>> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  });

  /// `POST /api/auth/password/forgot`.
  Future<Either<Failure, Unit>> forgotPassword({required String email});

  /// `POST /api/auth/password/verify_code` — returns the user (with its jwt)
  /// the reset step must authenticate as.
  Future<Either<Failure, UserModel>> verifyResetCode({required String code});

  /// `POST /api/auth/password/reset`, authenticated with [jwt] from
  /// [verifyResetCode].
  Future<Either<Failure, Unit>> resetPassword({required int userId, required String password, required String jwt});
}
