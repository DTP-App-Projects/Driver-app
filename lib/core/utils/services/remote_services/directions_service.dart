import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
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

/// Asks OSRM (OpenStreetMap road data) for the road path through the
/// remaining stops, in order, so the map draws what the driver actually drives
/// instead of a straight line.
class DirectionsService {
  DirectionsService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// [origin] is the live driver position, [stops] the stops still to visit in
  /// the order they are driven. Null when the route cannot be built, so the
  /// caller can fall back to straight lines. OSRM has no localized output, so
  /// [languageCode] is unused; it stays for callers.
  Future<DirectionsResult?> route({
    required LatLng origin,
    required List<LatLng> stops,
    required String languageCode,
  }) async {
    if (stops.isEmpty) return null;

    // OSRM takes "lng,lat" pairs joined by ";".
    final coordinates = [origin, ...stops].map((point) => "${point.longitude},${point.latitude}").join(";");

    try {
      final response = await _dio.get(
        "${EndPoints.osrmRouteUrl}/$coordinates",
        // Steps carry the per leg shape; the overview would be one line for
        // the whole route.
        queryParameters: {"overview": "false", "steps": "true", "geometries": "polyline"},
        options: Options(headers: {"User-Agent": EndPoints.osmUserAgent}),
      );

      if (response.data?["code"] != "Ok") return null;

      final routes = response.data?["routes"] as List?;
      if (routes == null || routes.isEmpty) return null;

      final legs = (routes.first["legs"] as List?) ?? const [];
      if (legs.isEmpty) return null;

      return DirectionsResult(
        legs: [
          for (final leg in legs)
            DirectionsLeg(
              points: [
                for (final step in (leg["steps"] as List?) ?? const [])
                  ...decodePolyline(step["geometry"] as String? ?? ""),
              ],
              distanceMeters: (leg["distance"] as num?)?.round() ?? 0,
              duration: Duration(seconds: (leg["duration"] as num?)?.round() ?? 0),
            ),
        ],
      );
    } on DioException catch (error) {
      // The map keeps working with straight hops.
      debugPrint("Directions request failed: ${error.response?.statusCode} ${error.response?.data}");
      return null;
    } catch (error) {
      debugPrint("Directions request failed: $error");
      return null;
    }
  }

  /// Encoded polyline algorithm (precision 5, as OSRM returns it), turned back into map points.
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
