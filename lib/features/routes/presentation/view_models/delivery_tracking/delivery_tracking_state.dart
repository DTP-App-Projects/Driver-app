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

class DeliveryTrackingState {
  const DeliveryTrackingState({
    required this.stops,
    this.driverPosition,
    this.locationFailure,
    this.directions,
    this.directionsFailed = false,
    this.followDriver = true,
    this.isMapExpanded = false,
    this.camera,
    this.message,
  });

  final List<RouteStop> stops;
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

  int get stopsDone => stops.where((stop) => stop.status == StopStatus.completed).length;

  bool get isFinished => stops.isEmpty || stopsDone >= stops.length;

  double get progress => stops.isEmpty ? 0 : stopsDone / stops.length;

  /// The first stop that is not completed yet, or null once the route is done.
  int? get currentStopIndex {
    final index = stops.indexWhere((stop) => stop.status != StopStatus.completed);
    return index == -1 ? null : index;
  }

  RouteStop? get currentStop {
    final index = currentStopIndex;
    return index == null ? null : stops[index];
  }

  List<RouteStop> get remainingStops => [
    for (final stop in stops)
      if (stop.status != StopStatus.completed) stop,
  ];

  /// The hop the driver is on right now: their location -> the current stop.
  DirectionsLeg? get activeLeg {
    final legs = directions?.legs;
    return legs == null || legs.isEmpty ? null : legs.first;
  }

  /// Straight line distance from the driver to [stop], null without a fix.
  double? distanceTo(RouteStop stop) {
    final position = driverPosition;
    if (position == null) return null;

    return const LocationService().distanceInMeters(
      startLatitude: position.latitude,
      startLongitude: position.longitude,
      endLatitude: stop.latitude,
      endLongitude: stop.longitude,
    );
  }

  DeliveryTrackingState copyWith({
    List<RouteStop>? stops,
    Position? driverPosition,
    LocationFailure? locationFailure,
    DirectionsResult? directions,
    bool? directionsFailed,
    bool? followDriver,
    bool? isMapExpanded,
    CameraCommand? camera,
    DeliveryMessage? message,
    bool clearLocationFailure = false,
    bool clearDirections = false,
  }) {
    return DeliveryTrackingState(
      stops: stops ?? this.stops,
      driverPosition: driverPosition ?? this.driverPosition,
      locationFailure: clearLocationFailure ? null : locationFailure ?? this.locationFailure,
      directions: clearDirections ? null : directions ?? this.directions,
      directionsFailed: directionsFailed ?? this.directionsFailed,
      followDriver: followDriver ?? this.followDriver,
      isMapExpanded: isMapExpanded ?? this.isMapExpanded,
      camera: camera ?? this.camera,
      message: message ?? this.message,
    );
  }
}
