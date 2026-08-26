import 'package:geolocator/geolocator.dart';

/// Why the driver position is not available, so the UI can say what to do
/// about it instead of showing an empty map.
enum LocationFailure { serviceDisabled, denied, deniedForever }

/// Thin wrapper around geolocator: asks for permission once and then streams
/// the driver position while a delivery is in progress.
class LocationService {
  const LocationService();

  static const LocationSettings _settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    // Only report a new position after the driver actually moved, so the map
    // does not redraw on GPS jitter while parked at a stop.
    distanceFilter: 10,
  );

  /// Null when location is usable, otherwise the reason it is not.
  Future<LocationFailure?> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationFailure.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return switch (permission) {
      LocationPermission.denied => LocationFailure.denied,
      LocationPermission.deniedForever => LocationFailure.deniedForever,
      _ => null,
    };
  }

  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(locationSettings: _settings);
    } catch (_) {
      // A fix can be unavailable indoors; the stream keeps trying.
      return null;
    }
  }

  Stream<Position> positionStream() => Geolocator.getPositionStream(locationSettings: _settings);

  /// Straight line distance in metres, used for the "how far is this stop" hint.
  double distanceInMeters({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(startLatitude, startLongitude, endLatitude, endLongitude);
  }

  Future<void> openSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
