import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_trip_model.dart';

class VanTraderBranch {
  const VanTraderBranch({required this.id, required this.name, this.latitude, this.longitude, this.isDefault = false});

  final int id;
  final String name;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  factory VanTraderBranch.fromJson(Map<String, dynamic> json) => VanTraderBranch(
    id: JsonUtils.asInt(json["id"]) ?? 0,
    name: vanLocalizedName(json),
    latitude: JsonUtils.asDouble(json["latitude"]),
    longitude: JsonUtils.asDouble(json["longitude"]),
    isDefault: JsonUtils.asBool(json["is_default"]),
  );
}

class VanOpenOrderLine {
  const VanOpenOrderLine({required this.purchaseOrderLineId, required this.skuId, required this.outstandingQty});

  final int purchaseOrderLineId;
  final int skuId;
  final double outstandingQty;

  factory VanOpenOrderLine.fromJson(Map<String, dynamic> json) => VanOpenOrderLine(
    purchaseOrderLineId: JsonUtils.asInt(json["purchase_order_line_id"]) ?? 0,
    skuId: JsonUtils.asInt(json["sku_id"]) ?? 0,
    outstandingQty: JsonUtils.asDouble(json["outstanding_qty"]) ?? 0,
  );
}

/// An order the trader placed before, which the van can fill now.
class VanOpenOrder {
  const VanOpenOrder({required this.id, required this.code, this.status, this.deliveryBranchId, this.lines = const []});

  final int id;
  final String code;
  final String? status;
  final int? deliveryBranchId;
  final List<VanOpenOrderLine> lines;

  factory VanOpenOrder.fromJson(Map<String, dynamic> json) => VanOpenOrder(
    id: JsonUtils.asInt(json["id"]) ?? 0,
    code: JsonUtils.asString(json["code"]) ?? "",
    status: JsonUtils.asString(json["status"]),
    deliveryBranchId: JsonUtils.asInt(json["delivery_branch_id"]),
    lines: [for (final item in JsonUtils.asMapList(json["lines"])) VanOpenOrderLine.fromJson(item)],
  );
}

/// `GET /driver/van/trips/{trip_id}/traders` → one registered trader.
class VanTrader {
  const VanTrader({
    required this.organizationId,
    required this.name,
    this.businessRelationshipId,
    this.branches = const [],
    this.openOrders = const [],
  });

  final int organizationId;
  final String name;
  final int? businessRelationshipId;
  final List<VanTraderBranch> branches;
  final List<VanOpenOrder> openOrders;

  VanTraderBranch? get defaultBranch {
    for (final branch in branches) {
      if (branch.isDefault) return branch;
    }
    return branches.firstOrNull;
  }

  factory VanTrader.fromJson(Map<String, dynamic> json) => VanTrader(
    organizationId: JsonUtils.asInt(json["organization_id"]) ?? 0,
    name: vanLocalizedName(json, arKey: "name"),
    businessRelationshipId: JsonUtils.asInt(json["business_relationship_id"]),
    branches: [for (final item in JsonUtils.asMapList(json["branches"])) VanTraderBranch.fromJson(item)],
    openOrders: [for (final item in JsonUtils.asMapList(json["open_orders"])) VanOpenOrder.fromJson(item)],
  );
}

/// One line of a van delivery: `purchase_order_line_id` when filling an
/// order, `sku_id` for a spot order.
class VanDeliveryLine {
  const VanDeliveryLine.order({required int this.purchaseOrderLineId, required this.qty}) : skuId = null;

  const VanDeliveryLine.spot({required int this.skuId, required this.qty}) : purchaseOrderLineId = null;

  final int? purchaseOrderLineId;
  final int? skuId;
  final double qty;

  Map<String, dynamic> toJson() => {
    "purchase_order_line_id": ?purchaseOrderLineId,
    "sku_id": ?skuId,
    "qty": vanQty(qty),
  };
}

/// `POST /driver/van/trips/{trip_id}/deliveries`. A null [purchaseOrderId]
/// is a spot order; a null [paymentTermId] means cash on delivery.
class VanDeliveryRequest {
  const VanDeliveryRequest({
    required this.traderBranchId,
    required this.lines,
    this.purchaseOrderId,
    this.paymentTermId,
  });

  final int? purchaseOrderId;
  final int traderBranchId;
  final int? paymentTermId;
  final List<VanDeliveryLine> lines;

  bool get isSpotOrder => purchaseOrderId == null;

  Map<String, dynamic> toJson() => {
    "purchase_order_id": ?purchaseOrderId,
    "trader_branch_id": traderBranchId,
    if (isSpotOrder) "payment_term_id": paymentTermId,
    "lines": [for (final line in lines) line.toJson()],
  };
}

/// `van_delivery_created`: a normal delivery stop on the trip's route,
/// finished with the existing arrive → handoff → deliver flow.
class VanDeliveryResult {
  const VanDeliveryResult({required this.stop, this.deliveryRouteId, this.trip});

  final RouteStop stop;
  final int? deliveryRouteId;
  final VanTripModel? trip;
}
