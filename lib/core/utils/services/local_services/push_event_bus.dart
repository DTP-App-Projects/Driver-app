import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_push_event.dart';

/// Hands FCM route pushes from the messaging callbacks in `main.dart` to the
/// cubits. The last event is kept so a cubit created after the push (cold
/// start from a notification tap) still sees it.
class PushEventBus {
  final StreamController<RoutePushEvent> _controller = StreamController.broadcast();
  RoutePushEvent? _pending;

  Stream<RoutePushEvent> get events => _controller.stream;

  /// The event nobody consumed yet, cleared on read.
  RoutePushEvent? takePending() {
    final event = _pending;
    _pending = null;
    return event;
  }

  /// Parses [data] (`RemoteMessage.data`) and publishes it when it is a
  /// route push; anything else is ignored.
  void publishData(Map<dynamic, dynamic> data, {String? title, String? body}) {
    final event = RoutePushEvent.fromData(JsonUtils.asMap(data), title: title, body: body);
    if (event == null) return;
    publish(event);
  }

  void publish(RoutePushEvent event) {
    debugPrint("PushEventBus: ${event.eventCode} route=${event.routeId} stop=${event.stopId}");
    // Kept until the route cubit takes it, whether it is listening yet or not.
    _pending = event;
    _controller.add(event);
  }

  void dispose() => _controller.close();
}
