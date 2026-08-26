import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';

/// Kind of problem a driver can report from the road.
enum IssueType { accident, vehicleBreakdown, goodsDamage, customerComplaint }

extension IssueTypeData on IssueType {
  String get titleKey => switch (this) {
    IssueType.accident => "issue_accident",
    IssueType.vehicleBreakdown => "issue_vehicle",
    IssueType.goodsDamage => "issue_goods",
    IssueType.customerComplaint => "issue_complaint",
  };

  IconData get icon => switch (this) {
    IssueType.accident => Icons.emergency_rounded,
    IssueType.vehicleBreakdown => Icons.build_rounded,
    IssueType.goodsDamage => Icons.inventory_2_rounded,
    IssueType.customerComplaint => Icons.people_alt_rounded,
  };

  Color get color => switch (this) {
    IssueType.accident => AppColors.red,
    IssueType.vehicleBreakdown => const Color(0xff667085),
    IssueType.goodsDamage => const Color(0xffE8A317),
    IssueType.customerComplaint => AppColors.primarySwatchColor,
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
}
