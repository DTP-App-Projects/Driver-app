import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:digital_trade_portal_driver/core/errors/api_error_messages.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/location_service.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/offline_queue.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/directions_service.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/tr_or.dart';
import 'package:digital_trade_portal_driver/core/utils/uuid.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/stop_execution_models.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/sync_event.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/today_route/today_route_cubit.dart';

part 'delivery_tracking_state.dart';

/// Runs a delivery: follows the driver position, keeps the road path through
/// the stops that are left up to date, and moves stops through the server
/// state machine (`en_route → arrived → completed | skipped`), queueing the
/// action offline when the network is gone. Every change is pushed back to
/// [todayRouteCubit] so the home and details screens stay in step.
class DeliveryTrackingCubit extends Cubit<DeliveryTrackingState> {
  DeliveryTrackingCubit({
    required RouteModel route,
    required this.routesRepo,
    required this.todayRouteCubit,
    required this.offlineQueue,
    this.driverName,
    LocationService? locationService,
    DirectionsService? directionsService,
  }) : locationService = locationService ?? const LocationService(),
       directionsService = directionsService ?? DirectionsService(),
       super(
         DeliveryTrackingState(
           route: route,
           pendingSyncStopIds: {
             for (final stop in route.stops)
               if (offlineQueue.hasPendingForStop(stop.id)) stop.id,
           },
         ),
       ) {
    // A background flush (location tick, app resume) clears the badges here.
    _queueSubscription = offlineQueue.changes.listen((_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          pendingSyncStopIds: {
            for (final stop in state.stops)
              if (offlineQueue.hasPendingForStop(stop.id)) stop.id,
          },
        ),
      );
    });

    // A queued pickup / delivery the server refused for a reason only the
    // driver can fix: say which stop and why, then reload so it reopens.
    _rejectionSubscription = offlineQueue.rejections.listen((rejection) {
      if (isClosed) return;
      final stop = rejection.stopId == null ? null : state.stopById(rejection.stopId!);
      if (stop == null) return;
      emit(
        state.copyWith(
          message: _error(
            tr("sync_stop_rejected", namedArgs: {"stop": stop.name, "reason": syncResultText(rejection.result)}),
          ),
        ),
      );
      todayRouteCubit.loadTodayRoute(silent: true);
    });

    // The supplier can change the route under the driver (shipment canceled,
    // stop rescheduled, route canceled): every payload fetched from the server
    // replaces the local copy.
    _revision = todayRouteCubit.state.revision;
    _todayRouteSubscription = todayRouteCubit.stream.listen((todayState) {
      if (isClosed || todayState.revision == _revision) return;
      _revision = todayState.revision;
      _adoptServerRoute(todayState.data);
    });
  }

  final RoutesRepo routesRepo;
  final TodayRouteCubit todayRouteCubit;
  final OfflineQueue offlineQueue;
  final LocationService locationService;
  final DirectionsService directionsService;

  /// Stamped into photo watermarks.
  final String? driverName;

  /// Metres the driver has to move before the road path is asked for again,
  /// so a delivery does not burn quota while parked at a stop.
  static const double refreshDistance = 60;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<SyncEvent>>? _queueSubscription;
  StreamSubscription<SyncRejection>? _rejectionSubscription;
  StreamSubscription<TodayRouteState>? _todayRouteSubscription;
  int _revision = 0;
  Position? _directionsOrigin;
  bool _isLoadingDirections = false;
  int _token = 0;

  /// Language the road path is requested in, kept in step with the app.
  String languageCode = "en";

  RouteModel get route => state.route;

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    _queueSubscription?.cancel();
    _rejectionSubscription?.cancel();
    _todayRouteSubscription?.cancel();
    return super.close();
  }

  int get _nextToken => ++_token;

  // ------------------------------------------------------- server refresh

  /// Takes the route as the server last sent it. Stops whose action is still
  /// waiting in the offline queue keep their optimistic status, since the
  /// server has not seen that action yet. A route that vanished from the
  /// payload was closed by the server: `completed` when at least one stop
  /// was completed, `canceled` otherwise. Either way the delivery is over.
  Future<void> _adoptServerRoute(TodayRouteModel? data) async {
    if (data == null || state.isRouteClosed) return;
    final fresh = data.routeById(route.id);

    if (fresh == null || fresh.status == RouteStatus.cancelled || fresh.status == RouteStatus.completed) {
      final bool anyCompleted = (fresh ?? route).stops.any((stop) => stop.status == StopStatus.completed);
      final status = fresh?.status == RouteStatus.cancelled || (fresh == null && !anyCompleted)
          ? RouteStatus.cancelled
          : RouteStatus.completed;
      emit(state.copyWith(route: (fresh ?? route).copyWith(status: status), clearBusy: true, clearDirections: true));

      if (status == RouteStatus.completed) {
        await todayRouteCubit.loadEndOfDaySummary();
        if (!isClosed) emit(state.copyWith(summary: todayRouteCubit.state.summary));
      }
      return;
    }

    final stops = [
      for (final stop in fresh.stops)
        if (state.isPendingSync(stop.id)) state.stopById(stop.id) ?? stop else _keepLocalScans(stop),
    ];
    final bool stopsChanged =
        stops.length != state.stops.length ||
        [for (final stop in stops) "${stop.id}:${stop.status.apiValue}"].join(",") !=
            [for (final stop in state.stops) "${stop.id}:${stop.status.apiValue}"].join(",");

    emit(state.copyWith(route: fresh.copyWith(stops: stops)));
    if (stopsChanged) refreshDirections(force: true);
  }

  /// `barcode/verify` matches live on the server but the stop payload may
  /// not show them before the pickup / delivery is confirmed; keep the ones
  /// already made on this device so a refresh does not un-verify a line.
  RouteStop _keepLocalScans(RouteStop fresh) {
    final local = state.stopById(fresh.id);
    if (local == null || fresh.status.isClosed) return fresh;
    final scanned = {
      for (final item in local.items)
        if (item.barcodeMatch) item.id: item,
    };
    if (scanned.isEmpty) return fresh;
    return fresh.copyWith(
      items: [
        for (final item in fresh.items)
          if (!item.barcodeMatch && scanned.containsKey(item.id))
            item.copyWith(barcodeScanned: true, barcodeMatch: true, barcodeValue: scanned[item.id]!.barcodeValue)
          else
            item,
      ],
    );
  }

  // ---------------------------------------------------------------- tracking

  Future<void> startTracking() async {
    final failure = await locationService.ensurePermission();
    if (isClosed) return;

    emit(state.copyWith(locationFailure: failure, clearLocationFailure: failure == null));
    if (failure != null) return;

    final position = await locationService.currentPosition();
    if (isClosed) return;
    if (position != null) {
      _onPosition(position);
      await refreshDirections(force: true);
    }

    await _positionSubscription?.cancel();
    _positionSubscription = locationService.positionStream().listen(
      _onPosition,
      // A dropped fix is not fatal: the stops stay on the map.
      onError: (_) {},
    );
  }

  void _onPosition(Position position) {
    if (isClosed) return;

    emit(
      state.copyWith(
        driverPosition: position,
        camera: state.followDriver
            ? CameraCommand(token: _nextToken, target: LatLng(position.latitude, position.longitude))
            : null,
      ),
    );

    refreshDirections();
  }

  /// Rebuilds the road path from where the driver is now through the stops
  /// that are left. [force] skips the moved-far-enough check, for when the
  /// stop list itself changed.
  Future<void> refreshDirections({bool force = false}) async {
    final position = state.driverPosition;
    final remaining = state.remainingStops;

    if (position == null || remaining.isEmpty) {
      if (state.directions != null) emit(state.copyWith(clearDirections: true));
      return;
    }

    if (_isLoadingDirections) return;

    final origin = _directionsOrigin;
    if (!force && origin != null) {
      final moved = locationService.distanceInMeters(
        startLatitude: origin.latitude,
        startLongitude: origin.longitude,
        endLatitude: position.latitude,
        endLongitude: position.longitude,
      );
      if (moved < refreshDistance) return;
    }

    _isLoadingDirections = true;
    final result = await directionsService.route(
      origin: LatLng(position.latitude, position.longitude),
      stops: [for (final stop in remaining) LatLng(stop.latitude!, stop.longitude!)],
      languageCode: languageCode,
    );
    _isLoadingDirections = false;
    if (isClosed) return;

    _directionsOrigin = position;
    emit(state.copyWith(directions: result, directionsFailed: result == null, clearDirections: result == null));
  }

  // ------------------------------------------------------------ stop actions

  /// `pending → en_route`.
  Future<bool> markEnRoute(RouteStop stop) async {
    if (!_begin(stop)) return false;

    final result = await routesRepo.markStopEnRoute(stop: stop);
    if (isClosed) return false;

    return result.fold((failure) => _fail(failure), (updated) {
      _applyStop(updated, text: tr("api_stop_en_route"));
      return true;
    });
  }

  /// `→ arrived`, with the device position for the geofence check. For a
  /// delivery stop the response carries the receiver OTP dispatch details,
  /// kept in [DeliveryTrackingState.arrivals] for the delivery sheet.
  Future<bool> arrive(RouteStop stop) async {
    if (!_begin(stop)) return false;

    final position = state.driverPosition ?? await locationService.currentPosition();
    if (isClosed) return false;

    final result = await routesRepo.arriveAtStop(
      stop: stop,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
    if (isClosed) return false;

    return result.fold(
      (failure) {
        if (failure.isNetwork) {
          _queue(stop, SyncActionType.arrive, {
            "stop_id": stop.id,
            if (position != null) "latitude": position.latitude,
            if (position != null) "longitude": position.longitude,
          }, optimistic: stop.copyWith(status: StopStatus.arrived));
          return true;
        }
        return _fail(failure);
      },
      (arrival) {
        final arrivals = Map<int, ArrivalResult>.of(state.arrivals)..[stop.id] = arrival;
        emit(state.copyWith(arrivals: arrivals));
        _applyStop(arrival.stop, text: tr("arrived_at_stop", namedArgs: {"stop": stop.name}));
        if (arrival.otpError != null) {
          emit(state.copyWith(message: _error(tr("otp_sms_failed"))));
        }
        return true;
      },
    );
  }

  /// `arrived → completed` for a pickup stop.
  Future<Either<Failure, RouteStop>> confirmPickup(RouteStop stop, PickupRequest request) async {
    if (!_begin(stop)) return left(_busyFailure());

    final position = state.driverPosition;
    final body = PickupRequest(
      items: request.items,
      sealNumbers: request.sealNumbers,
      temperature: request.temperature,
      departureLatitude: request.departureLatitude ?? position?.latitude,
      departureLongitude: request.departureLongitude ?? position?.longitude,
    );

    final result = await routesRepo.confirmPickup(stop: stop, request: body);
    if (isClosed) return left(_busyFailure());

    return result.fold(
      (failure) {
        if (failure.isNetwork) {
          final optimistic = stop.copyWith(status: StopStatus.completed);
          _queue(stop, SyncActionType.pickup, {"stop_id": stop.id, ...body.toJson()}, optimistic: optimistic);
          return right(optimistic);
        }
        _fail(failure, silent: true);
        // Canceled or closed since the route was loaded: show the route as
        // the server has it now.
        if (failure.reason == "shipment_not_ready_for_pickup") todayRouteCubit.loadTodayRoute(silent: true);
        return left(failure);
      },
      (updated) {
        offlineQueue.clearRejection(stop.id);
        _applyStop(updated, text: tr("api_pickup_confirmed"));
        return right(updated);
      },
    );
  }

  /// `arrived → completed` for a delivery stop. Quantities are checked
  /// locally first; the server stays the final judge.
  Future<Either<Failure, RouteStop>> confirmDelivery(RouteStop stop, DeliveryRequest request) async {
    final unbalanced = request.unbalancedItems;
    if (unbalanced.isNotEmpty) {
      return left(
        CustomError(tr("quantity_balance_hint"), kind: FailureKind.validation, code: "quantity_balance_failed"),
      );
    }

    if (!_begin(stop)) return left(_busyFailure());

    final result = await routesRepo.confirmDelivery(stop: stop, request: request);
    if (isClosed) return left(_busyFailure());

    return result.fold(
      (failure) {
        if (failure.isNetwork) {
          // A QR / code captured offline travels in the payload and is
          // checked by the server at sync time.
          final optimistic = stop.copyWith(status: StopStatus.completed);
          _queue(stop, SyncActionType.deliver, {"stop_id": stop.id, ...request.toJson()}, optimistic: optimistic);
          return right(optimistic);
        }
        final shown = _deliveryFailure(stop, failure);
        _fail(shown, silent: true);
        return left(shown);
      },
      (updated) {
        offlineQueue.clearRejection(stop.id);
        _applyStop(updated, text: tr("api_delivery_confirmed"));
        if (updated.hasDeliveryNote) loadReceiptStatus(updated.id);
        return right(updated);
      },
    );
  }

  /// A refused `/deliver` that is about the handoff resets the handoff step:
  /// the server did not accept what the sheet thought was verified or
  /// captured. `otp_verification_failed` carries `handoff: {msg,
  /// attempts_remaining}`, which reads better than the generic reason.
  Failure _deliveryFailure(RouteStop stop, Failure failure) {
    final reason = failure.reason;
    if (reason != "otp_verification_failed" && reason != "handoff_verification_required") return failure;

    final handoffJson = JsonUtils.asMapOrNull(failure.body["handoff"]);
    final handoff = handoffJson == null ? null : OtpResult.fromJson(handoffJson);
    emit(
      state.copyWith(
        otpVerifiedStopIds: {...state.otpVerifiedStopIds}..remove(stop.id),
        handoffCaptures: Map<int, HandoffCapture>.of(state.handoffCaptures)..remove(stop.id),
        otpResults: handoff == null ? null : (Map<int, OtpResult>.of(state.otpResults)..[stop.id] = handoff),
      ),
    );
    if (handoff == null) return failure;
    return ServerFailure(
      handoffFailureText(handoff),
      kind: failure.kind,
      code: failure.code,
      statusCode: failure.statusCode,
      body: failure.body,
    );
  }

  /// `arrived → completed` for a `return_to_base` stop: the goods of a
  /// canceled shipment were handed back at the supplier warehouse.
  Future<Either<Failure, RouteStop>> confirmReturn(RouteStop stop, ReturnRequest request) async {
    if (!_begin(stop)) return left(_busyFailure());

    final position = state.driverPosition;
    final body = ReturnRequest(
      latitude: request.latitude ?? position?.latitude,
      longitude: request.longitude ?? position?.longitude,
      notes: request.notes,
    );

    final result = await routesRepo.confirmReturn(stop: stop, request: body);
    if (isClosed) return left(_busyFailure());

    return result.fold(
      (failure) {
        if (failure.isNetwork) {
          final optimistic = stop.copyWith(status: StopStatus.completed);
          _queue(stop, SyncActionType.returnToBase, {"stop_id": stop.id, ...body.toJson()}, optimistic: optimistic);
          return right(optimistic);
        }
        _fail(failure, silent: true);
        return left(failure);
      },
      (updated) {
        _applyStop(updated, text: tr("api_stop_returned"));
        return right(updated);
      },
    );
  }

  /// `→ skipped` with the reason typed or picked in the sheet (forwarded to
  /// the trader and the supplier, at most 200 characters).
  Future<bool> skip(RouteStop stop, {required String reason}) async {
    if (!_begin(stop)) return false;

    final result = await routesRepo.skipStop(stop: stop, reason: reason);
    if (isClosed) return false;

    return result.fold(
      (failure) {
        if (failure.isNetwork) {
          _queue(stop, SyncActionType.skip, {
            "stop_id": stop.id,
            "reason": reason,
          }, optimistic: stop.copyWith(status: StopStatus.skipped));
          return true;
        }
        return _fail(failure);
      },
      (updated) {
        _applyStop(updated, text: tr("api_stop_skipped"));
        return true;
      },
    );
  }

  // ----------------------------------------------------------------- handoff

  /// Proves the goods reach the right trader: the trader's QR
  /// ([handoffQr], `TJD1:<stop>:<code>`) or the 6-digit [otpCode] through
  /// `handoff/verify`. A QR that is not a handoff QR, or is for another stop,
  /// is refused here without a round trip. Offline, the QR / code is kept in
  /// [DeliveryTrackingState.handoffCaptures] and sent with `/deliver` so the
  /// server checks it at sync time; the returned failure is then a network one.
  Future<Either<Failure, OtpResult>> verifyHandoff(RouteStop stop, {String? handoffQr, String? otpCode}) async {
    final qr = handoffQr?.trim();
    final code = otpCode?.trim();
    if (qr != null) {
      final parsed = HandoffQr.tryParse(qr);
      final local = parsed == null
          ? const OtpResult(success: false, msg: "invalid_handoff_qr")
          : parsed.stopId != stop.id
          ? const OtpResult(success: false, msg: "handoff_qr_for_another_stop")
          : null;
      if (local != null) {
        _storeOtp(stop.id, local);
        return right(local);
      }
    }

    final result = await routesRepo.verifyHandoff(stopId: stop.id, handoffQr: qr, otpCode: code);
    if (isClosed) return result;
    result.fold(
      (failure) {
        if (!failure.isNetwork) return;
        emit(
          state.copyWith(
            handoffCaptures: Map<int, HandoffCapture>.of(state.handoffCaptures)
              ..[stop.id] = HandoffCapture(handoffQr: qr, otpCode: code),
          ),
        );
      },
      (otp) {
        _storeOtp(stop.id, otp);
        if (otp.success) {
          emit(
            state.copyWith(
              otpVerifiedStopIds: {...state.otpVerifiedStopIds, stop.id},
              handoffCaptures: Map<int, HandoffCapture>.of(state.handoffCaptures)..remove(stop.id),
            ),
          );
        }
      },
    );
    return result;
  }

  /// Drops a QR / code captured offline, e.g. before scanning again.
  void clearHandoffCapture(RouteStop stop) {
    if (!state.handoffCaptures.containsKey(stop.id)) return;
    emit(state.copyWith(handoffCaptures: Map<int, HandoffCapture>.of(state.handoffCaptures)..remove(stop.id)));
  }

  // --------------------------------------------------------------------- OTP

  Future<Either<Failure, OtpResult>> resendOtp(RouteStop stop) async {
    final result = await routesRepo.resendOtp(stopId: stop.id);
    if (isClosed) return result;
    result.fold((_) {}, (otp) => _storeOtp(stop.id, otp));
    return result;
  }

  Future<Either<Failure, OtpResult>> verifyOtp(RouteStop stop, String code) async {
    final result = await routesRepo.verifyOtp(stopId: stop.id, otpCode: code);
    if (isClosed) return result;
    result.fold((_) {}, (otp) {
      _storeOtp(stop.id, otp);
      if (otp.success) emit(state.copyWith(otpVerifiedStopIds: {...state.otpVerifiedStopIds, stop.id}));
    });
    return result;
  }

  void _storeOtp(int stopId, OtpResult otp) {
    emit(state.copyWith(otpResults: Map<int, OtpResult>.of(state.otpResults)..[stopId] = otp));
  }

  // ------------------------------------------------------- barcode & seals

  /// A match flags the line locally as scanned; a mismatch comes back as a
  /// `Right` with `success == false` (the API answers 200 for both).
  ///
  /// Offline, a code equal to a line's product barcode is accepted locally:
  /// it goes out as that line's `barcode_value`, which the server checks the
  /// same way when the pickup / delivery syncs.
  Future<Either<Failure, BarcodeResult>> verifyBarcode(RouteStop stop, String barcode) async {
    final code = barcode.trim();
    var result = await routesRepo.verifyBarcode(stopId: stop.id, barcode: code);
    if (isClosed) return result;

    if (result.fold((failure) => failure.isNetwork, (_) => false)) {
      final current = state.stopById(stop.id) ?? stop;
      final match = current.items.where((item) => item.barcode == code).firstOrNull;
      if (match != null) result = right(BarcodeResult(success: true, itemId: match.id, barcode: code));
    }

    result.fold((_) {}, (barcodeResult) {
      if (!barcodeResult.success) return;
      final itemId = barcodeResult.itemId;
      final current = state.stopById(stop.id) ?? stop;
      final items = [
        for (final item in current.items)
          if (item.id == itemId || (itemId == null && item.barcode == code))
            item.copyWith(barcodeScanned: true, barcodeMatch: true, barcodeValue: code)
          else
            item,
      ];
      _applyStop(current.copyWith(items: items));
    });
    return result;
  }

  Future<Either<Failure, SealResult>> submitSeals(RouteStop stop, List<String> seals, {required bool isDelivery}) {
    return routesRepo.submitSeals(stopId: stop.id, seals: seals, isDelivery: isDelivery);
  }

  /// Records a receiver's partial refusal of one line and mirrors the new
  /// returned / delivered split locally.
  Future<Either<Failure, StopItemModel?>> partialReject(
    RouteStop stop, {
    required StopItemModel item,
    required double rejectedQty,
    required String reason,
    String? notes,
  }) async {
    final result = await routesRepo.partialReject(
      stopId: stop.id,
      itemId: item.id,
      rejectedQty: rejectedQty,
      reason: reason,
      notes: notes,
    );
    if (isClosed) return result;

    result.fold((_) {}, (serverItem) {
      final current = state.stopById(stop.id) ?? stop;
      final returned = (item.returnedQty ?? 0) + rejectedQty;
      final updated =
          serverItem ??
          item.copyWith(
            returnedQty: returned,
            deliveredQty: item.deliverableQty - returned - (item.damagedQty ?? 0),
            conditionNotes: [item.conditionNotes, reason].where((part) => part != null && part.isNotEmpty).join("; "),
          );
      _applyStop(current.copyWith(items: [for (final line in current.items) line.id == item.id ? updated : line]));
    });
    return result;
  }

  // ------------------------------------------------------------------ proofs

  /// One multipart call: the picture goes straight to the proof endpoint,
  /// typed and watermarked. Photo proofs carry `watermark_data` (text plus
  /// GPS and time); without it the server would answer `watermark_required`.
  Future<Either<Failure, ProofModel?>> uploadProof(
    RouteStop stop, {
    required File file,
    required ProofType proofType,
    required ProofCategory proofCategory,
    String? signerName,
    String? signerRole,
    String? notes,
  }) async {
    final position = state.driverPosition;
    final now = DateTime.now();

    final request = ProofRequest(
      proofType: proofType,
      proofCategory: proofCategory,
      file: file,
      clientUuid: Uuid.v4(),
      latitude: position?.latitude,
      longitude: position?.longitude,
      capturedAt: now,
      watermarkData: proofType.requiresWatermark
          ? {
              "text": [
                if (driverName != null && driverName!.isNotEmpty) driverName!,
                route.code,
                stop.name,
                JsonUtils.formatServerDateTime(now),
              ].join(" • "),
              if (position != null) "latitude": position.latitude,
              if (position != null) "longitude": position.longitude,
              "captured_at": JsonUtils.formatServerDateTime(now),
            }
          : null,
      signerName: signerName,
      signerRole: signerRole,
      notes: notes,
    );

    final attached = await routesRepo.attachProof(stopId: stop.id, request: request);
    if (isClosed) return attached;

    attached.fold((_) {}, (proof) {
      final current = state.stopById(stop.id) ?? stop;
      _applyStop(
        current.copyWith(
          proofs: [
            ...current.proofs,
            proof ?? ProofModel(id: 0, proofType: proofType.apiValue, capturedAt: now),
          ],
        ),
      );
    });
    return attached;
  }

  // ---------------------------------------------------------------- receipt

  Future<void> loadReceiptStatus(int stopId) async {
    final result = await routesRepo.getReceiptStatus(stopId: stopId);
    if (isClosed) return;
    result.fold((_) {}, (status) {
      emit(state.copyWith(receiptStatuses: Map<int, ReceiptStatusModel>.of(state.receiptStatuses)..[stopId] = status));
    });
  }

  // ------------------------------------------------------------------ route

  /// `in_progress → completed` through the shared cubit, then the end of day
  /// summary for the closing card.
  Future<bool> completeRoute() async {
    if (state.isCompletingRoute || state.isRouteClosed) return false;
    emit(state.copyWith(isCompletingRoute: true));

    final completed = await todayRouteCubit.completeRoute(route);
    if (isClosed) return false;

    if (!completed) {
      final message = todayRouteCubit.state.message;
      emit(
        state.copyWith(
          isCompletingRoute: false,
          message: message == null ? null : DeliveryMessage(token: _nextToken, text: message.text, isError: true),
        ),
      );
      return false;
    }

    emit(
      state.copyWith(
        isCompletingRoute: false,
        route: route.copyWith(status: RouteStatus.completed),
        summary: todayRouteCubit.state.summary,
        message: DeliveryMessage(token: _nextToken, text: tr("delivery_finished")),
      ),
    );
    return true;
  }

  /// Replays queued actions (offline arrive / pickup / deliver / skip) and
  /// refreshes the statuses from the server once they went through.
  Future<void> retrySync() async {
    final results = await offlineQueue.flush();
    if (isClosed) return;

    emit(
      state.copyWith(
        pendingSyncStopIds: {
          for (final stop in state.stops)
            if (offlineQueue.hasPendingForStop(stop.id)) stop.id,
        },
      ),
    );

    if (results == null) {
      emit(state.copyWith(message: _error(tr("sync_still_offline"))));
      return;
    }

    // Refusals the driver has to fix left the queue and were announced per
    // stop by the rejection listener; the rest stay queued for a retry.
    final failed = results.where((result) => result.isFailed).toList();
    final stillQueued = failed.where((result) => offlineQueue.events.any((e) => e.clientUuid == result.clientUuid));
    if (stillQueued.isNotEmpty) {
      emit(state.copyWith(message: _error(syncResultText(stillQueued.first))));
    } else if (failed.isEmpty) {
      emit(
        state.copyWith(
          message: DeliveryMessage(token: _nextToken, text: tr("sync_done")),
        ),
      );
    }

    // The refreshed payload is folded in by the revision listener.
    await todayRouteCubit.loadTodayRoute(silent: true);
  }

  // ----------------------------------------------------------------- camera

  /// Rides along with the driver again, centring on the latest fix.
  void centerOnDriver({required String unavailableText}) {
    final position = state.driverPosition;

    if (position == null) {
      emit(state.copyWith(message: _error(unavailableText)));
      return;
    }

    emit(
      state.copyWith(
        followDriver: true,
        camera: CameraCommand(token: _nextToken, target: LatLng(position.latitude, position.longitude)),
      ),
    );
  }

  /// Frames the whole route, the driver included, and stops following.
  void fitRoute() {
    emit(state.copyWith(followDriver: false, camera: CameraCommand(token: _nextToken, fitRoute: true)));
  }

  void focusStop(RouteStop stop) {
    if (!stop.hasLocation) return;
    emit(
      state.copyWith(
        followDriver: false,
        camera: CameraCommand(token: _nextToken, target: LatLng(stop.latitude!, stop.longitude!)),
      ),
    );
  }

  void setMapExpanded(bool value) => emit(state.copyWith(isMapExpanded: value));

  /// Sends the driver to the settings screen that fixes the exact failure,
  /// then tries to start tracking again.
  Future<void> resolveLocationFailure() async {
    switch (state.locationFailure) {
      case LocationFailure.serviceDisabled:
        await locationService.openLocationSettings();
      case LocationFailure.deniedForever:
        await locationService.openSettings();
      case _:
        break;
    }

    await startTracking();
  }

  // ---------------------------------------------------------------- helpers

  /// Marks [stop] busy; false when another request is already running.
  bool _begin(RouteStop stop) {
    if (state.busyStopId != null) return false;
    emit(state.copyWith(busyStopId: stop.id));
    return true;
  }

  bool _fail(Failure failure, {bool silent = false}) {
    emit(state.copyWith(clearBusy: true, message: silent ? null : _error(failure.errMessage)));
    return false;
  }

  Failure _busyFailure() => CustomError(tr("action_in_progress"), kind: FailureKind.unknown, code: "busy");

  /// Writes the stop into the local route, mirrors it to the shared cubit
  /// and re-frames the map when the stop just closed.
  void _applyStop(RouteStop updated, {String? text}) {
    final stops = [for (final stop in state.stops) stop.id == updated.id ? updated : stop];
    final wasClosed = state.stopById(updated.id)?.status.isClosed ?? false;
    final justClosed = updated.status.isClosed && !wasClosed;

    // Closing a stop moves the driver on, so frame the next one unless the
    // camera is already riding along with the driver.
    final nextStop = stops.where((item) => !item.status.isClosed && item.hasLocation).firstOrNull;
    final shouldFrameNext = justClosed && nextStop != null && !state.followDriver;

    emit(
      state.copyWith(
        route: state.route.copyWith(stops: stops),
        clearBusy: true,
        message: text == null ? null : DeliveryMessage(token: _nextToken, text: text),
        camera: shouldFrameNext
            ? CameraCommand(token: _nextToken, target: LatLng(nextStop.latitude!, nextStop.longitude!), zoom: 14)
            : null,
      ),
    );

    todayRouteCubit.applyStop(updated);

    // The remaining path changed, so redraw it from where the driver is.
    if (justClosed) refreshDirections(force: true);
  }

  /// Offline path: persist the action with its client UUID, apply the
  /// optimistic status and flag the stop as pending sync.
  void _queue(RouteStop stop, SyncActionType type, Map<String, dynamic> payload, {required RouteStop optimistic}) {
    offlineQueue.enqueue(SyncEvent(actionType: type, payload: payload));
    emit(state.copyWith(pendingSyncStopIds: {...state.pendingSyncStopIds, stop.id}));
    _applyStop(optimistic, text: tr("action_queued_offline"));
  }

  DeliveryMessage _error(String text) => DeliveryMessage(token: _nextToken, text: text, isError: true);
}

/// Driver facing text for a refused handoff (`handoff/verify`, `otp/verify`
/// or the `handoff` object of a refused `/deliver`).
String handoffFailureText(OtpResult outcome) {
  if (outcome.isInvalidCode) {
    final left = outcome.attemptsRemaining;
    return left == null ? tr("api_invalid_code") : tr("handoff_invalid_code_attempts", namedArgs: {"count": "$left"});
  }
  if (outcome.needsNewCode) return tr("handoff_code_expired");
  return trOr("api_${outcome.msg}", tr("api_invalid_code"));
}

/// Driver facing text for one failed event of `sync/batch`, never the raw code.
String syncResultText(SyncResult result) {
  final error = result.error ?? result.reason;
  if (error == null || error.isEmpty) return tr("sync_failed");
  return ApiErrorMessages.forCode(result.errorCode, serverMessage: error);
}
