part of 'forgot_password_cubit.dart';

sealed class ForgotPasswordState {}

final class ForgotPasswordInitial extends ForgotPasswordState {}

final class ForgotPasswordLoadingState extends ForgotPasswordState {}

final class ForgotPasswordCodeSentState extends ForgotPasswordState {}

final class ForgotPasswordCodeVerifiedState extends ForgotPasswordState {
  final UserModel user;

  ForgotPasswordCodeVerifiedState({required this.user});
}

final class ForgotPasswordResetSuccessState extends ForgotPasswordState {}

final class ForgotPasswordErrorState extends ForgotPasswordState {
  final String errMessage;

  ForgotPasswordErrorState({required this.errMessage});
}
