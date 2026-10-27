import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/cache_keys.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/location_tracker.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/session_manager.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/features/auth/data/models/user_model.dart';
import 'package:digital_trade_portal_driver/features/my_cars/data/models/vehicle_model.dart';
import 'package:digital_trade_portal_driver/features/notification/data/repos/notifications_repo.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/driver_model.dart';
import 'package:digital_trade_portal_driver/features/profile/data/repos/profile_repo.dart';

part 'driver_profile_state.dart';

/// The signed in driver, loaded right after login / at app boot and kept for
/// the whole session: profile screen, home greeting, terms gate, push
/// registration and logout all go through here.
class DriverProfileCubit extends Cubit<DriverProfileState> {
  DriverProfileCubit({required this.profileRepo, required this.notificationsRepo}) : super(const DriverProfileState()) {
    SessionManager.addSessionClearedListener(reset);
  }

  final ProfileRepo profileRepo;
  final NotificationsRepo notificationsRepo;

  int _token = 0;

  int get _nextToken => ++_token;

  @override
  Future<void> close() {
    SessionManager.removeSessionClearedListener(reset);
    return super.close();
  }

  void reset() {
    if (!isClosed) emit(const DriverProfileState());
  }

  DriverModel? get driver => state.driver;

  /// App boot call. A `403 not_a_driver` is a distinct state, not an error
  /// toast: the account is fine, it just is not a driver yet.
  Future<void> loadProfile({bool silent = false}) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: !silent, clearFailure: true, isNotADriver: false));

    final result = await profileRepo.getProfile();
    if (isClosed) return;

    result.fold(
      (failure) {
        emit(state.copyWith(isLoading: false, failure: failure, isNotADriver: failure.isNotADriver));
      },
      (driver) async {
        await CacheKeysManger.saveDriverId(driver.id);
        // Acceptance is sticky: once the driver accepted on this device the gate
        // stays closed even if the profile payload omits (or lags) the flag.
        if (driver.termsAccepted) {
          await CacheKeysManger.saveTermsAccepted(true);
        } else if (CacheKeysManger.getTermsAccepted()) {
          driver = driver.copyWith(termsAccepted: true);
        }
        if (isClosed) return;
        emit(state.copyWith(driver: driver, isLoading: false, clearFailure: true, isNotADriver: false));
        registerPushToken();
      },
    );
  }

  /// `POST /driver/terms/accept`, then the gate closes for good.
  Future<bool> acceptTerms() async {
    if (state.isAcceptingTerms) return false;
    emit(state.copyWith(isAcceptingTerms: true));

    final result = await profileRepo.acceptTerms();
    if (isClosed) return false;

    return result.fold(
      (failure) {
        emit(state.copyWith(isAcceptingTerms: false, message: _error(failure.errMessage)));
        return false;
      },
      (acceptedAt) {
        CacheKeysManger.saveTermsAccepted(true);
        emit(
          state.copyWith(
            isAcceptingTerms: false,
            driver: state.driver?.copyWith(termsAccepted: true, termsAcceptedAt: acceptedAt),
          ),
        );
        return true;
      },
    );
  }

  /// Keeps the backend user language in step with the UI so server sent
  /// notifications arrive in the language the driver reads.
  Future<void> setLanguage(String language) async {
    if (!await CacheKeysManger.isLoggedIn() || isClosed) return;
    emit(state.copyWith(isSavingLanguage: true));
    final result = await profileRepo.setLanguage(language: language);
    if (isClosed) return;
    result.fold(
      (_) => emit(state.copyWith(isSavingLanguage: false)),
      (_) => emit(state.copyWith(isSavingLanguage: false, driver: state.driver?.copyWith(language: language))),
    );
  }

  /// `POST /push/register` — after login and on every token refresh.
  Future<void> registerPushToken() async {
    final token = CacheKeysManger.getDeviceToken();
    if (token == null || token.isEmpty || !await CacheKeysManger.isLoggedIn()) return;
    final language = CacheKeysManger.getUserLanguage();
    await notificationsRepo.registerPushToken(
      token: token,
      platform: Platform.isIOS ? "ios" : "android",
      locale: language.isEmpty ? "ar" : language,
    );
  }

  /// Applies edits made through the account form without a reload.
  void applyUser(UserModel user) {
    final driver = state.driver;
    if (driver == null) return;
    emit(state.copyWith(driver: driver.copyWith(user: user)));
  }

  void applyDriverFields({String? nationalId, String? driverLicenseNo, String? driverLicenseExpiry, String? photo}) {
    final driver = state.driver;
    if (driver == null) return;
    emit(
      state.copyWith(
        driver: driver.copyWith(
          nationalId: nationalId,
          driverLicenseNo: driverLicenseNo,
          driverLicenseExpiry: driverLicenseExpiry,
          photo: photo,
        ),
      ),
    );
  }

  void applyVehicle(VehicleModel vehicle) {
    final driver = state.driver;
    if (driver == null) return;
    emit(
      state.copyWith(
        driver: driver.copyWith(defaultVehicle: vehicle..isAssigned = true, defaultVehicleId: vehicle.id),
      ),
    );
  }

  /// Unregisters the push token, stops tracking and forgets the session.
  /// Navigation is left to the caller so the existing flow stays in place.
  Future<void> logout() async {
    final token = CacheKeysManger.getDeviceToken();
    if (token != null && token.isNotEmpty) {
      // Best effort: the device must stop receiving this driver's pushes.
      await notificationsRepo.unregisterPushToken(token: token);
    }
    await getIt.get<LocationTracker>().stop();
    await SessionManager.clear();
  }

  ProfileMessage _error(String text) => ProfileMessage(token: _nextToken, text: text, isError: true);
}
