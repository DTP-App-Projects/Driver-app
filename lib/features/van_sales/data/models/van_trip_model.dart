import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/cache_keys.dart';

/// `draft → on_road → returning`, then closed on the web by the warehouse
/// keeper (after which `GET /driver/van/trip` answers `null`).
enum VanTripStatus { draft, onRoad, returning }

extension VanTripStatusData on VanTripStatus {
  String get titleKey => switch (this) {
    VanTripStatus.draft => "van_status_draft",
    VanTripStatus.onRoad => "van_status_on_road",
    VanTripStatus.returning => "van_status_returning",
  };

  Color get color => switch (this) {
    VanTripStatus.draft => const Color(0xff667085),
    VanTripStatus.onRoad => AppColors.primarySwatchColor,
    VanTripStatus.returning => const Color(0xffE8A317),
  };

  static VanTripStatus fromApi(String? value) => switch (value) {
    "on_road" => VanTripStatus.onRoad,
    "returning" => VanTripStatus.returning,
    _ => VanTripStatus.draft,
  };
}

/// `name_ar` / `name_en` (or `name` / `name_en`) in the app language.
String vanLocalizedName(Map<String, dynamic> json, {String arKey = "name_ar", String enKey = "name_en"}) {
  final bool english = CacheKeysManger.getUserLanguage() == "en";
  final candidates = english ? [enKey, arKey, "name"] : [arKey, "name", enKey];
  for (final key in candidates) {
    final value = JsonUtils.asString(json[key]);
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }
  return "";
}

/// Sends a whole quantity as an int so the server never sees `70.0`.
num vanQty(double value) => value == value.roundToDouble() ? value.toInt() : value;

/// One SKU on the van. For every line:
/// `loaded = sold + delivered + returned + damaged + missing`.
class VanTripLine {
  const VanTripLine({
    required this.lineId,
    required this.skuId,
    required this.name,
    this.barcode,
    this.unitPrice = 0,
    this.loaded = 0,
    this.sold = 0,
    this.delivered = 0,
    this.inVan = 0,
    this.inTransit = 0,
    this.driverReturned,
    this.returned = 0,
    this.damaged = 0,
    this.missing = 0,
  });

  final int lineId;
  final int skuId;
  final String name;
  final String? barcode;

  /// Before VAT.
  final double unitPrice;
  final double loaded;
  final double sold;
  final double delivered;

  /// Sellable right now.
  final double inVan;

  /// Reserved for a delivery not handed over yet.
  final double inTransit;

  /// The driver's own count when the return started.
  final double? driverReturned;
  final double returned;
  final double damaged;
  final double missing;

  bool get isSellable => inVan > 0;

  factory VanTripLine.fromJson(Map<String, dynamic> json) => VanTripLine(
    lineId: JsonUtils.asInt(json["line_id"]) ?? 0,
    skuId: JsonUtils.asInt(json["sku_id"]) ?? 0,
    name: JsonUtils.asString(json["name"]) ?? "",
    barcode: JsonUtils.asString(json["barcode"]),
    unitPrice: JsonUtils.asDouble(json["unit_price"]) ?? 0,
    loaded: JsonUtils.asDouble(json["loaded"]) ?? 0,
    sold: JsonUtils.asDouble(json["sold"]) ?? 0,
    delivered: JsonUtils.asDouble(json["delivered"]) ?? 0,
    inVan: JsonUtils.asDouble(json["in_van"]) ?? 0,
    inTransit: JsonUtils.asDouble(json["in_transit"]) ?? 0,
    driverReturned: JsonUtils.asDouble(json["driver_returned"]),
    returned: JsonUtils.asDouble(json["returned"]) ?? 0,
    damaged: JsonUtils.asDouble(json["damaged"]) ?? 0,
    missing: JsonUtils.asDouble(json["missing"]) ?? 0,
  );
}

/// `GET /api/v2/driver/van/trip` → `trip`.
class VanTripModel {
  const VanTripModel({
    required this.id,
    required this.code,
    required this.status,
    this.supplierName = "",
    this.warehouseName = "",
    this.plateNumber,
    this.deliveryRouteId,
    this.maxDiscountPercent = 0,
    this.loadedAt,
    this.returnStartedAt,
    this.returnCode,
    this.cashSalesTotal = 0,
    this.lines = const [],
  });

  final int id;
  final String code;
  final VanTripStatus status;
  final String supplierName;
  final String warehouseName;
  final String? plateNumber;

  /// Route the trip's delivery stops are added to.
  final int? deliveryRouteId;
  final double maxDiscountPercent;
  final DateTime? loadedAt;
  final DateTime? returnStartedAt;

  /// Six digits, kept as a string so a leading zero survives. Only sent while
  /// [status] is returning.
  final String? returnCode;

  /// Cash the driver must hand over.
  final double cashSalesTotal;
  final List<VanTripLine> lines;

  bool get isDraft => status == VanTripStatus.draft;

  bool get isOnRoad => status == VanTripStatus.onRoad;

  bool get isReturning => status == VanTripStatus.returning;

  List<VanTripLine> get sellableLines => [
    for (final line in lines)
      if (line.isSellable) line,
  ];

  double get totalInVan => lines.fold(0, (sum, line) => sum + line.inVan);

  double get totalLoaded => lines.fold(0, (sum, line) => sum + line.loaded);

  VanTripLine? lineForSku(int skuId) {
    for (final line in lines) {
      if (line.skuId == skuId) return line;
    }
    return null;
  }

  factory VanTripModel.fromJson(Map<String, dynamic> json) {
    final supplier = JsonUtils.asMap(json["supplier"]);
    final warehouse = JsonUtils.asMap(json["warehouse"]);
    final vehicle = JsonUtils.asMap(json["vehicle"]);
    final returnCode = JsonUtils.asString(json["return_code"]);
    return VanTripModel(
      id: JsonUtils.asInt(json["id"]) ?? 0,
      code: JsonUtils.asString(json["code"]) ?? "",
      status: VanTripStatusData.fromApi(JsonUtils.asString(json["status"])),
      supplierName: vanLocalizedName(supplier),
      warehouseName: vanLocalizedName(warehouse),
      plateNumber: JsonUtils.asString(vehicle["plate_number"]),
      deliveryRouteId: JsonUtils.asInt(json["delivery_route_id"]),
      maxDiscountPercent: JsonUtils.asDouble(json["max_discount_percent"]) ?? 0,
      loadedAt: JsonUtils.asDate(json["loaded_at"]),
      returnStartedAt: JsonUtils.asDate(json["return_started_at"]),
      returnCode: returnCode == null || returnCode.trim().isEmpty ? null : returnCode.trim(),
      cashSalesTotal: JsonUtils.asDouble(json["cash_sales_total"]) ?? 0,
      lines: [for (final item in JsonUtils.asMapList(json["lines"])) VanTripLine.fromJson(item)],
    );
  }

  /// `trip` of a response, null when absent or `null`.
  static VanTripModel? maybeFrom(dynamic value) {
    final json = JsonUtils.asMapOrNull(value);
    return json == null || json["id"] == null ? null : VanTripModel.fromJson(json);
  }
}
