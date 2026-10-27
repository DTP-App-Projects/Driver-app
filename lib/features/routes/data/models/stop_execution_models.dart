import 'dart:io';

import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';

/// Response of `POST /driver/stops/{id}/arrive`. For a delivery stop it also
/// carries the receiver OTP dispatch result and the seals to expect.
class ArrivalResult {
  const ArrivalResult({
    required this.stop,
    this.otpRequired = false,
    this.otpSentTo,
    this.otpExpiresAt,
    this.otpError,
    this.otpChannels = const [],
    this.expectedSealNumbers = const [],
  });

  final RouteStop stop;

  /// The server generated the handoff code and sent it to the trader: the
  /// delivery needs the trader's QR, the code or an audited bypass.
  final bool otpRequired;
  final String? otpSentTo;
  final DateTime? otpExpiresAt;

  /// Set when the SMS could not be sent; the manual path stays open.
  final String? otpError;

  /// Where the code went, e.g. `push`, `sms`.
  final List<String> otpChannels;
  final List<String> expectedSealNumbers;

  factory ArrivalResult.fromJson(Map<String, dynamic> json, {required RouteStop current}) {
    final stopJson = JsonUtils.asMapOrNull(json["stop"]);
    return ArrivalResult(
      stop: stopJson == null ? current.copyWith(status: StopStatus.arrived) : current.mergeServer(stopJson),
      otpRequired: JsonUtils.asBool(json["otp_required"]),
      otpSentTo: JsonUtils.asString(json["otp_sent_to"]),
      otpExpiresAt: JsonUtils.asDate(json["otp_expires_at"]),
      otpError: JsonUtils.asString(json["otp_error"]),
      otpChannels: JsonUtils.asStringList(json["otp_channels"]),
      expectedSealNumbers: JsonUtils.asStringList(json["expected_seal_numbers"]),
    );
  }
}

/// Outcome of `handoff/verify`, `otp/verify` and `otp/resend`, and the
/// `handoff` object a refused `/deliver` carries.
class OtpResult {
  const OtpResult({
    required this.success,
    this.msg,
    this.attemptsRemaining,
    this.requiresGeneration = false,
    this.expiresAt,
    this.sentTo,
  });

  final bool success;
  final String? msg;
  final int? attemptsRemaining;

  /// Expired or attempt cap reached: offer resend, not another try.
  final bool requiresGeneration;
  final DateTime? expiresAt;
  final String? sentTo;

  bool get isInvalidCode => msg == "invalid_code";

  /// The code is gone (expired, attempt cap, never generated): the only way
  /// forward is `otp/resend`.
  bool get needsNewCode =>
      requiresGeneration || msg == "otp_expired" || msg == "max_attempts_reached" || msg == "no_active_otp";

  factory OtpResult.fromJson(Map<String, dynamic> json) => OtpResult(
    success: JsonUtils.asBool(json["success"], fallback: json["msg"] == "otp_verified" || json["msg"] == "otp_resent"),
    msg: JsonUtils.asString(json["msg"]),
    attemptsRemaining: JsonUtils.asInt(json["attempts_remaining"]),
    requiresGeneration: JsonUtils.asBool(json["requires_generation"]),
    expiresAt: JsonUtils.asDate(json["otp_expires_at"] ?? json["expires_at"]),
    sentTo: JsonUtils.asString(json["otp_sent_to"] ?? json["sent_to"]),
  );
}

/// Text of the QR the trader app shows while the driver is at the door:
/// `TJD1:<route_stop_id>:<6-digit code>`. The server is the judge; this only
/// catches a wrong QR before a round trip and lets an offline scan be kept.
class HandoffQr {
  const HandoffQr({required this.stopId, required this.code});

  static const String prefix = "TJD1:";

  final int stopId;
  final String code;

  static HandoffQr? tryParse(String text) {
    final parts = text.trim().split(":");
    if (parts.length != 3 || "${parts[0]}:" != prefix) return null;
    final stopId = int.tryParse(parts[1]);
    final code = parts[2].trim();
    if (stopId == null || !RegExp(r"^\d{6}$").hasMatch(code)) return null;
    return HandoffQr(stopId: stopId, code: code);
  }
}

/// `barcode/verify` — HTTP 200 for both outcomes, [success] is the truth.
class BarcodeResult {
  const BarcodeResult({required this.success, this.itemId, this.msg, this.barcode, this.expectedBarcodes = const []});

  final bool success;
  final int? itemId;
  final String? msg;
  final String? barcode;

  /// On a mismatch: the codes of every item at the stop, so the driver can
  /// see what was expected.
  final List<String> expectedBarcodes;

  factory BarcodeResult.fromJson(Map<String, dynamic> json, {String? barcode}) => BarcodeResult(
    success: JsonUtils.asBool(json["success"]),
    itemId: JsonUtils.asInt(json["item_id"]),
    msg: JsonUtils.asString(json["msg"]),
    barcode: barcode,
    expectedBarcodes: JsonUtils.asStringList(json["expected_barcodes"]),
  );
}

/// `POST /driver/stops/{id}/seals` for both modes.
class SealResult {
  const SealResult({
    required this.success,
    this.recorded = const [],
    this.matched = const [],
    this.mismatched = const [],
    this.missing = const [],
    this.extra = const [],
    this.msg,
  });

  final bool success;
  final List<String> recorded;
  final List<String> matched;
  final List<String> mismatched;
  final List<String> missing;
  final List<String> extra;
  final String? msg;

  bool get hasTamperEvidence => mismatched.isNotEmpty || missing.isNotEmpty || extra.isNotEmpty;

  static List<String> _seals(dynamic value) {
    if (value is num) return [];
    return JsonUtils.asStringList(value);
  }

  factory SealResult.fromJson(Map<String, dynamic> json) => SealResult(
    success: JsonUtils.asBool(json["success"]),
    recorded: _seals(json["recorded"]),
    matched: _seals(json["matched"]),
    mismatched: _seals(json["mismatched"]),
    missing: _seals(json["missing"]),
    extra: _seals(json["extra"]),
    msg: JsonUtils.asString(json["msg"]),
  );
}

/// `GET /driver/stops/{id}/receipt_status` → `data`.
class ReceiptStatusModel {
  const ReceiptStatusModel({
    required this.status,
    this.goodsReceiptId,
    this.receiptNo,
    this.receivedAt,
    this.disputedAt,
    this.receivedQty,
    this.rejectedQty,
    this.qtyMismatchWithDriver = false,
    this.notes,
  });

  final String status;
  final int? goodsReceiptId;
  final String? receiptNo;
  final DateTime? receivedAt;
  final DateTime? disputedAt;
  final double? receivedQty;
  final double? rejectedQty;
  final bool qtyMismatchWithDriver;
  final String? notes;

  bool get isPending => status == "pending_trader_action";

  bool get isFinal => status == "accepted" || status == "partial" || status == "rejected" || status == "disputed";

  factory ReceiptStatusModel.fromJson(Map<String, dynamic> json) {
    final totals = JsonUtils.asMap(json["totals"]);
    return ReceiptStatusModel(
      status: JsonUtils.asString(json["status"]) ?? "not_applicable",
      goodsReceiptId: JsonUtils.asInt(json["goods_receipt_id"]),
      receiptNo: JsonUtils.asString(json["receipt_no"]),
      receivedAt: JsonUtils.asDate(json["received_at"]),
      disputedAt: JsonUtils.asDate(json["disputed_at"]),
      receivedQty: JsonUtils.asDouble(totals["received_qty"]),
      rejectedQty: JsonUtils.asDouble(totals["rejected_qty"]),
      qtyMismatchWithDriver: JsonUtils.asBool(json["qty_mismatch_with_driver"]),
      notes: JsonUtils.asString(json["notes"]),
    );
  }
}

/// `POST /driver/uploads`: the docs put the row under `data`, the live
/// server under `file`; the repo passes whichever is present.
class UploadResult {
  const UploadResult({required this.filePath, this.fileUrl, this.mimeType, this.size, this.originalName});

  final String filePath;
  final String? fileUrl;
  final String? mimeType;
  final int? size;
  final String? originalName;

  factory UploadResult.fromJson(Map<String, dynamic> json) => UploadResult(
    filePath: JsonUtils.asString(json["file_path"]) ?? "",
    fileUrl: JsonUtils.asString(json["file_url"]),
    mimeType: JsonUtils.asString(json["mime_type"]),
    size: JsonUtils.asInt(json["size"]),
    originalName: JsonUtils.asString(json["original_name"]),
  );
}

/// One line of a pickup confirmation.
class PickupItemRequest {
  const PickupItemRequest({required this.itemId, this.loadedQty, this.barcodeValue, this.conditionNotes});

  final int itemId;

  /// At most the expected quantity; less is a short load the trader's
  /// receipt records.
  final double? loadedQty;

  /// The scanned code. The server no longer trusts `barcode_scanned` /
  /// `barcode_match` from the app: a required line passes only through an
  /// earlier `barcode/verify` match or this value equal to the product code.
  final String? barcodeValue;
  final String? conditionNotes;

  Map<String, dynamic> toJson() => {
    "item_id": itemId,
    if (loadedQty != null) "loaded_qty": loadedQty,
    if (barcodeValue != null && barcodeValue!.isNotEmpty) "barcode_value": barcodeValue,
    if (conditionNotes != null && conditionNotes!.isNotEmpty) "condition_notes": conditionNotes,
  };
}

/// Body of `POST /driver/stops/{id}/pickup`.
class PickupRequest {
  const PickupRequest({
    this.items = const [],
    this.sealNumbers = const [],
    this.temperature,
    this.departureLatitude,
    this.departureLongitude,
  });

  final List<PickupItemRequest> items;
  final List<String> sealNumbers;
  final double? temperature;
  final double? departureLatitude;
  final double? departureLongitude;

  Map<String, dynamic> toJson() => {
    if (items.isNotEmpty) "items": [for (final item in items) item.toJson()],
    if (sealNumbers.isNotEmpty) "seal_numbers": sealNumbers,
    if (temperature != null) "temperature": temperature,
    if (departureLatitude != null) "departure_latitude": departureLatitude,
    if (departureLongitude != null) "departure_longitude": departureLongitude,
  };
}

/// One line of a delivery confirmation. `delivered + returned + damaged`
/// must equal [loadedQty], the quantity confirmed at pickup
/// ([StopItemModel.deliverableQty]); [isBalanced] checks that locally.
class DeliveryItemRequest {
  const DeliveryItemRequest({
    required this.itemId,
    required this.loadedQty,
    this.deliveredQty = 0,
    this.returnedQty = 0,
    this.damagedQty = 0,
    this.barcodeValue,
    this.conditionNotes,
  });

  final int itemId;
  final double loadedQty;
  final double deliveredQty;
  final double returnedQty;
  final double damagedQty;
  final String? barcodeValue;
  final String? conditionNotes;

  double get total => deliveredQty + returnedQty + damagedQty;

  bool get isBalanced => (total - loadedQty).abs() < 0.0001;

  Map<String, dynamic> toJson() => {
    "item_id": itemId,
    "delivered_qty": deliveredQty,
    "returned_qty": returnedQty,
    "damaged_qty": damagedQty,
    if (barcodeValue != null && barcodeValue!.isNotEmpty) "barcode_value": barcodeValue,
    if (conditionNotes != null && conditionNotes!.isNotEmpty) "condition_notes": conditionNotes,
  };
}

/// Reasons `/deliver` accepts when neither the trader's QR nor the code
/// could be had. Anything else is refused as `handoff_verification_required`,
/// and the bypass also needs a delivery photo.
const List<String> handoffBypassReasons = ["receiver_absent", "no_signal", "receiver_refused_code"];

/// Body of `POST /driver/stops/{id}/deliver`. The receiver handoff is proven
/// one of three ways: it was verified beforehand through `handoff/verify`
/// (nothing to send), [handoffQr] / [otpCode] captured offline and checked by
/// the server at sync time, or [bypassReason] with a delivery photo.
class DeliveryRequest {
  const DeliveryRequest({
    this.handoffQr,
    this.otpCode,
    this.bypassReason,
    this.items = const [],
    this.sealNumbers = const [],
    this.signerName,
    this.signerRole,
  });

  final String? handoffQr;
  final String? otpCode;
  final String? bypassReason;
  final List<DeliveryItemRequest> items;
  final List<String> sealNumbers;
  final String? signerName;
  final String? signerRole;

  List<DeliveryItemRequest> get unbalancedItems => [
    for (final item in items)
      if (!item.isBalanced) item,
  ];

  Map<String, dynamic> toJson() => {
    if (handoffQr != null && handoffQr!.isNotEmpty) "handoff_qr": handoffQr,
    if (otpCode != null && otpCode!.isNotEmpty) "otp_code": otpCode,
    if (bypassReason != null && bypassReason!.isNotEmpty) "bypass_reason": bypassReason,
    if (items.isNotEmpty) "items": [for (final item in items) item.toJson()],
    // `verified_seal_numbers` is the current name; older servers read `seal_numbers`.
    if (sealNumbers.isNotEmpty) "verified_seal_numbers": sealNumbers,
    if (sealNumbers.isNotEmpty) "seal_numbers": sealNumbers,
    if (signerName != null && signerName!.isNotEmpty) "signer_name": signerName,
    if (signerRole != null && signerRole!.isNotEmpty) "signer_role": signerRole,
  };
}

/// Body of `POST /driver/stops/{id}/return`, closing a `return_to_base` stop
/// once the goods are back at the supplier warehouse.
class ReturnRequest {
  const ReturnRequest({this.latitude, this.longitude, this.notes});

  final double? latitude;
  final double? longitude;

  /// Free text for the supplier, at most [notesMaxLength] characters.
  final String? notes;

  static const int notesMaxLength = 500;

  Map<String, dynamic> toJson() => {
    if (latitude != null) "latitude": latitude,
    if (longitude != null) "longitude": longitude,
    if (notes != null && notes!.trim().isNotEmpty) "notes": notes!.trim(),
  };
}

/// Types the proof endpoint accepts. The four photo types need watermark data.
enum ProofType { pickupPhoto, deliveryPhoto, damagePhoto, signature, conditionPhoto, returnPhoto, documentScan }

extension ProofTypeData on ProofType {
  String get apiValue => switch (this) {
    ProofType.pickupPhoto => "pickup_photo",
    ProofType.deliveryPhoto => "delivery_photo",
    ProofType.damagePhoto => "damage_photo",
    ProofType.signature => "signature",
    ProofType.conditionPhoto => "condition_photo",
    ProofType.returnPhoto => "return_photo",
    ProofType.documentScan => "document_scan",
  };

  bool get requiresWatermark =>
      this == ProofType.pickupPhoto ||
      this == ProofType.deliveryPhoto ||
      this == ProofType.damagePhoto ||
      this == ProofType.conditionPhoto;

  String get titleKey => switch (this) {
    ProofType.pickupPhoto => "proof_pickup_photo",
    ProofType.deliveryPhoto => "proof_delivery_photo",
    ProofType.damagePhoto => "proof_damage_photo",
    ProofType.signature => "proof_signature",
    ProofType.conditionPhoto => "proof_condition_photo",
    ProofType.returnPhoto => "proof_return_photo",
    ProofType.documentScan => "proof_document_scan",
  };
}

enum ProofCategory { pickup, delivery, returned, inspection }

extension ProofCategoryData on ProofCategory {
  String get apiValue => switch (this) {
    ProofCategory.pickup => "pickup",
    ProofCategory.delivery => "delivery",
    ProofCategory.returned => "return",
    ProofCategory.inspection => "inspection",
  };
}

/// Body of `POST /driver/stops/{id}/proof`. The picture goes either as
/// [file] in one multipart call, or as [filePath] returned by a previous
/// `POST /driver/uploads`; one of the two is required. [watermarkData] is
/// required for photo proofs (the server builds it from the coordinates when
/// it is absent and they are not).
class ProofRequest {
  const ProofRequest({
    required this.proofType,
    required this.proofCategory,
    required this.clientUuid,
    this.file,
    this.filePath,
    this.watermarkData,
    this.fileType,
    this.latitude,
    this.longitude,
    this.capturedAt,
    this.signerName,
    this.signerRole,
    this.signerNationalId,
    this.cameraSource = "camera",
    this.notes,
  }) : assert(file != null || filePath != null, "send either file or file_path");

  final ProofType proofType;
  final ProofCategory proofCategory;
  final File? file;
  final String? filePath;
  final String clientUuid;
  final Map<String, dynamic>? watermarkData;
  final String? fileType;
  final double? latitude;
  final double? longitude;
  final DateTime? capturedAt;
  final String? signerName;
  final String? signerRole;
  final String? signerNationalId;
  final String cameraSource;
  final String? notes;

  /// Sent as multipart (`file`) rather than JSON (`file_path`).
  bool get isMultipart => file != null;

  /// The fields common to both encodings. `watermark_data` stays a map here;
  /// the multipart form serialises it to a JSON string.
  Map<String, dynamic> toJson() => {
    "proof_type": proofType.apiValue,
    "proof_category": proofCategory.apiValue,
    if (file == null && filePath != null && filePath!.isNotEmpty) "file_path": filePath,
    if (watermarkData != null) "watermark_data": watermarkData,
    if (fileType != null) "file_type": fileType,
    if (latitude != null) "latitude": latitude,
    if (longitude != null) "longitude": longitude,
    if (capturedAt != null) "captured_at": JsonUtils.formatServerDateTime(capturedAt!),
    if (signerName != null && signerName!.isNotEmpty) "signer_name": signerName,
    if (signerRole != null && signerRole!.isNotEmpty) "signer_role": signerRole,
    if (signerNationalId != null && signerNationalId!.isNotEmpty) "signer_national_id": signerNationalId,
    "camera_source": cameraSource,
    "client_uuid": clientUuid,
    if (notes != null && notes!.isNotEmpty) "notes": notes,
  };
}

/// One GPS sample of the live location feed.
class LocationPoint {
  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.loggedAt,
    this.speedKmh,
    this.heading,
    this.accuracyMeters,
    this.batteryLevel,
  });

  final double latitude;
  final double longitude;
  final DateTime loggedAt;
  final double? speedKmh;
  final double? heading;
  final double? accuracyMeters;
  final int? batteryLevel;

  Map<String, dynamic> toJson() => {
    "latitude": latitude,
    "longitude": longitude,
    if (speedKmh != null) "speed_kmh": speedKmh,
    if (heading != null) "heading": heading,
    if (accuracyMeters != null) "accuracy_meters": accuracyMeters,
    if (batteryLevel != null) "battery_level": batteryLevel,
    "logged_at": JsonUtils.formatServerDateTime(loggedAt),
  };

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
    latitude: JsonUtils.asDouble(json["latitude"]) ?? 0,
    longitude: JsonUtils.asDouble(json["longitude"]) ?? 0,
    loggedAt: JsonUtils.asDate(json["logged_at"]) ?? DateTime.now(),
    speedKmh: JsonUtils.asDouble(json["speed_kmh"]),
    heading: JsonUtils.asDouble(json["heading"]),
    accuracyMeters: JsonUtils.asDouble(json["accuracy_meters"]),
    batteryLevel: JsonUtils.asInt(json["battery_level"]),
  );
}
