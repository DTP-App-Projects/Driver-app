import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_call.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_response.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_service.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/endpoints.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/live_session_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/stop_execution_models.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/sync_event.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo.dart';

class RoutesRepoImpl implements RoutesRepo {
  final ApiService apiService;

  RoutesRepoImpl(this.apiService);

  /// Mutations answer with the changed row under `stop` (or nothing); fold
  /// it over the stop we already hold so branch, items and coordinates stay.
  RouteStop _mergeStop(RouteStop current, ApiResponse response, {StopStatus? fallbackStatus}) {
    final stopJson = JsonUtils.asMapOrNull(response.body["stop"] ?? response.dataMap["stop"]);
    if (stopJson != null) return current.mergeServer(stopJson);
    return fallbackStatus == null ? current : current.copyWith(status: fallbackStatus);
  }

  RouteModel? _routeFrom(ApiResponse response) {
    final routeJson = JsonUtils.asMapOrNull(response.body["route"] ?? response.dataMap["route"]);
    return routeJson == null || routeJson["id"] == null ? null : RouteModel.fromJson(routeJson);
  }

  @override
  Future<Either<Failure, TodayRouteModel>> getTodayRoute({String? date}) {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.todayRoute, query: {"date": ?date}),
      (response) => TodayRouteModel.fromJson(response.body),
    );
  }

  @override
  Future<Either<Failure, RouteModel?>> startRoute({required int routeId}) {
    return apiCall(() => apiService.postData(endPoint: EndPoints.startRoute(routeId), data: const {}), _routeFrom);
  }

  @override
  Future<Either<Failure, RouteModel?>> completeRoute({required int routeId}) {
    return apiCall(() => apiService.postData(endPoint: EndPoints.completeRoute(routeId), data: const {}), _routeFrom);
  }

  @override
  Future<Either<Failure, RouteHistoryPage>> getHistory({int page = 1}) {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.routeHistory, query: {"page": page}),
      (response) => RouteHistoryPage.fromJson(response.body),
    );
  }

  @override
  Future<Either<Failure, EndOfDaySummaryModel>> getEndOfDaySummary({String? date}) {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.endOfDaySummary, query: {"date": ?date}),
      (response) => EndOfDaySummaryModel.fromJson(response.body),
    );
  }

  @override
  Future<Either<Failure, RouteStop>> markStopEnRoute({required RouteStop stop}) {
    return apiCall(
      () => apiService.postData(endPoint: EndPoints.stopEnRoute(stop.id), data: const {}),
      (response) => _mergeStop(stop, response, fallbackStatus: StopStatus.enRoute),
    );
  }

  @override
  Future<Either<Failure, ArrivalResult>> arriveAtStop({
    required RouteStop stop,
    double? latitude,
    double? longitude,
    String? notes,
  }) {
    return apiCall(
      () => apiService.postData(
        endPoint: EndPoints.stopArrive(stop.id),
        data: {"latitude": ?latitude, "longitude": ?longitude, if (notes != null && notes.isNotEmpty) "notes": notes},
      ),
      (response) => ArrivalResult.fromJson(response.body, current: stop),
    );
  }

  @override
  Future<Either<Failure, RouteStop>> confirmPickup({required RouteStop stop, required PickupRequest request}) {
    return apiCall(
      () => apiService.postData(endPoint: EndPoints.stopPickup(stop.id), data: request.toJson()),
      (response) => _mergeStop(stop, response, fallbackStatus: StopStatus.completed),
    );
  }

  @override
  Future<Either<Failure, RouteStop>> confirmDelivery({required RouteStop stop, required DeliveryRequest request}) {
    return apiCall(
      () => apiService.postData(endPoint: EndPoints.stopDeliver(stop.id), data: request.toJson()),
      (response) => _mergeStop(stop, response, fallbackStatus: StopStatus.completed),
    );
  }

  @override
  Future<Either<Failure, RouteStop>> confirmReturn({required RouteStop stop, required ReturnRequest request}) {
    return apiCall(
      () => apiService.postData(endPoint: EndPoints.stopReturn(stop.id), data: request.toJson()),
      (response) => _mergeStop(stop, response, fallbackStatus: StopStatus.completed),
    );
  }

  @override
  Future<Either<Failure, RouteStop>> skipStop({required RouteStop stop, String? reason}) {
    return apiCall(
      () => apiService.postData(
        endPoint: EndPoints.stopSkip(stop.id),
        data: {if (reason != null && reason.isNotEmpty) "reason": reason},
      ),
      (response) => _mergeStop(stop, response, fallbackStatus: StopStatus.skipped),
    );
  }

  @override
  Future<Either<Failure, ReceiptStatusModel>> getReceiptStatus({required int stopId}) {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.stopReceiptStatus(stopId)),
      (response) => ReceiptStatusModel.fromJson(response.dataMap),
    );
  }

  /// OTP outcomes are reported through `success` / `msg` in the body: a wrong
  /// code is business data for the sheet (attempts left, resend needed), not
  /// a transport failure, so it is returned as a `Right`.
  Future<Either<Failure, OtpResult>> _otpCall(Future<ApiResponse> Function() request) async {
    try {
      final response = await request();
      final result = OtpResult.fromJson(response.body);
      if (response.isSuccess || result.msg != null && _otpBusinessCodes.contains(result.msg)) {
        return right(result);
      }
      return left(ServerFailure.fromApiResponse(response));
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map) {
        final result = OtpResult.fromJson(JsonUtils.asMap(body));
        if (result.msg != null && _otpBusinessCodes.contains(result.msg)) return right(result);
      }
      return left(ServerFailure.fromDioError(error));
    } catch (error) {
      return left(CustomError.getError(error));
    }
  }

  static const Set<String> _otpBusinessCodes = {
    "invalid_code",
    "otp_expired",
    "max_attempts_reached",
    "no_active_otp",
    "requires_generation",
    "invalid_handoff_qr",
    "handoff_qr_for_another_stop",
  };

  @override
  Future<Either<Failure, OtpResult>> resendOtp({required int stopId}) {
    return _otpCall(() => apiService.postData(endPoint: EndPoints.otpResend(stopId), data: const {}));
  }

  @override
  Future<Either<Failure, OtpResult>> verifyOtp({required int stopId, required String otpCode}) {
    return _otpCall(() => apiService.postData(endPoint: EndPoints.otpVerify(stopId), data: {"otp_code": otpCode}));
  }

  @override
  Future<Either<Failure, OtpResult>> verifyHandoff({required int stopId, String? handoffQr, String? otpCode}) {
    return _otpCall(
      () => apiService.postData(
        endPoint: EndPoints.handoffVerify(stopId),
        data: {
          if (handoffQr != null && handoffQr.isNotEmpty) "handoff_qr": handoffQr,
          if (otpCode != null && otpCode.isNotEmpty) "otp_code": otpCode,
        },
      ),
    );
  }

  @override
  Future<Either<Failure, BarcodeResult>> verifyBarcode({required int stopId, required String barcode}) async {
    // A mismatch is HTTP 200 with success:false — surfaced as data, not error.
    try {
      final response = await apiService.postData(endPoint: EndPoints.barcodeVerify(stopId), data: {"barcode": barcode});
      if (response.httpStatus >= 200 && response.httpStatus < 300) {
        return right(BarcodeResult.fromJson(response.body, barcode: barcode));
      }
      return left(ServerFailure.fromApiResponse(response));
    } catch (error) {
      return left(CustomError.getError(error));
    }
  }

  @override
  Future<Either<Failure, SealResult>> submitSeals({
    required int stopId,
    required List<String> seals,
    required bool isDelivery,
  }) async {
    // `success:false` here means seal mismatch — tamper evidence the sheet
    // must show, so it is data, not a failure.
    try {
      final response = await apiService.postData(
        endPoint: EndPoints.stopSeals(stopId),
        data: {"seals": seals, "mode": isDelivery ? "delivery" : "pickup"},
      );
      if (response.httpStatus >= 200 && response.httpStatus < 300) return right(SealResult.fromJson(response.body));
      return left(ServerFailure.fromApiResponse(response));
    } catch (error) {
      return left(CustomError.getError(error));
    }
  }

  @override
  Future<Either<Failure, StopItemModel?>> partialReject({
    required int stopId,
    required int itemId,
    required double rejectedQty,
    required String reason,
    String? notes,
  }) {
    return apiCall(
      () => apiService.postData(
        endPoint: EndPoints.partialReject(stopId),
        data: {
          "item_id": itemId,
          "rejected_qty": rejectedQty,
          "reason": reason,
          if (notes != null && notes.isNotEmpty) "notes": notes,
        },
      ),
      (response) {
        final item = JsonUtils.asMapOrNull(response.body["item"] ?? response.dataMap["item"]);
        return item == null ? null : StopItemModel.fromJson(item);
      },
    );
  }

  @override
  Future<Either<Failure, UploadResult>> uploadAttachment({required File file, String module = "proof"}) async {
    final form = FormData.fromMap({
      "attachment": await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
      "module": module,
    });
    return apiCall(
      () => apiService.postData(endPoint: EndPoints.uploads, data: form),
      // Documented as `{data:{file_path}}`, served as `{file:{file_path}}`.
      (response) => UploadResult.fromJson(JsonUtils.asMapOrNull(response.body["file"]) ?? response.dataMap),
    );
  }

  /// One multipart call with the picture under `file`, or JSON with the
  /// `file_path` of an earlier upload. The multipart form carries
  /// `watermark_data` as a JSON string.
  Future<dynamic> _proofBody(ProofRequest request) async {
    if (!request.isMultipart) return request.toJson();
    final file = request.file!;
    final fields = request.toJson();
    if (request.watermarkData != null) fields["watermark_data"] = jsonEncode(request.watermarkData);
    return FormData.fromMap({
      ...fields,
      "file": await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
    });
  }

  @override
  Future<Either<Failure, ProofModel?>> attachProof({required int stopId, required ProofRequest request}) async {
    final body = await _proofBody(request);
    return apiCall(() => apiService.postData(endPoint: EndPoints.stopProof(stopId), data: body), (response) {
      final proof = JsonUtils.asMapOrNull(response.body["proof"]);
      if (proof == null) return null;
      // `file_url` is the only address to display the picture from: the
      // response puts it next to the row, so fold it in when the row lacks it.
      final fileUrl = JsonUtils.asString(response.body["file_url"]);
      return ProofModel.fromJson({"file_url": ?fileUrl, ...proof});
    });
  }

  @override
  Future<Either<Failure, LiveSessionModel>> getLiveSession() async {
    final result = await apiCall(
      () => apiService.get(endPoint: EndPoints.driverLive),
      (response) => LiveSessionModel.fromJson(response.body),
    );
    // No route in progress today: nothing to share, not an error.
    return result.fold(
      (failure) => failure.code == "no_active_route" ? right(LiveSessionModel.disabled) : left(failure),
      right,
    );
  }

  @override
  Future<Either<Failure, int>> sendLocations({required List<LocationPoint> points}) {
    return apiCall(
      () => apiService.postData(
        endPoint: EndPoints.location,
        data: {
          "locations": [for (final point in points) point.toJson()],
        },
      ),
      (response) => JsonUtils.asInt(response.body["points_saved"]) ?? points.length,
    );
  }

  @override
  Future<Either<Failure, List<SyncResult>>> syncBatch({required List<SyncEvent> events}) {
    return apiCall(
      () => apiService.postData(
        endPoint: EndPoints.syncBatch,
        data: {
          "events": [for (final event in events) event.toApiJson()],
        },
      ),
      (response) => [for (final item in JsonUtils.asMapList(response.body["results"])) SyncResult.fromJson(item)],
    );
  }
}
