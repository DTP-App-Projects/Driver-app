import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/directions_service.dart';

/// Distances and drive times, formatted the way the delivery screens show them.
class DeliveryFormat {
  const DeliveryFormat._();

  /// "450 m away" / "4.3 km away", used for the straight line to a stop.
  static String distanceAway(BuildContext context, double meters) {
    final locale = context.locale.languageCode;

    if (meters < 1000) {
      return "distance_away_m".tr(namedArgs: {"distance": NumberFormat("#0", locale).format(meters)});
    }

    return "distance_away_km".tr(namedArgs: {"distance": NumberFormat("#0.0", locale).format(meters / 1000)});
  }

  /// "450 m" / "4.3 km", used for a driven distance.
  static String distance(BuildContext context, num meters) {
    final locale = context.locale.languageCode;

    if (meters < 1000) {
      return "distance_m".tr(namedArgs: {"distance": NumberFormat("#0", locale).format(meters)});
    }

    return "distance_km".tr(namedArgs: {"distance": NumberFormat("#0.0", locale).format(meters / 1000)});
  }

  static String duration(BuildContext context, Duration duration) {
    final number = NumberFormat.decimalPattern(context.locale.languageCode);
    final minutes = (duration.inSeconds / 60).round();

    if (minutes < 60) {
      return "eta_minutes".tr(namedArgs: {"minutes": number.format(minutes < 1 ? 1 : minutes)});
    }

    return "eta_hours".tr(namedArgs: {"hours": number.format(minutes ~/ 60), "minutes": number.format(minutes % 60)});
  }

  /// Road distance and drive time of a hop, e.g. "4.3 km • 12 min".
  static String? leg(BuildContext context, DirectionsLeg? leg) {
    if (leg == null) return null;
    return "${distance(context, leg.distanceMeters)} • ${duration(context, leg.duration)}";
  }
}
