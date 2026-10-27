import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/features/auth/data/models/user_model.dart';
import 'package:digital_trade_portal_driver/features/my_cars/data/models/vehicle_model.dart';

/// An organisation or outsourced fleet company the driver belongs to.
class OrganizationModel {
  const OrganizationModel({required this.id, this.name});

  final int id;
  final String? name;

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      id: JsonUtils.asInt(json["id"]) ?? 0,
      name: JsonUtils.asString(json["name"] ?? json["company_name"] ?? json["title"]),
    );
  }
}

/// `GET /api/v2/driver/profile` → `driver`: the `fleet_drivers` row plus the
/// user, default vehicle, organisation and fleet company relations.
class DriverModel {
  const DriverModel({
    required this.id,
    this.userId,
    this.organizationId,
    this.fleetCompanyId,
    this.status,
    this.employmentType,
    this.rating,
    this.totalDeliveries = 0,
    this.totalPickups = 0,
    this.ratePerDelivery,
    this.baseSalary,
    this.currency,
    this.canBypassOtp = false,
    this.driverLicenseNo,
    this.driverLicenseExpiry,
    this.nationalId,
    this.photo,
    this.defaultVehicleId,
    this.termsAccepted = false,
    this.termsAcceptedAt,
    this.language,
    this.user,
    this.defaultVehicle,
    this.organization,
    this.fleetCompany,
  });

  final int id;
  final int? userId;
  final int? organizationId;
  final int? fleetCompanyId;
  final String? status;
  final String? employmentType;
  final double? rating;
  final int totalDeliveries;
  final int totalPickups;
  final double? ratePerDelivery;
  final double? baseSalary;
  final String? currency;
  final bool canBypassOtp;
  final String? driverLicenseNo;
  final String? driverLicenseExpiry;
  final String? nationalId;
  final String? photo;
  final int? defaultVehicleId;
  final bool termsAccepted;
  final DateTime? termsAcceptedAt;
  final String? language;
  final UserModel? user;
  final VehicleModel? defaultVehicle;
  final OrganizationModel? organization;
  final OrganizationModel? fleetCompany;

  String get displayName => user?.fullName ?? "";

  String get phone => user?.phone ?? "";

  String get email => user?.email ?? "";

  bool get isActive => status == null || status == "active";

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    final acceptedAt = JsonUtils.asDate(json["terms_accepted_at"]);
    final acceptedFlag = json["terms_accepted"];
    final user = JsonUtils.asMapOrNull(json["user"]);
    final vehicle = JsonUtils.asMapOrNull(json["defaultVehicle"] ?? json["default_vehicle"]);
    final organization = JsonUtils.asMapOrNull(json["organization"]);
    final fleetCompany = JsonUtils.asMapOrNull(json["fleetCompany"] ?? json["fleet_company"]);

    return DriverModel(
      id: JsonUtils.asInt(json["id"]) ?? 0,
      userId: JsonUtils.asInt(json["user_id"]),
      organizationId: JsonUtils.asInt(json["organization_id"]),
      fleetCompanyId: JsonUtils.asInt(json["fleet_company_id"]),
      status: JsonUtils.asString(json["status"]),
      employmentType: JsonUtils.asString(json["employment_type"]),
      rating: JsonUtils.asDouble(json["rating"]),
      totalDeliveries: JsonUtils.asInt(json["total_deliveries"]) ?? 0,
      totalPickups: JsonUtils.asInt(json["total_pickups"]) ?? 0,
      ratePerDelivery: JsonUtils.asDouble(json["rate_per_delivery"]),
      baseSalary: JsonUtils.asDouble(json["base_salary"]),
      currency: JsonUtils.asString(json["currency"]),
      canBypassOtp: JsonUtils.asBool(json["can_bypass_otp"]),
      driverLicenseNo: JsonUtils.asString(json["driver_license_no"]),
      driverLicenseExpiry: JsonUtils.asString(json["driver_license_expiry"]),
      nationalId: JsonUtils.asString(json["national_id"]),
      photo: JsonUtils.asString(json["photo"]),
      defaultVehicleId: JsonUtils.asInt(json["default_vehicle_id"]),
      // Either an explicit flag or the acceptance timestamp marks the terms as done.
      termsAccepted: acceptedFlag != null ? JsonUtils.asBool(acceptedFlag) : acceptedAt != null,
      termsAcceptedAt: acceptedAt,
      language: JsonUtils.asString(json["language"] ?? json["lang"] ?? (user?["language"] ?? user?["lang"])),
      user: user == null ? null : UserModel.fromJson(user),
      defaultVehicle: vehicle == null ? null : (VehicleModel.fromJson(vehicle)..isAssigned = true),
      organization: organization == null ? null : OrganizationModel.fromJson(organization),
      fleetCompany: fleetCompany == null ? null : OrganizationModel.fromJson(fleetCompany),
    );
  }

  DriverModel copyWith({
    bool? termsAccepted,
    DateTime? termsAcceptedAt,
    String? language,
    UserModel? user,
    VehicleModel? defaultVehicle,
    int? defaultVehicleId,
    String? nationalId,
    String? driverLicenseNo,
    String? driverLicenseExpiry,
    String? photo,
  }) {
    return DriverModel(
      id: id,
      userId: userId,
      organizationId: organizationId,
      fleetCompanyId: fleetCompanyId,
      status: status,
      employmentType: employmentType,
      rating: rating,
      totalDeliveries: totalDeliveries,
      totalPickups: totalPickups,
      ratePerDelivery: ratePerDelivery,
      baseSalary: baseSalary,
      currency: currency,
      canBypassOtp: canBypassOtp,
      driverLicenseNo: driverLicenseNo ?? this.driverLicenseNo,
      driverLicenseExpiry: driverLicenseExpiry ?? this.driverLicenseExpiry,
      nationalId: nationalId ?? this.nationalId,
      photo: photo ?? this.photo,
      defaultVehicleId: defaultVehicleId ?? this.defaultVehicleId,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      language: language ?? this.language,
      user: user ?? this.user,
      defaultVehicle: defaultVehicle ?? this.defaultVehicle,
      organization: organization,
      fleetCompany: fleetCompany,
    );
  }
}
