import 'package:bloc/bloc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/cache_keys.dart';
import 'package:digital_trade_portal_driver/features/auth/data/models/login_model.dart';
import 'package:digital_trade_portal_driver/features/auth/data/repos/auth_repo.dart';
part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this.repo) : super(LoginInitial());
  final AuthRepo repo;

  Future<void> login({required String email, required String password}) async {
    if (state is LoginLoadingState) return;
    emit(LoginLoadingState());

    final deviceToken = await _deviceToken();
    // Registers the push token row before login, as the API flow asks; a
    // failure here must not block signing in.
    if (deviceToken.isNotEmpty) await repo.updateDeviceToken(token: deviceToken);

    final result = await repo.login(email: email.trim(), password: password, deviceToken: deviceToken);
    return result.fold(
      (failure) {
        emit(LoginErrorState(errMessage: failure.errMessage));
      },
      (data) async {
        await CacheKeysManger.saveToken(token: data.jwt);
        await CacheKeysManger.saveUserId(data.user.id);
        emit(LoginSuccessState(model: data));
      },
    );
  }

  /// The FCM token saved at startup, or a fresh one when startup could not
  /// get it (no network yet, APNs still warming up on iOS).
  Future<String> _deviceToken() async {
    final cached = CacheKeysManger.getDeviceToken();
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await CacheKeysManger.saveDeviceToken(token);
        return token;
      }
    } catch (error) {
      debugPrint("Device token unavailable at login: $error");
    }
    return "";
  }
}
