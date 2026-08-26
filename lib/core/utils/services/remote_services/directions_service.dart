import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/endpoints.dart';

/// One driven leg of a route: driver -> first stop, first stop -> second stop
/// and so on, with the shape it follows on the road.
class DirectionsLeg {
  const DirectionsLeg({required this.points, required this.distanceMeters, required this.duration});

  final List<LatLng> points;
  final int distanceMeters;
  final Duration duration;
}

class DirectionsResult {
  const DirectionsResult({required this.legs});

  final List<DirectionsLeg> legs;

  int get distanceMeters => legs.fold(0, (total, leg) => total + leg.distanceMeters);

  Duration get duration => legs.fold(Duration.zero, (total, leg) => total + leg.duration);
}

/// Asks Google for the road path through the remaining stops, in order, so the
/// map draws what the driver actually drives instead of a straight line.
class DirectionsService {
  DirectionsService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// [origin] is the live driver position, [stops] the stops still to visit in
  /// the order they are driven. Null when the route cannot be built, so the
  /// caller can fall back to straight lines.
  Future<DirectionsResult?> route({
    required LatLng origin,
    required List<LatLng> stops,
    required String languageCode,
  }) async {
    if (stops.isEmpty) return null;

    try {
      final response = await _dio.post(
        EndPoints.googleRoutesUrl,
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": EndPoints.googleMapsApiKey,
            // Routes API bills per requested field, so only ask for the shape
            // and the numbers shown to the driver.
            "X-Goog-FieldMask": "routes.legs.polyline.encodedPolyline,routes.legs.distanceMeters,routes.legs.duration",
          },
        ),
        data: {
          "origin": _waypoint(origin),
          "destination": _waypoint(stops.last),
          if (stops.length > 1) "intermediates": [for (final stop in stops.sublist(0, stops.length - 1)) _waypoint(stop)],
          "travelMode": "DRIVE",
          "routingPreference": "TRAFFIC_AWARE",
          "polylineQuality": "HIGH_QUALITY",
          "languageCode": languageCode,
          "units": "METRIC",
        },
      );

      final routes = response.data?["routes"] as List?;
      if (routes == null || routes.isEmpty) return null;

      final legs = (routes.first["legs"] as List?) ?? const [];
      if (legs.isEmpty) return null;

      return DirectionsResult(
        legs: [
          for (final leg in legs)
            DirectionsLeg(
              points: decodePolyline(leg["polyline"]?["encodedPolyline"] as String? ?? ""),
              distanceMeters: (leg["distanceMeters"] as num?)?.toInt() ?? 0,
              duration: _parseDuration(leg["duration"] as String?),
            ),
        ],
      );
    } on DioException catch (error) {
      // Most often the key is missing the Routes API; the map keeps working.
      debugPrint("Directions request failed: ${error.response?.statusCode} ${error.response?.data}");
      return null;
    } catch (error) {
      debugPrint("Directions request failed: $error");
      return null;
    }
  }

  Map<String, dynamic> _waypoint(LatLng point) => {
    "location": {
      "latLng": {"latitude": point.latitude, "longitude": point.longitude},
    },
  };

  /// Routes API returns seconds as a string, e.g. "845s".
  Duration _parseDuration(String? value) {
    if (value == null) return Duration.zero;
    return Duration(seconds: int.tryParse(value.replaceAll("s", "")) ?? 0);
  }

  /// Google encoded polyline algorithm, turned back into map points.
  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, latitude = 0, longitude = 0;

    while (index < encoded.length) {
      int result = 0, shift = 0, byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      latitude += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      result = 0;
      shift = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      longitude += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }

    return points;
  }
}
