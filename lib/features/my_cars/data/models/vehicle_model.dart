import 'package:flutter/material.dart';

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

class VehicleModel {
  VehicleModel({
    required this.plate,
    required this.type,
    required this.manufacturer,
    required this.model,
    required this.year,
    required this.capacityTons,
    this.isAssigned = false,
  });

  final String plate;
  final VehicleType type;
  final String manufacturer;
  final String model;
  final int year;
  final double capacityTons;
  bool isAssigned;

  bool get isRefrigerated => type == VehicleType.refrigeratedTruck;

  String get fullName => "$manufacturer $model";

  /// Placeholder fleet until the vehicles endpoint is wired.
  static List<VehicleModel> demoData() {
    return [
      VehicleModel(
        plate: "ر ر أ ١٢٣٤",
        type: VehicleType.refrigeratedTruck,
        manufacturer: "Isuzu",
        model: "NQR",
        year: 2023,
        capacityTons: 3.5,
      ),
      VehicleModel(
        plate: "ر ر ب ٥٦٧٨",
        type: VehicleType.refrigeratedTruck,
        manufacturer: "Hino",
        model: "300",
        year: 2022,
        capacityTons: 4,
      ),
      VehicleModel(
        plate: "ر ر ج ٩٠١٢",
        type: VehicleType.van,
        manufacturer: "Toyota",
        model: "HiAce",
        year: 2024,
        capacityTons: 1.5,
        isAssigned: true,
      ),
    ];
  }
}
