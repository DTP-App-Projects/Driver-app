import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/location_service.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/directions_service.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';

part 'delivery_tracking_state.dart';

/// Runs a delivery: follows the driver position, keeps the road path through
/// the stops that are left up to date, and moves stops forward as they are
/// delivered.
class DeliveryTrackingCubit extends Cubit<DeliveryTrackingState> {
  DeliveryTrackingCubit({
    required this.route,
    LocationService? locationService,
    DirectionsService? directionsService,
  }) : locationService = locationService ?? const LocationService(),
       directionsService = directionsService ?? DirectionsService(),
       super(DeliveryTrackingState(stops: [...route.stops]));

  final RouteModel route;
  final LocationService locationService;
  final DirectionsService directionsService;

  /// Metres the driver has to move before the road path is asked for again,
  /// so a delivery does not burn quota while parked at a stop.
  static const double refreshDistance = 60;

  StreamSubscription<Position>? _positionSubscription;
  Position? _directionsOrigin;
  bool _isLoadingDirections = false;
  int _token = 0;

  /// Language the road path is requested in, kept in step with the app.
  String languageCode = "en";

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    return super.close();
  }

  int get _nextToken => ++_token;

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
      stops: [for (final stop in remaining) LatLng(stop.latitude, stop.longitude)],
      languageCode: languageCode,
    );
    _isLoadingDirections = false;
    if (isClosed) return;

    _directionsOrigin = position;
    emit(state.copyWith(directions: result, directionsFailed: result == null, clearDirections: result == null));
  }

  /// Pending -> arrived -> completed, one tap at a time. Works on any stop so
  /// the driver can deliver out of order straight from the map.
  ///
  /// [arrivedText] and [completedText] are the already translated toasts, so
  /// the cubit stays out of the widget tree.
  void advanceStop(int index, {required String arrivedText, required String completedText}) {
    final stop = state.stops[index];
    if (stop.status == StopStatus.completed) return;

    final next = stop.status == StopStatus.pending ? StopStatus.arrived : StopStatus.completed;
    final stops = [...state.stops]..[index] = stop.copyWith(status: next);
    final isCompleted = next == StopStatus.completed;

    // Completing a stop moves the driver on, so frame the next one unless the
    // camera is already riding along with the driver.
    final nextStop = stops.where((item) => item.status != StopStatus.completed).firstOrNull;
    final shouldFrameNext = isCompleted && nextStop != null && !state.followDriver;

    emit(
      state.copyWith(
        stops: stops,
        message: DeliveryMessage(token: _nextToken, text: isCompleted ? completedText : arrivedText),
        camera: shouldFrameNext
            ? CameraCommand(token: _nextToken, target: LatLng(nextStop.latitude, nextStop.longitude), zoom: 14)
            : null,
      ),
    );

    // The remaining path changed, so redraw it from where the driver is.
    if (isCompleted) refreshDirections(force: true);
  }

  /// Rides along with the driver again, centring on the latest fix.
  void centerOnDriver({required String unavailableText}) {
    final position = state.driverPosition;

    if (position == null) {
      emit(state.copyWith(message: DeliveryMessage(token: _nextToken, text: unavailableText, isError: true)));
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
    emit(
      state.copyWith(
        followDriver: false,
        camera: CameraCommand(token: _nextToken, target: LatLng(stop.latitude, stop.longitude)),
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
}
