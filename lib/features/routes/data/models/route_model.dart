import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/tr_or.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/cache_keys.dart';
import 'package:digital_trade_portal_driver/features/my_cars/data/models/vehicle_model.dart';

/// What the driver does at a stop. The internal transfer variants are handled
/// exactly like a pickup / delivery on the road. `return_to_base` is appended
/// by the server when a shipment is canceled after its pickup was done: the
/// goods on the truck go back to the supplier warehouse.
enum StopType { delivery, pickup, internalTransferPickup, internalTransferDelivery, returnToBase }

extension StopTypeData on StopType {
  String get titleKey => switch (this) {
    StopType.delivery => "stop_delivery",
    StopType.pickup => "stop_pickup",
    StopType.internalTransferPickup => "stop_internal_transfer_pickup",
    StopType.internalTransferDelivery => "stop_internal_transfer",
    StopType.returnToBase => "stop_return_to_base",
  };

  /// Closed with `POST /stops/{id}/pickup`.
  bool get isPickup => this == StopType.pickup || this == StopType.internalTransferPickup;

  /// Closed with `POST /stops/{id}/deliver`.
  bool get isDelivery => this == StopType.delivery || this == StopType.internalTransferDelivery;

  /// Closed with `POST /stops/{id}/return`; neither pickup nor deliver accept it.
  bool get isReturn => this == StopType.returnToBase;

  /// Translation key of the button that closes an arrived stop.
  String get confirmKey => switch (this) {
    StopType.pickup || StopType.internalTransferPickup => "confirm_pickup",
    StopType.returnToBase => "confirm_return",
    _ => "confirm_delivery",
  };

  static StopType fromApi(String? value) => switch (value) {
    "pickup" => StopType.pickup,
    "internal_transfer_pickup" => StopType.internalTransferPickup,
    "internal_transfer_delivery" => StopType.internalTransferDelivery,
    "return_to_base" => StopType.returnToBase,
    _ => StopType.delivery,
  };
}

/// Server side stop state machine:
/// `pending → en_route → arrived → completed`, `skipped` from any open state
/// by the driver (or the supplier when rescheduling), `canceled` by the
/// supplier only (shipment, order or route canceled).
enum StopStatus { pending, enRoute, arrived, completed, skipped, canceled }

extension StopStatusData on StopStatus {
  String get titleKey => switch (this) {
    StopStatus.pending => "stop_pending",
    StopStatus.enRoute => "stop_en_route",
    StopStatus.arrived => "stop_arrived",
    StopStatus.completed => "route_completed",
    StopStatus.skipped => "stop_skipped",
    StopStatus.canceled => "stop_canceled",
  };

  Color get color => switch (this) {
    StopStatus.pending => const Color(0xff667085),
    StopStatus.enRoute => AppColors.primarySwatchColor,
    StopStatus.arrived => const Color(0xffE8A317),
    StopStatus.completed => AppColors.secondaryColor,
    StopStatus.skipped => AppColors.red,
    StopStatus.canceled => const Color(0xffB42318),
  };

  String get apiValue => switch (this) {
    StopStatus.pending => "pending",
    StopStatus.enRoute => "en_route",
    StopStatus.arrived => "arrived",
    StopStatus.completed => "completed",
    StopStatus.skipped => "skipped",
    StopStatus.canceled => "canceled",
  };

  /// Completed, skipped or canceled: nothing left to do at this stop. All
  /// three count as done in the route counters.
  bool get isClosed => this == StopStatus.completed || this == StopStatus.skipped || this == StopStatus.canceled;

  /// Closed without the goods moving: shown with a reason, never as a task.
  bool get isDropped => this == StopStatus.skipped || this == StopStatus.canceled;

  bool get canMarkEnRoute => this == StopStatus.pending;

  bool get canArrive => this == StopStatus.pending || this == StopStatus.enRoute;

  bool get canConfirm => this == StopStatus.arrived;

  bool get canSkip => !isClosed;

  static StopStatus fromApi(String? value) => switch (value) {
    "en_route" => StopStatus.enRoute,
    "arrived" => StopStatus.arrived,
    "completed" => StopStatus.completed,
    "skipped" => StopStatus.skipped,
    "canceled" || "cancelled" => StopStatus.canceled,
    _ => StopStatus.pending,
  };
}

/// `draft → assigned → in_progress → completed` (`cancelled` from the fleet).
enum RouteStatus { draft, assigned, inProgress, completed, cancelled }

extension RouteStatusData on RouteStatus {
  String get titleKey => switch (this) {
    RouteStatus.draft => "route_draft",
    RouteStatus.assigned => "route_assigned",
    RouteStatus.inProgress => "route_in_progress",
    RouteStatus.completed => "route_completed",
    RouteStatus.cancelled => "route_cancelled",
  };

  Color get color => switch (this) {
    RouteStatus.draft => const Color(0xff667085),
    RouteStatus.assigned => AppColors.primarySwatchColor,
    RouteStatus.inProgress => const Color(0xffE8A317),
    RouteStatus.completed => AppColors.secondaryColor,
    RouteStatus.cancelled => AppColors.red,
  };

  static RouteStatus fromApi(String? value) => switch (value) {
    "draft" => RouteStatus.draft,
    "in_progress" => RouteStatus.inProgress,
    "completed" => RouteStatus.completed,
    "cancelled" || "canceled" => RouteStatus.cancelled,
    _ => RouteStatus.assigned,
  };
}

String _localizedName(Map<String, dynamic> json, List<String> keys) {
  final language = CacheKeysManger.getUserLanguage();
  for (final key in keys) {
    final localized = JsonUtils.asString(json["${key}_$language"]);
    if (localized != null && localized.trim().isNotEmpty) return localized;
    final plain = JsonUtils.asString(json[key]);
    if (plain != null && plain.trim().isNotEmpty) return plain;
  }
  return "";
}

/// The place a stop happens at.
class BranchModel {
  const BranchModel({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.contactName,
    this.latitude,
    this.longitude,
  });

  final int id;
  final String name;
  final String? address;
  final String? phone;
  final String? contactName;
  final double? latitude;
  final double? longitude;

  factory BranchModel.fromJson(Map<String, dynamic> json) => BranchModel(
    id: JsonUtils.asInt(json["id"]) ?? 0,
    name: _localizedName(json, ["name", "title", "branch_name"]),
    address: JsonUtils.asString(json["address"] ?? json["full_address"] ?? json["street"]),
    phone: JsonUtils.asString(json["phone"] ?? json["mobile"] ?? json["contact_phone"]),
    contactName: JsonUtils.asString(json["contact_name"] ?? json["manager_name"]),
    latitude: JsonUtils.asDouble(json["latitude"] ?? json["lat"]),
    longitude: JsonUtils.asDouble(json["longitude"] ?? json["lng"] ?? json["long"]),
  );
}

class ProductModel {
  const ProductModel({required this.id, required this.name, this.image});

  final int id;
  final String name;
  final String? image;

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
    id: JsonUtils.asInt(json["id"]) ?? 0,
    name: _localizedName(json, ["name", "title", "product_name"]),
    image: JsonUtils.asString(json["image"] ?? json["thumbnail"]),
  );
}

class SkuModel {
  const SkuModel({required this.id, this.code, this.barcode, this.product, this.unit});

  final int id;

  /// The SKU code — an all digit code arrives as a number, kept as text.
  final String? code;
  final String? barcode;
  final ProductModel? product;
  final String? unit;

  factory SkuModel.fromJson(Map<String, dynamic> json) {
    final product = JsonUtils.asMapOrNull(json["product"]);
    return SkuModel(
      id: JsonUtils.asInt(json["id"]) ?? 0,
      code: JsonUtils.asString(json["sku"] ?? json["code"] ?? json["sku_code"]),
      barcode: JsonUtils.asString(json["barcode"]),
      product: product == null ? null : ProductModel.fromJson(product),
      unit: JsonUtils.asString(json["unit"] ?? json["unit_name"]),
    );
  }
}

/// One `delivery_stop_items` line.
class StopItemModel {
  const StopItemModel({
    required this.id,
    required this.expectedQty,
    this.loadedQty,
    this.deliveredQty,
    this.returnedQty,
    this.damagedQty,
    this.barcodeRequired = false,
    this.barcodeScanned = false,
    this.barcodeMatch = false,
    this.barcodeValue,
    this.expectedBarcode,
    this.conditionNotes,
    this.sku,
    this.name,
  });

  final int id;
  final double expectedQty;
  final double? loadedQty;
  final double? deliveredQty;
  final double? returnedQty;
  final double? damagedQty;

  /// The line cannot be confirmed until `barcode/verify` matched it.
  final bool barcodeRequired;
  final bool barcodeScanned;
  final bool barcodeMatch;
  final String? barcodeValue;

  /// The package barcode (EAN/GTIN) the supplier saved on the SKU, `null`
  /// when it has none. The SKU code and the order number are not barcodes.
  final String? expectedBarcode;
  final String? conditionNotes;
  final SkuModel? sku;

  /// Item level name when the line carries one directly.
  final String? name;

  String get productName {
    final fromSku = sku?.product?.name;
    if (fromSku != null && fromSku.isNotEmpty) return fromSku;
    if (name != null && name!.isNotEmpty) return name!;
    return sku?.code ?? "#$id";
  }

  /// The code a scan has to produce: `expected_barcode` on the line, else
  /// the SKU's own barcode on older payloads.
  String? get barcode {
    final expected = expectedBarcode?.trim();
    if (expected != null && expected.isNotEmpty) return expected;
    final fromSku = sku?.barcode?.trim();
    return fromSku == null || fromSku.isEmpty ? null : fromSku;
  }

  /// What the delivery split has to add up to: the quantity confirmed at
  /// pickup, or the expected one when no pickup was recorded (the server
  /// applies the same fallback when `loaded_qty` is 0).
  double get deliverableQty {
    final loaded = loadedQty;
    return loaded != null && loaded > 0 ? loaded : expectedQty;
  }

  /// Loaded less than ordered at pickup.
  bool get isShortLoaded => loadedQty != null && loadedQty! > 0 && loadedQty! < expectedQty;

  /// A required scan that has not matched yet blocks pickup / delivery.
  bool get needsBarcodeScan => barcodeRequired && !barcodeMatch;

  factory StopItemModel.fromJson(Map<String, dynamic> json) {
    final sku = JsonUtils.asMapOrNull(json["sku"]);
    return StopItemModel(
      id: JsonUtils.asInt(json["id"]) ?? 0,
      expectedQty: JsonUtils.asDouble(json["expected_qty"]) ?? 0,
      loadedQty: JsonUtils.asDouble(json["loaded_qty"]),
      deliveredQty: JsonUtils.asDouble(json["delivered_qty"]),
      returnedQty: JsonUtils.asDouble(json["returned_qty"]),
      damagedQty: JsonUtils.asDouble(json["damaged_qty"]),
      barcodeRequired: JsonUtils.asBool(json["barcode_required"]),
      barcodeScanned: JsonUtils.asBool(json["barcode_scanned"]),
      barcodeMatch: JsonUtils.asBool(json["barcode_match"]),
      barcodeValue: JsonUtils.asString(json["barcode_value"]),
      expectedBarcode: JsonUtils.asString(json["expected_barcode"]),
      conditionNotes: JsonUtils.asString(json["condition_notes"]),
      sku: sku == null ? null : SkuModel.fromJson(sku),
      name: JsonUtils.asString(json["name"] ?? json["product_name"]),
    );
  }

  StopItemModel copyWith({
    double? loadedQty,
    double? deliveredQty,
    double? returnedQty,
    double? damagedQty,
    bool? barcodeScanned,
    bool? barcodeMatch,
    String? barcodeValue,
    String? conditionNotes,
  }) {
    return StopItemModel(
      id: id,
      expectedQty: expectedQty,
      loadedQty: loadedQty ?? this.loadedQty,
      deliveredQty: deliveredQty ?? this.deliveredQty,
      returnedQty: returnedQty ?? this.returnedQty,
      damagedQty: damagedQty ?? this.damagedQty,
      barcodeRequired: barcodeRequired,
      barcodeScanned: barcodeScanned ?? this.barcodeScanned,
      barcodeMatch: barcodeMatch ?? this.barcodeMatch,
      barcodeValue: barcodeValue ?? this.barcodeValue,
      expectedBarcode: expectedBarcode,
      conditionNotes: conditionNotes ?? this.conditionNotes,
      sku: sku,
      name: name,
    );
  }
}

/// A `delivery_proofs` row attached to a stop.
class ProofModel {
  const ProofModel({
    required this.id,
    this.proofType,
    this.proofCategory,
    this.filePath,
    this.fileUrl,
    this.capturedAt,
  });

  final int id;
  final String? proofType;
  final String? proofCategory;
  final String? filePath;
  final String? fileUrl;
  final DateTime? capturedAt;

  /// Address to show the picture from. Never built from [filePath]: on
  /// production files live in cloud storage and the path is already absolute.
  String? get displayUrl {
    if (fileUrl != null && fileUrl!.isNotEmpty) return fileUrl;
    if (filePath != null && filePath!.startsWith("http")) return filePath;
    return null;
  }

  factory ProofModel.fromJson(Map<String, dynamic> json) => ProofModel(
    id: JsonUtils.asInt(json["id"]) ?? 0,
    proofType: JsonUtils.asString(json["proof_type"]),
    proofCategory: JsonUtils.asString(json["proof_category"]),
    filePath: JsonUtils.asString(json["file_path"]),
    fileUrl: JsonUtils.asString(json["file_url"]),
    capturedAt: JsonUtils.asDate(json["captured_at"] ?? json["created_at"]),
  );
}

class RouteStop {
  const RouteStop({
    required this.id,
    required this.stopOrder,
    required this.type,
    required this.status,
    this.branch,
    this.items = const [],
    this.proofs = const [],
    this.notes,
    this.referenceType,
    this.referenceId,
    this.plannedArrival,
    this.actualArrival,
    this.failureReason,
    double? latitude,
    double? longitude,
  }) : _latitude = latitude,
       _longitude = longitude;

  final int id;
  final int stopOrder;
  final StopType type;
  final StopStatus status;
  final BranchModel? branch;
  final List<StopItemModel> items;
  final List<ProofModel> proofs;
  final String? notes;

  /// `delivery_note` stops have a goods receipt to poll after delivery.
  final String? referenceType;
  final int? referenceId;
  final DateTime? plannedArrival;
  final DateTime? actualArrival;
  final String? failureReason;
  final double? _latitude;
  final double? _longitude;

  String get name => branch?.name.isNotEmpty == true ? branch!.name : "#$stopOrder";

  /// Where the stop sits on the map: the stop's own coordinates, else the
  /// branch's.
  double? get latitude => _latitude ?? branch?.latitude;

  double? get longitude => _longitude ?? branch?.longitude;

  bool get hasLocation => latitude != null && longitude != null;

  bool get isPickup => type.isPickup;

  bool get isReturn => type.isReturn;

  bool get hasDeliveryNote => referenceType == "delivery_note";

  bool get isCanceled => status == StopStatus.canceled;

  /// Closed by the supplier, not the driver: the shipment / order / route
  /// was canceled (`canceled`) or the shipment was moved to another route
  /// (`skipped`, `rescheduled_by_supplier`).
  bool get isClosedBySupplier =>
      isCanceled || (status == StopStatus.skipped && failureReason == "rescheduled_by_supplier");

  /// `failure_reason` codes the supplier side writes on a closed stop.
  static const Set<String> supplierReasons = {"shipment_canceled", "rescheduled_by_supplier", "route_canceled"};

  /// Human text for `failure_reason`: known codes (supplier cancellations,
  /// the app's own reason codes) are translated, free text is shown as is.
  String? get failureReasonLabel {
    final reason = failureReason?.trim();
    if (reason == null || reason.isEmpty) return null;
    if (supplierReasons.contains(reason)) return tr("failure_$reason");
    if (reason == "skipped_by_driver") return tr("failure_skipped_by_driver");
    return trOr("skip_$reason", reason);
  }

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    final branch = JsonUtils.asMapOrNull(json["branch"]);
    return RouteStop(
      id: JsonUtils.asInt(json["id"]) ?? 0,
      stopOrder: JsonUtils.asInt(json["stop_order"]) ?? 0,
      type: StopTypeData.fromApi(JsonUtils.asString(json["stop_type"])),
      status: StopStatusData.fromApi(JsonUtils.asString(json["status"])),
      branch: branch == null ? null : BranchModel.fromJson(branch),
      items: [for (final item in JsonUtils.asMapList(json["items"])) StopItemModel.fromJson(item)],
      proofs: [for (final item in JsonUtils.asMapList(json["proofs"])) ProofModel.fromJson(item)],
      notes: JsonUtils.asString(json["notes"]),
      referenceType: JsonUtils.asString(json["reference_type"]),
      referenceId: JsonUtils.asInt(json["reference_id"]),
      plannedArrival: JsonUtils.asDate(json["planned_arrival_time"] ?? json["eta"]),
      actualArrival: JsonUtils.asDate(json["actual_arrival_time"]),
      failureReason: JsonUtils.asString(json["failure_reason"]),
      latitude: JsonUtils.asDouble(json["latitude"]),
      longitude: JsonUtils.asDouble(json["longitude"]),
    );
  }

  RouteStop copyWith({StopStatus? status, List<StopItemModel>? items, List<ProofModel>? proofs, String? notes}) {
    return RouteStop(
      id: id,
      stopOrder: stopOrder,
      type: type,
      status: status ?? this.status,
      branch: branch,
      items: items ?? this.items,
      proofs: proofs ?? this.proofs,
      notes: notes ?? this.notes,
      referenceType: referenceType,
      referenceId: referenceId,
      plannedArrival: plannedArrival,
      actualArrival: actualArrival,
      failureReason: failureReason,
      latitude: _latitude,
      longitude: _longitude,
    );
  }

  /// Merges a stop the server sent back (after arrive / pickup / deliver)
  /// over this one, keeping branch and items when the response omits them.
  RouteStop mergeServer(Map<String, dynamic> json) {
    final fresh = RouteStop.fromJson(json);
    return RouteStop(
      id: id,
      stopOrder: fresh.stopOrder == 0 ? stopOrder : fresh.stopOrder,
      type: json["stop_type"] == null ? type : fresh.type,
      status: json["status"] == null ? status : fresh.status,
      branch: fresh.branch ?? branch,
      items: fresh.items.isEmpty ? items : fresh.items,
      proofs: fresh.proofs.isEmpty ? proofs : fresh.proofs,
      notes: fresh.notes ?? notes,
      referenceType: fresh.referenceType ?? referenceType,
      referenceId: fresh.referenceId ?? referenceId,
      plannedArrival: fresh.plannedArrival ?? plannedArrival,
      actualArrival: fresh.actualArrival ?? actualArrival,
      failureReason: fresh.failureReason ?? failureReason,
      latitude: fresh._latitude ?? _latitude,
      longitude: fresh._longitude ?? _longitude,
    );
  }
}

class RouteModel {
  const RouteModel({
    required this.id,
    required this.code,
    required this.date,
    required this.status,
    this.hasTime = false,
    this.distanceKm,
    this.stops = const [],
    this.vehicle,
    this.totalStops,
    this.completedStops,
    this.actualStart,
    this.actualEnd,
    this.notes,
  });

  final int id;
  final String code;

  /// `route_date`, combined with the planned start time when the row has one.
  final DateTime date;
  final bool hasTime;
  final RouteStatus status;
  final double? distanceKm;
  final List<RouteStop> stops;
  final VehicleModel? vehicle;
  final int? totalStops;
  final int? completedStops;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final String? notes;

  int get stopsTotal => stops.isNotEmpty ? stops.length : (totalStops ?? 0);

  int get stopsDone => stops.isNotEmpty ? stops.where((stop) => stop.status.isClosed).length : (completedStops ?? 0);

  bool get isCompleted => status == RouteStatus.completed;

  bool get isInProgress => status == RouteStatus.inProgress;

  bool get isAssigned => status == RouteStatus.assigned;

  /// Assigned or in progress and dated before today.
  bool get isLate {
    if (isCompleted || status == RouteStatus.cancelled) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(date.year, date.month, date.day).isBefore(today);
  }

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final rawDate = JsonUtils.asString(json["route_date"]) ?? "";
    final rawTime = JsonUtils.asString(json["planned_start_time"] ?? json["start_time"]);
    DateTime date = JsonUtils.asDate(rawDate) ?? DateTime.now();
    bool hasTime = false;

    if (rawTime != null && rawTime.trim().isNotEmpty) {
      // "08:30:00" or a full timestamp.
      final asFull = JsonUtils.asDate(rawTime) ?? JsonUtils.asDate("${JsonUtils.formatServerDate(date)} $rawTime");
      if (asFull != null) {
        date = asFull;
        hasTime = true;
      }
    }

    final vehicle = JsonUtils.asMapOrNull(json["vehicle"]);
    return RouteModel(
      id: JsonUtils.asInt(json["id"]) ?? 0,
      code: JsonUtils.asString(json["code"] ?? json["route_code"]) ?? "",
      date: date,
      hasTime: hasTime,
      status: RouteStatusData.fromApi(JsonUtils.asString(json["status"])),
      distanceKm: JsonUtils.asDouble(
        json["actual_distance_km"] ?? json["planned_distance_km"] ?? json["distance_km"] ?? json["total_distance_km"],
      ),
      stops: [for (final item in JsonUtils.asMapList(json["stops"])) RouteStop.fromJson(item)],
      vehicle: vehicle == null ? null : VehicleModel.fromJson(vehicle),
      totalStops: JsonUtils.asInt(json["total_stops"]),
      completedStops: JsonUtils.asInt(json["completed_stops"]),
      actualStart: JsonUtils.asDate(json["actual_start_time"]),
      actualEnd: JsonUtils.asDate(json["actual_end_time"]),
      notes: JsonUtils.asString(json["notes"]),
    );
  }

  static List<RouteModel> listFromJson(dynamic value) => [
    for (final item in JsonUtils.asMapList(value)) RouteModel.fromJson(item),
  ];

  RouteModel copyWith({RouteStatus? status, List<RouteStop>? stops, int? completedStops, double? distanceKm}) {
    return RouteModel(
      id: id,
      code: code,
      date: date,
      hasTime: hasTime,
      status: status ?? this.status,
      distanceKm: distanceKm ?? this.distanceKm,
      stops: stops ?? this.stops,
      vehicle: vehicle,
      totalStops: totalStops,
      completedStops: completedStops ?? this.completedStops,
      actualStart: actualStart,
      actualEnd: actualEnd,
      notes: notes,
    );
  }

  /// Replaces one stop by id.
  RouteModel withStop(RouteStop stop) => copyWith(stops: [for (final item in stops) item.id == stop.id ? stop : item]);
}

/// `eta` block of the today route, only present while the route is in
/// progress. Its exact shape depends on the backend build; the raw map is
/// kept and the common fields are read tolerantly.
class RouteEtaModel {
  const RouteEtaModel({required this.raw});

  final Map<String, dynamic> raw;

  int? get nextStopId => JsonUtils.asInt(raw["next_stop_id"] ?? raw["stop_id"]);

  int? get etaMinutes => JsonUtils.asInt(raw["eta_minutes"] ?? raw["minutes"] ?? raw["duration_minutes"]);

  double? get distanceKm => JsonUtils.asDouble(raw["distance_km"] ?? raw["remaining_distance_km"]);

  DateTime? get estimatedArrival => JsonUtils.asDate(raw["estimated_arrival"] ?? raw["eta"] ?? raw["arrival_time"]);
}

/// `GET /api/v2/driver/today_route`.
class TodayRouteModel {
  const TodayRouteModel({this.route, this.eta, this.lateRoutes = const [], this.upcomingRoutes = const []});

  final RouteModel? route;
  final RouteEtaModel? eta;
  final List<RouteModel> lateRoutes;
  final List<RouteModel> upcomingRoutes;

  bool get isEmpty => route == null && lateRoutes.isEmpty && upcomingRoutes.isEmpty;

  /// Every route the home card lists: today's first, then overdue, then next.
  List<RouteModel> get allRoutes => [?route, ...lateRoutes, ...upcomingRoutes];

  factory TodayRouteModel.fromJson(Map<String, dynamic> json) {
    final route = JsonUtils.asMapOrNull(json["route"]);
    final eta = JsonUtils.asMapOrNull(json["eta"]);
    return TodayRouteModel(
      route: route == null || route["id"] == null ? null : RouteModel.fromJson(route),
      eta: eta == null ? null : RouteEtaModel(raw: eta),
      lateRoutes: RouteModel.listFromJson(json["late_routes"]),
      upcomingRoutes: RouteModel.listFromJson(json["upcoming_routes"]),
    );
  }

  TodayRouteModel copyWith({RouteModel? route, bool clearRoute = false, List<RouteModel>? lateRoutes}) {
    return TodayRouteModel(
      route: clearRoute ? null : route ?? this.route,
      eta: eta,
      lateRoutes: lateRoutes ?? this.lateRoutes,
      upcomingRoutes: upcomingRoutes,
    );
  }

  /// Applies an updated route wherever it lives (today, late or upcoming).
  TodayRouteModel withRoute(RouteModel updated) {
    List<RouteModel> replace(List<RouteModel> list) => [
      for (final item in list) item.id == updated.id ? updated : item,
    ];
    return TodayRouteModel(
      route: route?.id == updated.id ? updated : route,
      eta: eta,
      lateRoutes: replace(lateRoutes),
      upcomingRoutes: replace(upcomingRoutes),
    );
  }

  RouteModel? routeById(int id) {
    for (final item in allRoutes) {
      if (item.id == id) return item;
    }
    return null;
  }
}

/// `GET /api/v2/driver/end_of_day_summary`.
class EndOfDaySummaryModel {
  const EndOfDaySummaryModel({
    this.date,
    this.driverName,
    this.routeCode,
    this.status,
    this.totalStops = 0,
    this.completedStops = 0,
    this.skippedStops = 0,
    this.canceledStops = 0,
    this.pickupsDone = 0,
    this.deliveriesDone = 0,
    this.totalItems = 0,
    this.totalDeliveredQty = 0,
    this.totalReturnedQty = 0,
    this.totalDamagedQty = 0,
    this.incidentsCount = 0,
    this.distanceKm,
    this.workingMinutes,
  });

  final String? date;
  final String? driverName;
  final String? routeCode;
  final String? status;
  final int totalStops;
  final int completedStops;
  final int skippedStops;

  /// Stops the supplier canceled (shipment, order or route).
  final int canceledStops;
  final int pickupsDone;
  final int deliveriesDone;
  final int totalItems;
  final double totalDeliveredQty;
  final double totalReturnedQty;
  final double totalDamagedQty;
  final int incidentsCount;
  final double? distanceKm;
  final int? workingMinutes;

  factory EndOfDaySummaryModel.fromJson(Map<String, dynamic> json) {
    final summary = JsonUtils.asMap(json["summary"]);
    return EndOfDaySummaryModel(
      date: JsonUtils.asString(json["date"]),
      driverName: JsonUtils.asString(json["driver_name"]),
      routeCode: JsonUtils.asString(json["route_code"]),
      status: JsonUtils.asString(json["status"]),
      totalStops: JsonUtils.asInt(summary["total_stops"]) ?? 0,
      completedStops: JsonUtils.asInt(summary["completed_stops"]) ?? 0,
      skippedStops: JsonUtils.asInt(summary["skipped_stops"]) ?? 0,
      canceledStops: JsonUtils.asInt(summary["canceled_stops"]) ?? 0,
      pickupsDone: JsonUtils.asInt(summary["pickups_done"]) ?? 0,
      deliveriesDone: JsonUtils.asInt(summary["deliveries_done"]) ?? 0,
      totalItems: JsonUtils.asInt(summary["total_items"]) ?? 0,
      totalDeliveredQty: JsonUtils.asDouble(summary["total_delivered_qty"]) ?? 0,
      totalReturnedQty: JsonUtils.asDouble(summary["total_returned_qty"]) ?? 0,
      totalDamagedQty: JsonUtils.asDouble(summary["total_damaged_qty"]) ?? 0,
      incidentsCount: JsonUtils.asInt(summary["incidents_count"]) ?? 0,
      distanceKm: JsonUtils.asDouble(summary["distance_km"]),
      workingMinutes: JsonUtils.asInt(summary["working_minutes"]),
    );
  }
}

/// Standard Laravel paginator envelope of `GET /api/v2/driver/history`.
class RouteHistoryPage {
  const RouteHistoryPage({required this.routes, required this.currentPage, required this.lastPage, this.total});

  final List<RouteModel> routes;
  final int currentPage;
  final int lastPage;
  final int? total;

  bool get hasMore => currentPage < lastPage;

  factory RouteHistoryPage.fromJson(Map<String, dynamic> json) {
    // `{data:[…], current_page, last_page}` or `{data:{data:[…], …}}`.
    final inner = json["data"] is Map ? JsonUtils.asMap(json["data"]) : json;
    return RouteHistoryPage(
      routes: RouteModel.listFromJson(inner["data"]),
      currentPage: JsonUtils.asInt(inner["current_page"]) ?? 1,
      lastPage: JsonUtils.asInt(inner["last_page"]) ?? 1,
      total: JsonUtils.asInt(inner["total"]),
    );
  }
}
