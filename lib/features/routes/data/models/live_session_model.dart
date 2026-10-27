import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';

/// `GET /driver/live` → `live`: a short-lived Firebase custom token and the
/// Realtime Database node the driver writes its position to. `enabled:
/// false` (not configured on the server, or `409 no_active_route`) means the
/// app keeps sending history to Laravel only, exactly as before.
class LiveSessionModel {
  const LiveSessionModel({
    required this.enabled,
    this.token,
    this.uid,
    this.databaseUrl,
    this.expiresAt,
    this.path,
    this.driverId,
    this.routeId,
    this.sup,
    this.writeInterval = defaultWriteInterval,
    this.historyInterval = defaultHistoryInterval,
  });

  static const LiveSessionModel disabled = LiveSessionModel(enabled: false);

  static const Duration defaultWriteInterval = Duration(seconds: 5);
  static const Duration defaultHistoryInterval = Duration(seconds: 60);

  final bool enabled;
  final String? token;
  final String? uid;
  final String? databaseUrl;
  final DateTime? expiresAt;

  /// `live/drivers/{driverId}`.
  final String? path;
  final int? driverId;
  final int? routeId;

  /// Supplier id the security rules check on every write: it must be sent
  /// back exactly as received.
  final int? sup;
  final Duration writeInterval;

  /// How often the batched points go to `POST /driver/location` while live.
  final Duration historyInterval;

  /// Everything a write needs is there.
  bool get isUsable =>
      enabled &&
      (token?.isNotEmpty ?? false) &&
      (databaseUrl?.isNotEmpty ?? false) &&
      (path?.isNotEmpty ?? false) &&
      sup != null;

  factory LiveSessionModel.fromJson(Map<String, dynamic> json) {
    final live = JsonUtils.asMapOrNull(json["live"]) ?? json;
    if (!JsonUtils.asBool(live["enabled"])) return disabled;

    Duration seconds(dynamic value, Duration fallback) {
      final parsed = JsonUtils.asInt(value);
      return parsed == null || parsed <= 0 ? fallback : Duration(seconds: parsed);
    }

    return LiveSessionModel(
      enabled: true,
      token: JsonUtils.asString(live["token"]),
      uid: JsonUtils.asString(live["uid"]),
      databaseUrl: JsonUtils.asString(live["database_url"]),
      expiresAt: JsonUtils.asDate(live["expires_at"]),
      path: JsonUtils.asString(live["path"]),
      driverId: JsonUtils.asInt(live["driver_id"]),
      routeId: JsonUtils.asInt(live["route_id"]),
      sup: JsonUtils.asInt(live["sup"]),
      writeInterval: seconds(live["write_interval_seconds"], defaultWriteInterval),
      historyInterval: seconds(live["history_interval_seconds"], defaultHistoryInterval),
    );
  }
}
