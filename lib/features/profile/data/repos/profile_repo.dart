import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/content_models.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/driver_model.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/earnings_model.dart';

/// 02 · Driver profile, 11 · Earnings & performance, 14 · Content & account.
abstract class ProfileRepo {
  /// `GET /api/v2/driver/profile`.
  Future<Either<Failure, DriverModel>> getProfile();

  /// `PATCH /api/v2/driver/profile` — only these four fields persist.
  Future<Either<Failure, Unit>> updateDriverProfile({
    String? nationalId,
    String? driverLicenseNo,
    String? driverLicenseExpiry,
    String? photo,
  });

  /// `POST /api/v2/driver/terms/accept`.
  Future<Either<Failure, DateTime?>> acceptTerms();

  /// `PUT /api/v2/driver/language`.
  Future<Either<Failure, Unit>> setLanguage({required String language});

  /// `GET /api/v2/driver/earnings`.
  Future<Either<Failure, EarningsModel>> getEarnings();

  /// `GET /api/v2/driver/performance`.
  Future<Either<Failure, PerformanceModel>> getPerformance({String? since, String? until});

  /// `GET /api/abouts`.
  Future<Either<Failure, ContentPageModel>> getAbout();

  /// `GET /api/terms`.
  Future<Either<Failure, ContentPageModel>> getTerms();

  /// `GET /api/support`.
  Future<Either<Failure, List<SupportChannelModel>>> getSupport();

  /// `GET /api/countries`.
  Future<Either<Failure, List<CountryModel>>> getCountries();

  /// `POST /api/v2/account/deletion_request`.
  Future<Either<Failure, DeletionRequestModel?>> requestAccountDeletion({String? reason});

  /// `GET /api/v2/account/deletion_request` — null when none was ever filed.
  Future<Either<Failure, DeletionRequestModel?>> getAccountDeletionRequest();

  /// `DELETE /api/v2/account/deletion_request`.
  Future<Either<Failure, Unit>> cancelAccountDeletion();
}
