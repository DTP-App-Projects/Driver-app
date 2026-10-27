import 'package:bloc/bloc.dart';
import 'package:digital_trade_portal_driver/features/auth/data/models/user_model.dart';
import 'package:digital_trade_portal_driver/features/auth/data/repos/auth_repo.dart';

part 'forgot_password_state.dart';

/// Three step reset: e-mail the code, check it, set the new password with
/// the token the check returned.
class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  ForgotPasswordCubit(this.repo) : super(ForgotPasswordInitial());
  final AuthRepo repo;

  /// User returned by the code check; the reset step authenticates as them.
  UserModel? verifiedUser;

  Future<void> sendCode({required String email}) async {
    if (state is ForgotPasswordLoadingState) return;
    emit(ForgotPasswordLoadingState());
    final result = await repo.forgotPassword(email: email.trim());
    result.fold(
      (failure) => emit(ForgotPasswordErrorState(errMessage: failure.errMessage)),
      (_) => emit(ForgotPasswordCodeSentState()),
    );
  }

  Future<void> verifyCode({required String code}) async {
    if (state is ForgotPasswordLoadingState) return;
    emit(ForgotPasswordLoadingState());
    final result = await repo.verifyResetCode(code: code.trim());
    result.fold((failure) => emit(ForgotPasswordErrorState(errMessage: failure.errMessage)), (user) {
      verifiedUser = user;
      emit(ForgotPasswordCodeVerifiedState(user: user));
    });
  }

  Future<void> resetPassword({required String password}) async {
    final user = verifiedUser;
    if (user == null || state is ForgotPasswordLoadingState) return;
    emit(ForgotPasswordLoadingState());
    final result = await repo.resetPassword(userId: user.id, password: password, jwt: user.jwt ?? "");
    result.fold(
      (failure) => emit(ForgotPasswordErrorState(errMessage: failure.errMessage)),
      (_) => emit(ForgotPasswordResetSuccessState()),
    );
  }
}
