import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';

/// Kind of vehicle a driver can be assigned.
enum VehicleType { van, truck, refrigeratedTruck }

extension VehicleTypeData on VehicleType {
  String get titleKey => switch (this) {
    VehicleType.van => "vehicle_van",
    VehicleType.truck => "vehicle_truck",
    VehicleType.refrigeratedTruck => "vehicle_refrigerated_truck",
  };

  IconData get icon => switch (this) {
    VehicleType.van => Icons.airport_shuttle_rounded,
    VehicleType.truck => Icons.local_shipping_rounded,
    VehicleType.refrigeratedTruck => Icons.ac_unit_rounded,
  };
}

/// One `fleet_vehicles` row as returned by the available vehicles list and
/// as `defaultVehicle` on the driver profile.
class VehicleModel {
  VehicleModel({
    required this.id,
    required this.plate,
    required this.vehicleType,
    this.manufacturer,
    this.model,
    this.year,
    this.capacityKg,
    this.isRefrigerated = false,
    this.status,
    this.isAssigned = false,
  });

  final int id;
  final String plate;

  /// Raw `vehicle_type` from the server (`van`, `truck`, …).
  final String vehicleType;
  final String? manufacturer;
  final String? model;
  final int? year;
  final double? capacityKg;
  final bool isRefrigerated;
  final String? status;
  bool isAssigned;

  /// The design groups vehicles in three families; anything refrigerated
  /// shows as a refrigerated truck regardless of the raw type.
  VehicleType get type {
    if (isRefrigerated) return VehicleType.refrigeratedTruck;
    final raw = vehicleType.toLowerCase();
    if (raw.contains("refrig") || raw.contains("cold") || raw.contains("chiller")) {
      return VehicleType.refrigeratedTruck;
    }
    if (raw.contains("van") || raw.contains("pickup") || raw.contains("car") || raw.contains("bike")) {
      return VehicleType.van;
    }
    return VehicleType.truck;
  }

  double get capacityTons => (capacityKg ?? 0) / 1000;

  String get fullName => [manufacturer, model].where((part) => part != null && part.isNotEmpty).join(" ");

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: JsonUtils.asInt(json["id"]) ?? 0,
      plate: JsonUtils.asString(json["plate_number"] ?? json["plate"]) ?? "",
      vehicleType: JsonUtils.asString(json["vehicle_type"] ?? json["type"]) ?? "",
      manufacturer: JsonUtils.asString(json["make"] ?? json["manufacturer"]),
      model: JsonUtils.asString(json["model"]),
      year: JsonUtils.asInt(json["year"]),
      capacityKg: JsonUtils.asDouble(json["capacity_kg"]),
      isRefrigerated: JsonUtils.asBool(json["is_refrigerated"]),
      status: JsonUtils.asString(json["status"]),
    );
  }

  static List<VehicleModel> listFromJson(dynamic value) => [
    for (final item in JsonUtils.asMapList(value)) VehicleModel.fromJson(item),
  ];
}
