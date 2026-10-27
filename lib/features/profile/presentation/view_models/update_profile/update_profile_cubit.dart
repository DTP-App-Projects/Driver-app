import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/cache_keys.dart';
import 'package:digital_trade_portal_driver/features/auth/data/models/user_model.dart';
import 'package:digital_trade_portal_driver/features/auth/data/repos/auth_repo.dart';
import 'package:digital_trade_portal_driver/features/profile/data/repos/profile_repo.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo.dart';

part 'update_profile_state.dart';

/// The account form: shared user fields through `POST /api/auth/profile`
/// (multipart when an avatar is picked) and the driver only fields through
/// `PATCH /driver/profile`; a driver photo is uploaded first and sent as
/// the returned path.
class UpdateProfileCubit extends Cubit<UpdateProfileState> {
  UpdateProfileCubit({required this.authRepo, required this.profileRepo, required this.routesRepo})
    : super(UpdateProfileInitial());

  final AuthRepo authRepo;
  final ProfileRepo profileRepo;
  final RoutesRepo routesRepo;

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    File? avatar,
    String? nationalId,
    String? driverLicenseNo,
    String? driverLicenseExpiry,
    File? driverPhoto,
  }) async {
    if (state is UpdateProfileLoadingState) return;
    final userId = CacheKeysManger.getUserId();
    if (userId == null) {
      emit(UpdateProfileErrorState(errMessage: "err_unauthenticated"));
      return;
    }
    emit(UpdateProfileLoadingState());

    final basic = await authRepo.updateBasicProfile(
      userId: userId,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: email.trim(),
      phone: phone.trim(),
      image: avatar,
    );
    if (isClosed) return;

    await basic.fold((failure) async => emit(UpdateProfileErrorState(errMessage: failure.errMessage)), (user) async {
      String? photoPath;
      if (driverPhoto != null) {
        final upload = await routesRepo.uploadAttachment(file: driverPhoto, module: "driver_photo");
        upload.fold((_) {}, (result) => photoPath = result.filePath);
      }

      final driver = await profileRepo.updateDriverProfile(
        nationalId: nationalId,
        driverLicenseNo: driverLicenseNo,
        driverLicenseExpiry: driverLicenseExpiry,
        photo: photoPath,
      );
      if (isClosed) return;

      driver.fold(
        (failure) => emit(UpdateProfileErrorState(errMessage: failure.errMessage)),
        (_) => emit(
          UpdateProfileSuccessState(
            user: user,
            nationalId: nationalId,
            driverLicenseNo: driverLicenseNo,
            driverLicenseExpiry: driverLicenseExpiry,
            photo: photoPath,
          ),
        ),
      );
    });
  }

  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    if (state is UpdateProfileLoadingState) return;
    final userId = CacheKeysManger.getUserId();
    if (userId == null) return;
    emit(UpdateProfileLoadingState());

    final result = await authRepo.changePassword(userId: userId, oldPassword: oldPassword, newPassword: newPassword);
    if (isClosed) return;
    result.fold(
      (failure) => emit(UpdateProfileErrorState(errMessage: failure.errMessage)),
      (_) => emit(ChangePasswordSuccessState()),
    );
  }

  /// Non-fatal: returns the unit either way so the caller keeps going.
  Future<Unit> reset() async {
    emit(UpdateProfileInitial());
    return unit;
  }
}
