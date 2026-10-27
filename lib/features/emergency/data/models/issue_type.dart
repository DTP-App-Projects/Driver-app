import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';

/// Kind of problem a driver can report from the road — the `incident_type`
/// set accepted by `POST /api/v2/driver/incidents`.
enum IssueType { accident, vehicleBreakdown, goodsDamage, theftAttempt, customerComplaint, delay, other }

extension IssueTypeData on IssueType {
  String get titleKey => switch (this) {
    IssueType.accident => "issue_accident",
    IssueType.vehicleBreakdown => "issue_vehicle",
    IssueType.goodsDamage => "issue_goods",
    IssueType.theftAttempt => "issue_theft",
    IssueType.customerComplaint => "issue_complaint",
    IssueType.delay => "issue_delay",
    IssueType.other => "issue_other",
  };

  IconData get icon => switch (this) {
    IssueType.accident => Icons.emergency_rounded,
    IssueType.vehicleBreakdown => Icons.build_rounded,
    IssueType.goodsDamage => Icons.inventory_2_rounded,
    IssueType.theftAttempt => Icons.gpp_maybe_rounded,
    IssueType.customerComplaint => Icons.people_alt_rounded,
    IssueType.delay => Icons.schedule_rounded,
    IssueType.other => Icons.more_horiz_rounded,
  };

  Color get color => switch (this) {
    IssueType.accident => AppColors.red,
    IssueType.vehicleBreakdown => const Color(0xff667085),
    IssueType.goodsDamage => const Color(0xffE8A317),
    IssueType.theftAttempt => const Color(0xff7A3E9D),
    IssueType.customerComplaint => AppColors.primarySwatchColor,
    IssueType.delay => const Color(0xff2E7DAF),
    IssueType.other => const Color(0xff98A2B3),
  };

  String get apiValue => switch (this) {
    IssueType.accident => "accident",
    IssueType.vehicleBreakdown => "vehicle_breakdown",
    IssueType.goodsDamage => "goods_damage",
    IssueType.theftAttempt => "theft_attempt",
    IssueType.customerComplaint => "customer_complaint",
    IssueType.delay => "delay",
    IssueType.other => "other",
  };
}

/// How urgent the report is.
enum IssueSeverity { low, medium, high, critical }

extension IssueSeverityData on IssueSeverity {
  String get titleKey => switch (this) {
    IssueSeverity.low => "severity_low",
    IssueSeverity.medium => "severity_medium",
    IssueSeverity.high => "severity_high",
    IssueSeverity.critical => "severity_critical",
  };

  String get apiValue => name;
}

/// A `driver_incidents` row as returned by report / lifecycle calls.
class IncidentModel {
  const IncidentModel({
    required this.id,
    this.incidentType,
    this.severity,
    this.status,
    this.description,
    this.routeId,
    this.stopId,
    this.reportedAt,
    this.resolvedAt,
  });

  final int id;
  final String? incidentType;
  final String? severity;

  /// `reported → acknowledged → investigating → resolved|dismissed`.
  final String? status;
  final String? description;
  final int? routeId;
  final int? stopId;
  final DateTime? reportedAt;
  final DateTime? resolvedAt;

  factory IncidentModel.fromJson(Map<String, dynamic> json) => IncidentModel(
    id: JsonUtils.asInt(json["id"]) ?? 0,
    incidentType: JsonUtils.asString(json["incident_type"]),
    severity: JsonUtils.asString(json["severity"]),
    status: JsonUtils.asString(json["status"]),
    description: JsonUtils.asString(json["description"]),
    routeId: JsonUtils.asInt(json["route_id"]),
    stopId: JsonUtils.asInt(json["stop_id"]),
    reportedAt: JsonUtils.asDate(json["reported_at"] ?? json["created_at"]),
    resolvedAt: JsonUtils.asDate(json["resolved_at"]),
  );
}

/// `GET /api/v2/incidents/{id}/age`.
class IncidentAgeModel {
  const IncidentAgeModel({this.slaBreached = false, this.severity, this.reportedAt, this.resolvedAt});

  final bool slaBreached;
  final String? severity;
  final DateTime? reportedAt;
  final DateTime? resolvedAt;

  factory IncidentAgeModel.fromJson(Map<String, dynamic> json) => IncidentAgeModel(
    slaBreached: JsonUtils.asBool(json["sla_breached"]),
    severity: JsonUtils.asString(json["severity"]),
    reportedAt: JsonUtils.asDate(json["reported_at"]),
    resolvedAt: JsonUtils.asDate(json["resolved_at"]),
  );
}
