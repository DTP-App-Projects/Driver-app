import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/live_session_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/stop_execution_models.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/sync_event.dart';

/// 03 · Routes, 04 · Stops, 05 · OTP, 06 · Barcode & seals, 07 · Proofs,
/// 08 · Location, 13 · Sync.
abstract class RoutesRepo {
  /// `GET /api/v2/driver/today_route?date=`.
  Future<Either<Failure, TodayRouteModel>> getTodayRoute({String? date});

  /// `POST /api/v2/driver/routes/{route_id}/start`.
  Future<Either<Failure, RouteModel?>> startRoute({required int routeId});

  /// `POST /api/v2/driver/routes/{route_id}/complete`.
  Future<Either<Failure, RouteModel?>> completeRoute({required int routeId});

  /// `GET /api/v2/driver/history?page=`.
  Future<Either<Failure, RouteHistoryPage>> getHistory({int page = 1});

  /// `GET /api/v2/driver/end_of_day_summary?date=`.
  Future<Either<Failure, EndOfDaySummaryModel>> getEndOfDaySummary({String? date});

  /// `POST /api/v2/driver/stops/{stop_id}/en_route`.
  Future<Either<Failure, RouteStop>> markStopEnRoute({required RouteStop stop});

  /// `POST /api/v2/driver/stops/{stop_id}/arrive`.
  Future<Either<Failure, ArrivalResult>> arriveAtStop({
    required RouteStop stop,
    double? latitude,
    double? longitude,
    String? notes,
  });

  /// `POST /api/v2/driver/stops/{stop_id}/pickup`.
  Future<Either<Failure, RouteStop>> confirmPickup({required RouteStop stop, required PickupRequest request});

  /// `POST /api/v2/driver/stops/{stop_id}/deliver`.
  Future<Either<Failure, RouteStop>> confirmDelivery({required RouteStop stop, required DeliveryRequest request});

  /// `POST /api/v2/driver/stops/{stop_id}/return` — closes a `return_to_base`
  /// stop; `pickup` and `deliver` both reject that stop type.
  Future<Either<Failure, RouteStop>> confirmReturn({required RouteStop stop, required ReturnRequest request});

  /// `POST /api/v2/driver/stops/{stop_id}/skip`. [reason] is free text of at
  /// most 200 characters and is forwarded to the trader and the supplier.
  Future<Either<Failure, RouteStop>> skipStop({required RouteStop stop, String? reason});

  /// `GET /api/v2/driver/stops/{stop_id}/receipt_status`.
  Future<Either<Failure, ReceiptStatusModel>> getReceiptStatus({required int stopId});

  /// `POST /api/v2/driver/stops/{stop_id}/otp/resend`.
  Future<Either<Failure, OtpResult>> resendOtp({required int stopId});

  /// `POST /api/v2/driver/stops/{stop_id}/otp/verify`.
  Future<Either<Failure, OtpResult>> verifyOtp({required int stopId, required String otpCode});

  /// `POST /api/v2/driver/stops/{stop_id}/handoff/verify` with either the
  /// scanned trader QR ([handoffQr]) or the typed 6-digit [otpCode]. A wrong
  /// QR / code is a `Right` with `success == false`.
  Future<Either<Failure, OtpResult>> verifyHandoff({required int stopId, String? handoffQr, String? otpCode});

  /// `POST /api/v2/driver/stops/{stop_id}/barcode/verify` — a mismatch is a
  /// `Right` with `success == false`, never a failure.
  Future<Either<Failure, BarcodeResult>> verifyBarcode({required int stopId, required String barcode});

  /// `POST /api/v2/driver/stops/{stop_id}/seals` with `mode` pickup/delivery.
  Future<Either<Failure, SealResult>> submitSeals({
    required int stopId,
    required List<String> seals,
    required bool isDelivery,
  });

  /// `POST /api/v2/driver/stops/{stop_id}/partial_reject`.
  Future<Either<Failure, StopItemModel?>> partialReject({
    required int stopId,
    required int itemId,
    required double rejectedQty,
    required String reason,
    String? notes,
  });

  /// `POST /api/v2/driver/uploads` (multipart).
  Future<Either<Failure, UploadResult>> uploadAttachment({required File file, String module = "proof"});

  /// `POST /api/v2/driver/stops/{stop_id}/proof` — multipart with the picture
  /// when the request carries a file, JSON with `file_path` otherwise.
  Future<Either<Failure, ProofModel?>> attachProof({required int stopId, required ProofRequest request});

  /// `GET /api/v2/driver/live` — Firebase live tracking session. `409
  /// no_active_route` and an unconfigured server both come back as
  /// [LiveSessionModel.disabled].
  Future<Either<Failure, LiveSessionModel>> getLiveSession();

  /// `POST /api/v2/driver/location` — batch form.
  Future<Either<Failure, int>> sendLocations({required List<LocationPoint> points});

  /// `POST /api/v2/driver/sync/batch`.
  Future<Either<Failure, List<SyncResult>>> syncBatch({required List<SyncEvent> events});
}
