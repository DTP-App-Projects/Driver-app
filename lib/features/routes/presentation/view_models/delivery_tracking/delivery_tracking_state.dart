part of 'delivery_tracking_cubit.dart';

/// A camera move the map runs once. [token] tells the map whether it has
/// already handled this request, so a rebuild does not replay it.
class CameraCommand {
  const CameraCommand({required this.token, this.target, this.zoom = 15, this.fitRoute = false});

  final int token;
  final LatLng? target;
  final double zoom;
  final bool fitRoute;
}

/// A one off message for the driver, shown as a toast. Carries a token for the
/// same reason as [CameraCommand].
class DeliveryMessage {
  const DeliveryMessage({required this.token, required this.text, this.isError = false});

  final int token;
  final String text;
  final bool isError;
}

/// A trader QR or code the driver captured while offline. It cannot be
/// checked live, so it rides along with `/deliver` (or its queued event) and
/// the server verifies it at sync time.
class HandoffCapture {
  const HandoffCapture({this.handoffQr, this.otpCode});

  final String? handoffQr;
  final String? otpCode;
}

class DeliveryTrackingState {
  const DeliveryTrackingState({
    required this.route,
    this.driverPosition,
    this.locationFailure,
    this.directions,
    this.directionsFailed = false,
    this.followDriver = true,
    this.isMapExpanded = false,
    this.camera,
    this.message,
    this.busyStopId,
    this.isCompletingRoute = false,
    this.arrivals = const {},
    this.otpResults = const {},
    this.otpVerifiedStopIds = const {},
    this.handoffCaptures = const {},
    this.pendingSyncStopIds = const {},
    this.receiptStatuses = const {},
    this.summary,
  });

  /// Live copy of the route: status plus every stop as the server last
  /// reported it (or as queued offline).
  final RouteModel route;
  final Position? driverPosition;
  final LocationFailure? locationFailure;

  /// Road path through the stops still to visit, one leg per hop.
  final DirectionsResult? directions;
  final bool directionsFailed;

  /// While true the camera rides along with the driver.
  final bool followDriver;
  final bool isMapExpanded;

  final CameraCommand? camera;
  final DeliveryMessage? message;

  /// Stop with a request in flight — its buttons are disabled meanwhile.
  final int? busyStopId;
  final bool isCompletingRoute;

  /// Arrival response per stop: OTP dispatch details and expected seals.
  final Map<int, ArrivalResult> arrivals;

  /// Last OTP verify / resend outcome per stop.
  final Map<int, OtpResult> otpResults;

  /// Stops whose receiver handoff was verified through `handoff/verify`
  /// (trader QR or code) or `otp/verify`.
  final Set<int> otpVerifiedStopIds;

  /// QR / code captured offline per stop, see [HandoffCapture].
  final Map<int, HandoffCapture> handoffCaptures;

  /// Stops whose last action is waiting in the offline queue.
  final Set<int> pendingSyncStopIds;

  /// Goods receipt status polled after a delivery, per stop.
  final Map<int, ReceiptStatusModel> receiptStatuses;

  /// End of day summary, once the route was completed.
  final EndOfDaySummaryModel? summary;

  List<RouteStop> get stops => route.stops;

  int get stopsDone => stops.where((stop) => stop.status.isClosed).length;

  bool get isFinished => stops.isEmpty || stopsDone >= stops.length;

  bool get isRouteCompleted => route.isCompleted;

  /// The supplier canceled the route (or the server closed it as canceled)
  /// while this screen was open: no action is possible any more.
  bool get isRouteCanceled => route.status == RouteStatus.cancelled;

  /// Completed or canceled: the screen only leads back home now.
  bool get isRouteClosed => isRouteCompleted || isRouteCanceled;

  double get progress => stops.isEmpty ? 0 : stopsDone / stops.length;

  bool isBusy(int stopId) => busyStopId == stopId;

  bool isPendingSync(int stopId) => pendingSyncStopIds.contains(stopId);

  bool isOtpVerified(int stopId) => otpVerifiedStopIds.contains(stopId);

  /// The first stop that is not closed yet, or null once the route is done.
  int? get currentStopIndex {
    final index = stops.indexWhere((stop) => !stop.status.isClosed);
    return index == -1 ? null : index;
  }

  RouteStop? get currentStop {
    final index = currentStopIndex;
    return index == null ? null : stops[index];
  }

  RouteStop? stopById(int id) {
    for (final stop in stops) {
      if (stop.id == id) return stop;
    }
    return null;
  }

  List<RouteStop> get remainingStops => [
    for (final stop in stops)
      if (!stop.status.isClosed && stop.hasLocation) stop,
  ];

  /// The hop the driver is on right now: their location -> the current stop.
  DirectionsLeg? get activeLeg {
    final legs = directions?.legs;
    return legs == null || legs.isEmpty ? null : legs.first;
  }

  /// Straight line distance from the driver to [stop], null without a fix or
  /// when the stop has no coordinates.
  double? distanceTo(RouteStop stop) {
    final position = driverPosition;
    if (position == null || !stop.hasLocation) return null;

    return const LocationService().distanceInMeters(
      startLatitude: position.latitude,
      startLongitude: position.longitude,
      endLatitude: stop.latitude!,
      endLongitude: stop.longitude!,
    );
  }

  DeliveryTrackingState copyWith({
    RouteModel? route,
    Position? driverPosition,
    LocationFailure? locationFailure,
    DirectionsResult? directions,
    bool? directionsFailed,
    bool? followDriver,
    bool? isMapExpanded,
    CameraCommand? camera,
    DeliveryMessage? message,
    int? busyStopId,
    bool clearBusy = false,
    bool? isCompletingRoute,
    Map<int, ArrivalResult>? arrivals,
    Map<int, OtpResult>? otpResults,
    Set<int>? otpVerifiedStopIds,
    Map<int, HandoffCapture>? handoffCaptures,
    Set<int>? pendingSyncStopIds,
    Map<int, ReceiptStatusModel>? receiptStatuses,
    EndOfDaySummaryModel? summary,
    bool clearLocationFailure = false,
    bool clearDirections = false,
  }) {
    return DeliveryTrackingState(
      route: route ?? this.route,
      driverPosition: driverPosition ?? this.driverPosition,
      locationFailure: clearLocationFailure ? null : locationFailure ?? this.locationFailure,
      directions: clearDirections ? null : directions ?? this.directions,
      directionsFailed: directionsFailed ?? this.directionsFailed,
      followDriver: followDriver ?? this.followDriver,
      isMapExpanded: isMapExpanded ?? this.isMapExpanded,
      camera: camera ?? this.camera,
      message: message ?? this.message,
      busyStopId: clearBusy ? null : busyStopId ?? this.busyStopId,
      isCompletingRoute: isCompletingRoute ?? this.isCompletingRoute,

      arrivals: arrivals ?? this.arrivals,
      otpResults: otpResults ?? this.otpResults,
      otpVerifiedStopIds: otpVerifiedStopIds ?? this.otpVerifiedStopIds,
      handoffCaptures: handoffCaptures ?? this.handoffCaptures,
      pendingSyncStopIds: pendingSyncStopIds ?? this.pendingSyncStopIds,
      receiptStatuses: receiptStatuses ?? this.receiptStatuses,
      summary: summary ?? this.summary,
    );
  }
}
