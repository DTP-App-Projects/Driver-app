import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';

enum NotificationType { route, order, alert, system }

/// One `driver_notifications` row from `GET /api/v2/driver/notifications`.
class NotificationModel {
  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.date,
    this.eventCode,
    this.payload = const {},
    this.deliveryNoteId,
    this.routeStopId,
    this.incidentId,
    this.isRead = false,
  });

  final int id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime date;
  final String? eventCode;
  final Map<String, dynamic> payload;
  final int? deliveryNoteId;
  final int? routeStopId;
  final int? incidentId;
  bool isRead;

  IconData get icon => switch (type) {
    NotificationType.route => Icons.route_rounded,
    NotificationType.order => Icons.inventory_2_outlined,
    NotificationType.alert => Icons.warning_amber_rounded,
    NotificationType.system => Icons.campaign_outlined,
  };

  Color get color => switch (type) {
    NotificationType.route => AppColors.primarySwatchColor,
    NotificationType.order => AppColors.secondaryColor,
    NotificationType.alert => AppColors.red,
    NotificationType.system => const Color(0xffE8A317),
  };

  /// The design groups the feed in four families; the server only sends an
  /// `event_code`, so the family is derived from it.
  static NotificationType typeFromEvent(String? eventCode, {int? incidentId, int? routeStopId, int? deliveryNoteId}) {
    final code = (eventCode ?? "").toLowerCase();
    if (incidentId != null || code.contains("incident") || code.contains("alert") || code.contains("sla")) {
      return NotificationType.alert;
    }
    if (code.contains("route")) return NotificationType.route;
    if (deliveryNoteId != null ||
        routeStopId != null ||
        code.contains("stop") ||
        code.contains("deliver") ||
        code.contains("pickup") ||
        code.contains("order") ||
        code.contains("receipt")) {
      return NotificationType.order;
    }
    return NotificationType.system;
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final eventCode = JsonUtils.asString(json["event_code"]);
    final incidentId = JsonUtils.asInt(json["incident_id"]);
    final routeStopId = JsonUtils.asInt(json["route_stop_id"]);
    final deliveryNoteId = JsonUtils.asInt(json["delivery_note_id"]);
    final rawPayload = json["payload_json"] ?? json["payload"];

    return NotificationModel(
      id: JsonUtils.asInt(json["id"]) ?? 0,
      type: typeFromEvent(eventCode, incidentId: incidentId, routeStopId: routeStopId, deliveryNoteId: deliveryNoteId),
      title: JsonUtils.asString(json["title"]) ?? "",
      body: JsonUtils.asString(json["body"]) ?? "",
      date: JsonUtils.asDate(json["created_at"]) ?? DateTime.now(),
      eventCode: eventCode,
      payload: rawPayload is Map ? JsonUtils.asMap(rawPayload) : const {},
      deliveryNoteId: deliveryNoteId,
      routeStopId: routeStopId,
      incidentId: incidentId,
      isRead: json["read_at"] != null,
    );
  }

  static List<NotificationModel> listFromJson(dynamic value) => [
    for (final item in JsonUtils.asMapList(value)) NotificationModel.fromJson(item),
  ];
}
