part of 'update_profile_cubit.dart';

sealed class UpdateProfileState {}

final class UpdateProfileInitial extends UpdateProfileState {}

final class UpdateProfileLoadingState extends UpdateProfileState {}

final class UpdateProfileSuccessState extends UpdateProfileState {
  /// The user the server sent back, when it did; the form values otherwise.
  final UserModel? user;
  final String? nationalId;
  final String? driverLicenseNo;
  final String? driverLicenseExpiry;
  final String? photo;

  UpdateProfileSuccessState({this.user, this.nationalId, this.driverLicenseNo, this.driverLicenseExpiry, this.photo});
}

final class ChangePasswordSuccessState extends UpdateProfileState {}

final class UpdateProfileErrorState extends UpdateProfileState {
  final String errMessage;

  UpdateProfileErrorState({required this.errMessage});
}
