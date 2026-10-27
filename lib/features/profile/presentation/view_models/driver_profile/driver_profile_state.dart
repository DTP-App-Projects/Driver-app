part of 'driver_profile_cubit.dart';

/// A one off message for the driver (toast). [token] lets listeners tell a
/// new message from a rebuild carrying the old one.
class ProfileMessage {
  const ProfileMessage({required this.token, required this.text, this.isError = false});

  final int token;
  final String text;
  final bool isError;
}

class DriverProfileState {
  const DriverProfileState({
    this.driver,
    this.isLoading = false,
    this.failure,
    this.isNotADriver = false,
    this.isAcceptingTerms = false,
    this.isSavingLanguage = false,
    this.message,
  });

  final DriverModel? driver;
  final bool isLoading;

  /// Why the last load failed, when it did.
  final Failure? failure;

  /// Authenticated account without a `fleet_drivers` row.
  final bool isNotADriver;
  final bool isAcceptingTerms;
  final bool isSavingLanguage;
  final ProfileMessage? message;

  bool get hasDriver => driver != null;

  /// The terms screen is due when the profile says they were not accepted.
  bool get needsTerms => driver != null && !driver!.termsAccepted;

  DriverProfileState copyWith({
    DriverModel? driver,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
    bool? isNotADriver,
    bool? isAcceptingTerms,
    bool? isSavingLanguage,
    ProfileMessage? message,
  }) {
    return DriverProfileState(
      driver: driver ?? this.driver,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
      isNotADriver: isNotADriver ?? this.isNotADriver,
      isAcceptingTerms: isAcceptingTerms ?? this.isAcceptingTerms,
      isSavingLanguage: isSavingLanguage ?? this.isSavingLanguage,
      message: message ?? this.message,
    );
  }
}
