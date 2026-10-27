import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/uuid.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_trip_model.dart';

enum VanPaymentMethod { cash, transfer }

extension VanPaymentMethodData on VanPaymentMethod {
  String get apiValue => switch (this) {
    VanPaymentMethod.cash => "cash",
    VanPaymentMethod.transfer => "transfer",
  };

  String get titleKey => switch (this) {
    VanPaymentMethod.cash => "van_payment_cash",
    VanPaymentMethod.transfer => "van_payment_transfer",
  };

  static VanPaymentMethod fromApi(String? value) =>
      value == "transfer" ? VanPaymentMethod.transfer : VanPaymentMethod.cash;
}

/// The simplified tax invoice the server issues for a walk-in sale. Anyone
/// with [shareUrl] can open it without logging in.
class VanInvoice {
  const VanInvoice({required this.id, required this.invoiceNo, this.title, this.zatcaQr, this.shareUrl});

  final int id;
  final String invoiceNo;
  final String? title;

  /// Base64 TLV, rendered as a QR image.
  final String? zatcaQr;
  final String? shareUrl;

  factory VanInvoice.fromJson(Map<String, dynamic> json) => VanInvoice(
    id: JsonUtils.asInt(json["id"]) ?? 0,
    invoiceNo: JsonUtils.asString(json["invoice_no"]) ?? "",
    title: JsonUtils.asString(json["title"]),
    zatcaQr: JsonUtils.asString(json["zatca_qr"]),
    shareUrl: JsonUtils.asString(json["share_url"]),
  );
}

class VanSaleLine {
  const VanSaleLine({
    required this.skuId,
    required this.name,
    required this.qty,
    this.unitPrice = 0,
    this.discountValue = 0,
    this.taxValue = 0,
    this.lineTotal = 0,
  });

  final int skuId;
  final String name;
  final double qty;
  final double unitPrice;
  final double discountValue;
  final double taxValue;
  final double lineTotal;

  factory VanSaleLine.fromJson(Map<String, dynamic> json) => VanSaleLine(
    skuId: JsonUtils.asInt(json["sku_id"]) ?? 0,
    name: JsonUtils.asString(json["name"]) ?? "",
    qty: JsonUtils.asDouble(json["qty"]) ?? 0,
    unitPrice: JsonUtils.asDouble(json["unit_price"]) ?? 0,
    discountValue: JsonUtils.asDouble(json["discount_value"]) ?? 0,
    taxValue: JsonUtils.asDouble(json["tax_value"]) ?? 0,
    lineTotal: JsonUtils.asDouble(json["line_total"]) ?? 0,
  );
}

/// A walk-in sale as the server recorded it; the totals are the server's.
class VanSaleModel {
  const VanSaleModel({
    required this.id,
    required this.buyerName,
    this.buyerPhone,
    this.paymentMethod = VanPaymentMethod.cash,
    this.subtotal = 0,
    this.taxTotal = 0,
    this.grandTotal = 0,
    this.lines = const [],
    this.invoice,
    this.createdAt,
  });

  final int id;
  final String buyerName;

  /// Kept as a string so a leading zero survives.
  final String? buyerPhone;
  final VanPaymentMethod paymentMethod;
  final double subtotal;
  final double taxTotal;
  final double grandTotal;
  final List<VanSaleLine> lines;
  final VanInvoice? invoice;
  final DateTime? createdAt;

  factory VanSaleModel.fromJson(Map<String, dynamic> json) {
    final invoice = JsonUtils.asMapOrNull(json["invoice"]);
    final phone = JsonUtils.asString(json["buyer_phone"]);
    return VanSaleModel(
      id: JsonUtils.asInt(json["id"]) ?? 0,
      buyerName: JsonUtils.asString(json["buyer_name"]) ?? "",
      buyerPhone: phone == null || phone.trim().isEmpty ? null : phone.trim(),
      paymentMethod: VanPaymentMethodData.fromApi(JsonUtils.asString(json["payment_method"])),
      subtotal: JsonUtils.asDouble(json["subtotal"]) ?? 0,
      taxTotal: JsonUtils.asDouble(json["tax_total"]) ?? 0,
      grandTotal: JsonUtils.asDouble(json["grand_total"]) ?? 0,
      lines: [for (final item in JsonUtils.asMapList(json["lines"])) VanSaleLine.fromJson(item)],
      invoice: invoice == null ? null : VanInvoice.fromJson(invoice),
      createdAt: JsonUtils.asDate(json["created_at"]),
    );
  }
}

/// One line of a sale the driver is entering; [name] and [unitPrice] are
/// kept for the pending list and never sent.
class VanSaleRequestLine {
  const VanSaleRequestLine({required this.skuId, required this.qty, this.name = "", this.unitPrice = 0});

  final int skuId;
  final double qty;
  final String name;
  final double unitPrice;

  Map<String, dynamic> toApiJson() => {"sku_id": skuId, "qty": vanQty(qty)};

  Map<String, dynamic> toStorageJson() => {...toApiJson(), "name": name, "unit_price": unitPrice};

  factory VanSaleRequestLine.fromStorageJson(Map<String, dynamic> json) => VanSaleRequestLine(
    skuId: JsonUtils.asInt(json["sku_id"]) ?? 0,
    qty: JsonUtils.asDouble(json["qty"]) ?? 0,
    name: JsonUtils.asString(json["name"]) ?? "",
    unitPrice: JsonUtils.asDouble(json["unit_price"]) ?? 0,
  );
}

/// `POST /driver/van/trips/{trip_id}/sales` body. [clientUuid] is generated
/// once: a retry returns the same sale, never a second invoice.
class VanSaleRequest {
  VanSaleRequest({
    required this.tripId,
    required this.buyerName,
    required this.lines,
    this.buyerPhone,
    this.buyerVatNo,
    this.paymentMethod = VanPaymentMethod.cash,
    this.discountPercent = 0,
    this.latitude,
    this.longitude,
    String? clientUuid,
    DateTime? createdAt,
    this.lastError,
  }) : clientUuid = clientUuid ?? Uuid.v4(),
       createdAt = createdAt ?? DateTime.now();

  final int tripId;
  final String buyerName;
  final String? buyerPhone;
  final String? buyerVatNo;
  final VanPaymentMethod paymentMethod;
  final double discountPercent;
  final List<VanSaleRequestLine> lines;
  final double? latitude;
  final double? longitude;
  final String clientUuid;
  final DateTime createdAt;
  String? lastError;

  /// Before VAT and discount, for the pending list only.
  double get estimatedSubtotal => lines.fold(0, (sum, line) => sum + line.qty * line.unitPrice);

  Map<String, dynamic> toApiJson() => {
    "buyer_name": buyerName,
    if (buyerPhone != null && buyerPhone!.isNotEmpty) "buyer_phone": buyerPhone,
    if (buyerVatNo != null && buyerVatNo!.isNotEmpty) "buyer_vat_no": buyerVatNo,
    "payment_method": paymentMethod.apiValue,
    "discount_percent": vanQty(discountPercent),
    "lines": [for (final line in lines) line.toApiJson()],
    "latitude": ?latitude,
    "longitude": ?longitude,
    "client_uuid": clientUuid,
  };

  Map<String, dynamic> toStorageJson() => {
    ...toApiJson(),
    "trip_id": tripId,
    "lines": [for (final line in lines) line.toStorageJson()],
    "created_at": createdAt.toIso8601String(),
    if (lastError != null) "last_error": lastError,
  };

  static VanSaleRequest? fromStorageJson(Map<String, dynamic> json) {
    final tripId = JsonUtils.asInt(json["trip_id"]);
    final uuid = JsonUtils.asString(json["client_uuid"]);
    if (tripId == null || uuid == null) return null;
    return VanSaleRequest(
      tripId: tripId,
      buyerName: JsonUtils.asString(json["buyer_name"]) ?? "",
      buyerPhone: JsonUtils.asString(json["buyer_phone"]),
      buyerVatNo: JsonUtils.asString(json["buyer_vat_no"]),
      paymentMethod: VanPaymentMethodData.fromApi(JsonUtils.asString(json["payment_method"])),
      discountPercent: JsonUtils.asDouble(json["discount_percent"]) ?? 0,
      lines: [for (final item in JsonUtils.asMapList(json["lines"])) VanSaleRequestLine.fromStorageJson(item)],
      latitude: JsonUtils.asDouble(json["latitude"]),
      longitude: JsonUtils.asDouble(json["longitude"]),
      clientUuid: uuid,
      createdAt: JsonUtils.asDate(json["created_at"]),
      lastError: JsonUtils.asString(json["last_error"]),
    );
  }
}

/// `van_sale_recorded`: the sale and the trip with its stock moved.
class VanSaleResult {
  const VanSaleResult({required this.sale, this.trip});

  final VanSaleModel sale;
  final VanTripModel? trip;
}
