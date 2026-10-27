import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';

/// Route events the backend pushes through FCM (`data.click_action = route`).
/// They are also listed by `GET /driver/notifications`; the push copy only
/// tells the app to act right away.
enum RoutePushEventType {
  /// The supplier canceled one shipment on the route, possibly mid-drive.
  shipmentCanceled,

  /// The supplier canceled the whole route before it started.
  routeCanceled,

  /// A stop was taken off the route (also sent when a skipped shipment is
  /// rescheduled by the supplier).
  stopRemoved,

  /// Any other `click_action = route` push: refresh only.
  other,
}

/// Parsed `RemoteMessage.data` of a route push. Every field is optional
/// because the payload keys differ per event; what matters is [type].
class RoutePushEvent {
  const RoutePushEvent({
    required this.type,
    required this.eventCode,
    this.title,
    this.body,
    this.routeId,
    this.routeCode,
    this.routeDate,
    this.routeStatus,
    this.routeClosed = false,
    this.stopId,
    this.deliveryNoteId,
    this.returnToBase = false,
    this.returnStopId,
  });

  final RoutePushEventType type;
  final String eventCode;

  /// Notification title / body, for the banner on the route screen.
  final String? title;
  final String? body;
  final int? routeId;
  final String? routeCode;
  final String? routeDate;

  /// Route status after the change (`shipment_canceled` only).
  final String? routeStatus;

  /// The cancellation left no open stop: the server closed the route
  /// (`completed` or `canceled`) and it is gone from `today_route`.
  final bool routeClosed;

  /// The stop that was canceled or removed.
  final int? stopId;
  final int? deliveryNoteId;

  /// `shipment_canceled` after the pickup was done: the goods are on the
  /// truck and a `return_to_base` stop was appended to the route.
  final bool returnToBase;
  final int? returnStopId;

  /// Whether the payload is a route push at all. Both the flat FCM `data`
  /// map and the inbox row's `payload_json` are accepted.
  static bool isRoutePush(Map<String, dynamic> data) {
    final code = JsonUtils.asString(data["event_code"]);
    if (code != null && _knownCodes.containsKey(code)) return true;
    return JsonUtils.asString(data["click_action"]) == "route";
  }

  static const Map<String, RoutePushEventType> _knownCodes = {
    "shipment_canceled": RoutePushEventType.shipmentCanceled,
    "route_canceled": RoutePushEventType.routeCanceled,
    "route_stop_removed": RoutePushEventType.stopRemoved,
  };

  static RoutePushEvent? fromData(Map<String, dynamic> data, {String? title, String? body}) {
    if (!isRoutePush(data)) return null;
    final code = JsonUtils.asString(data["event_code"]) ?? "";

    return RoutePushEvent(
      type: _knownCodes[code] ?? RoutePushEventType.other,
      eventCode: code,
      title: title ?? JsonUtils.asString(data["title"]),
      body: body ?? JsonUtils.asString(data["body"]),
      routeId: JsonUtils.asInt(data["route_id"]),
      routeCode: JsonUtils.asString(data["route_code"]),
      routeDate: JsonUtils.asString(data["route_date"]),
      routeStatus: JsonUtils.asString(data["route_status"]),
      routeClosed: JsonUtils.asBool(data["route_closed"]),
      stopId: JsonUtils.asInt(data["stop_id"] ?? data["route_stop_id"]),
      deliveryNoteId: JsonUtils.asInt(data["delivery_note_id"]),
      // Arrives as the string "1" / "0" in FCM data.
      returnToBase: JsonUtils.asBool(data["return_to_base"]),
      returnStopId: JsonUtils.asInt(data["return_stop_id"]),
    );
  }

  /// Shown as a banner on the route screen until the driver dismisses it.
  bool get isBlocking => type == RoutePushEventType.shipmentCanceled || type == RoutePushEventType.routeCanceled;

  /// The route named in the push no longer exists for the driver: whatever
  /// is held locally for it (queued actions, open screens) must go.
  bool get removesRoute => type == RoutePushEventType.routeCanceled || routeClosed;
}
