import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';

/// What the driver does at a stop.
enum StopType { delivery, pickup }

extension StopTypeData on StopType {
  String get titleKey => switch (this) {
    StopType.delivery => "stop_delivery",
    StopType.pickup => "stop_pickup",
  };
}

/// Where the driver got to with a stop.
enum StopStatus { pending, arrived, completed }

extension StopStatusData on StopStatus {
  String get titleKey => switch (this) {
    StopStatus.pending => "stop_pending",
    StopStatus.arrived => "stop_arrived",
    StopStatus.completed => "route_completed",
  };

  Color get color => switch (this) {
    StopStatus.pending => const Color(0xff667085),
    StopStatus.arrived => const Color(0xffE8A317),
    StopStatus.completed => AppColors.secondaryColor,
  };
}

class RouteStop {
  RouteStop({
    required this.name,
    required this.type,
    required this.status,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final StopType type;
  final StopStatus status;

  /// Where the stop sits on the map.
  final double latitude;
  final double longitude;

  RouteStop copyWith({String? name, StopType? type, StopStatus? status, double? latitude, double? longitude}) {
    return RouteStop(
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class RouteModel {
  RouteModel({
    required this.code,
    required this.date,
    required this.distanceKm,
    required this.stops,
  });

  final String code;
  final DateTime date;
  final double distanceKm;
  final List<RouteStop> stops;

  int get stopsTotal => stops.length;

  int get stopsDone => stops.where((stop) => stop.status == StopStatus.completed).length;

  bool get isCompleted => stopsTotal > 0 && stopsDone >= stopsTotal;

  /// Placeholder feed for the home screen until the routes endpoint is wired:
  /// the routes assigned to the driver for today.
  static List<RouteModel> todayDemoData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return [
      RouteModel(
        code: "RT-RUH-TODAY-01",
        date: today.add(const Duration(hours: 8)),
        distanceKm: 1.3,
        stops: [
          RouteStop(name: "مستودع الرياض", type: StopType.pickup, status: StopStatus.pending, latitude: 28.827374, longitude: 30.906402),
          RouteStop(name: "بنده - النخيل", type: StopType.delivery, status: StopStatus.pending, latitude: 28.832227, longitude: 30.902993),
        ],
      ),
      RouteModel(
        code: "RT-RUH-TODAY-02",
        date: today.add(const Duration(hours: 15)),
        distanceKm: 19.2,
        stops: [
          RouteStop(name: "مستودع الرياض", type: StopType.pickup, status: StopStatus.pending, latitude: 24.628, longitude: 46.716),
          RouteStop(name: "كارفور - الحمراء", type: StopType.delivery, status: StopStatus.pending, latitude: 24.7745, longitude: 46.762),
        ],
      ),
    ];
  }

  /// Placeholder feed until the routes endpoint is wired.
  static List<RouteModel> demoData() {
    return [
      RouteModel(
        code: "RT-RUH-2026-0418-01",
        date: DateTime(2026, 4, 18, 8),
        distanceKm: 28,
        stops: [
          RouteStop(name: "بنده - النخيل", type: StopType.delivery, status: StopStatus.completed, latitude: 24.7433, longitude: 46.63),
          RouteStop(name: "مستودع الرياض", type: StopType.pickup, status: StopStatus.completed, latitude: 24.628, longitude: 46.716),
        ],
      ),
      RouteModel(
        code: "RT-RUH-2026-0405-01",
        date: DateTime(2026, 4, 5, 9, 30),
        distanceKm: 37.1,
        stops: [
          RouteStop(name: "مستودع الرياض", type: StopType.pickup, status: StopStatus.completed, latitude: 24.628, longitude: 46.716),
        ],
      ),
      RouteModel(
        code: "RT-RUH-2026-0331-02",
        date: DateTime(2026, 3, 31, 7, 15),
        distanceKm: 62.4,
        stops: [
          RouteStop(name: "مستودع الرياض", type: StopType.pickup, status: StopStatus.completed, latitude: 24.628, longitude: 46.716),
          RouteStop(name: "بنده - النخيل", type: StopType.delivery, status: StopStatus.completed, latitude: 24.7433, longitude: 46.63),
          RouteStop(name: "بنده - الدمام", type: StopType.delivery, status: StopStatus.arrived, latitude: 26.4207, longitude: 50.0888),
          RouteStop(name: "أسواق العثيم - الملز", type: StopType.delivery, status: StopStatus.pending, latitude: 24.6714, longitude: 46.736),
        ],
      ),
      RouteModel(
        code: "RT-RUH-2026-0329-01",
        date: DateTime(2026, 3, 29, 10),
        distanceKm: 48.9,
        stops: [
          RouteStop(name: "مستودع الرياض", type: StopType.pickup, status: StopStatus.completed, latitude: 24.628, longitude: 46.716),
          RouteStop(name: "بنده - النخيل", type: StopType.delivery, status: StopStatus.completed, latitude: 24.7433, longitude: 46.63),
          RouteStop(name: "كارفور - الحمراء", type: StopType.delivery, status: StopStatus.completed, latitude: 24.7745, longitude: 46.762),
        ],
      ),
    ];
  }
}
