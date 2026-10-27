import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/cache_keys.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_call.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_response.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_service.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/endpoints.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/content_models.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/driver_model.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/earnings_model.dart';
import 'package:digital_trade_portal_driver/features/profile/data/repos/profile_repo.dart';

class ProfileRepoImpl implements ProfileRepo {
  final ApiService apiService;

  ProfileRepoImpl(this.apiService);

  String get _language {
    final language = CacheKeysManger.getUserLanguage();
    return language.isEmpty ? "ar" : language;
  }

  @override
  Future<Either<Failure, DriverModel>> getProfile() {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.driverProfile),
      (response) => DriverModel.fromJson(JsonUtils.asMap(response.body["driver"] ?? response.data)),
    );
  }

  @override
  Future<Either<Failure, Unit>> updateDriverProfile({
    String? nationalId,
    String? driverLicenseNo,
    String? driverLicenseExpiry,
    String? photo,
  }) {
    return apiCall(
      () => apiService.patchData(
        endPoint: EndPoints.driverProfile,
        data: {
          "national_id": ?nationalId,
          "driver_license_no": ?driverLicenseNo,
          "driver_license_expiry": ?driverLicenseExpiry,
          "photo": ?photo,
        },
      ),
      (_) => unit,
    );
  }

  @override
  Future<Either<Failure, DateTime?>> acceptTerms() {
    return apiCall(
      () => apiService.postData(endPoint: EndPoints.acceptTerms, data: const {}),
      (response) => JsonUtils.asDate(response.body["accepted_at"]) ?? DateTime.now(),
    );
  }

  @override
  Future<Either<Failure, Unit>> setLanguage({required String language}) {
    return apiCall(
      () => apiService.putData(endPoint: EndPoints.setLanguage, data: {"language": language}),
      (_) => unit,
    );
  }

  @override
  Future<Either<Failure, EarningsModel>> getEarnings() {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.earnings),
      (response) => EarningsModel.fromJson(response.dataMap),
    );
  }

  @override
  Future<Either<Failure, PerformanceModel>> getPerformance({String? since, String? until}) {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.performance, query: {"since": ?since, "until": ?until}),
      (response) => PerformanceModel.fromJson(response.dataMap),
    );
  }

  @override
  Future<Either<Failure, ContentPageModel>> getAbout() {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.abouts, sendToken: false),
      (response) => ContentPageModel.fromJson(response.body, language: _language),
    );
  }

  @override
  Future<Either<Failure, ContentPageModel>> getTerms() {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.terms, sendToken: false),
      (response) => ContentPageModel.fromJson(response.body, language: _language),
    );
  }

  @override
  Future<Either<Failure, List<SupportChannelModel>>> getSupport() {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.support, sendToken: false),
      (response) => SupportChannelModel.listFromJson(response.body),
    );
  }

  @override
  Future<Either<Failure, List<CountryModel>>> getCountries() {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.countries, sendToken: false),
      (response) => CountryModel.listFromJson(response.body, language: _language),
    );
  }

  @override
  Future<Either<Failure, DeletionRequestModel?>> requestAccountDeletion({String? reason}) {
    return apiCall(
      () => apiService.postData(
        endPoint: EndPoints.accountDeletionRequest,
        data: {if (reason != null && reason.trim().isNotEmpty) "reason": reason.trim()},
      ),
      _parseDeletionRequest,
    );
  }

  @override
  Future<Either<Failure, DeletionRequestModel?>> getAccountDeletionRequest() {
    return apiCall(() => apiService.get(endPoint: EndPoints.accountDeletionRequest), _parseDeletionRequest);
  }

  @override
  Future<Either<Failure, Unit>> cancelAccountDeletion() {
    return apiCall(() => apiService.deleteData(endPoint: EndPoints.accountDeletionRequest), (_) => unit);
  }

  DeletionRequestModel? _parseDeletionRequest(ApiResponse response) {
    final request = JsonUtils.asMapOrNull(response.body["request"] ?? response.body["data"]);
    if (request == null || request["id"] == null) return null;
    return DeletionRequestModel.fromJson(request);
  }
}
