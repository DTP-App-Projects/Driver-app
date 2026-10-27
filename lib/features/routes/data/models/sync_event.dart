import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/uuid.dart';

/// Actions `POST /driver/sync/batch` can replay.
enum SyncActionType { arrive, pickup, deliver, returnToBase, skip, proofUpload, locationBatch, incident }

extension SyncActionTypeData on SyncActionType {
  String get apiValue => switch (this) {
    SyncActionType.arrive => "arrive",
    SyncActionType.pickup => "pickup",
    SyncActionType.deliver => "deliver",
    SyncActionType.returnToBase => "return",
    SyncActionType.skip => "skip",
    SyncActionType.proofUpload => "proof_upload",
    SyncActionType.locationBatch => "location_batch",
    SyncActionType.incident => "incident",
  };

  static SyncActionType? fromApi(String? value) {
    for (final type in SyncActionType.values) {
      if (type.apiValue == value) return type;
    }
    return null;
  }
}

/// One queued mutation: the same body that would have been POSTed online,
/// stamped with a client UUID so the server can deduplicate retries.
class SyncEvent {
  SyncEvent({
    required this.actionType,
    required this.payload,
    String? clientUuid,
    DateTime? clientCreatedAt,
    this.attempts = 0,
    this.lastError,
  }) : clientUuid = clientUuid ?? Uuid.v4(),
       clientCreatedAt = clientCreatedAt ?? DateTime.now();

  final String clientUuid;
  final SyncActionType actionType;
  final Map<String, dynamic> payload;
  final DateTime clientCreatedAt;
  int attempts;
  String? lastError;

  /// Stop the event acts on, when it is a stop action.
  int? get stopId => JsonUtils.asInt(payload["stop_id"]);

  /// A `proof_upload` replays metadata only: without the `file_path` of an
  /// earlier upload the server fails it with `file_path_or_file_required`.
  bool get isSendable {
    if (actionType != SyncActionType.proofUpload) return true;
    final path = JsonUtils.asString(payload["file_path"]);
    return path != null && path.trim().isNotEmpty;
  }

  Map<String, dynamic> toApiJson() => {
    "client_uuid": clientUuid,
    "action_type": actionType.apiValue,
    "client_created_at": JsonUtils.formatServerDateTime(clientCreatedAt),
    "payload": payload,
  };

  Map<String, dynamic> toStorageJson() => {
    ...toApiJson(),
    "attempts": attempts,
    if (lastError != null) "last_error": lastError,
  };

  static SyncEvent? fromStorageJson(Map<String, dynamic> json) {
    final type = SyncActionTypeData.fromApi(JsonUtils.asString(json["action_type"]));
    final uuid = JsonUtils.asString(json["client_uuid"]);
    if (type == null || uuid == null) return null;
    return SyncEvent(
      clientUuid: uuid,
      actionType: type,
      payload: JsonUtils.asMap(json["payload"]),
      clientCreatedAt: JsonUtils.asDate(json["client_created_at"]) ?? DateTime.now(),
      attempts: JsonUtils.asInt(json["attempts"]) ?? 0,
      lastError: JsonUtils.asString(json["last_error"]),
    );
  }
}

/// A queued pickup / delivery the server refused for a reason only the driver
/// can fix (missing handoff code, quantities that do not add up, …). It is
/// taken out of the queue so the stop reopens and the sheet can be redone.
class SyncRejection {
  const SyncRejection({required this.event, required this.result});

  final SyncEvent event;
  final SyncResult result;

  int? get stopId => event.stopId;

  /// Reasons retrying the same payload can never fix.
  static const Set<String> fixableReasons = {
    "handoff_verification_required",
    "bypass_requires_delivery_photo",
    "otp_verification_failed",
    "pickup_not_completed",
    "quantity_balance_failed",
    "barcode_validation_failed",
    "shipment_not_ready_for_pickup",
    "loaded_exceeds_expected",
    "delivery_failed",
    "pickup_failed",
  };

  static bool applies(SyncEvent event, SyncResult result) {
    if (!result.isFailed) return false;
    if (event.actionType != SyncActionType.deliver && event.actionType != SyncActionType.pickup) return false;
    final text = result.error ?? "";
    return fixableReasons.contains(result.errorCode) || fixableReasons.any(text.contains);
  }
}

/// One entry of the `results` array the sync endpoint answers with.
class SyncResult {
  const SyncResult({this.clientUuid, required this.status, this.error, this.reason, this.result});

  final String? clientUuid;
  final String status;
  final String? error;
  final String? reason;
  final Map<String, dynamic>? result;

  bool get isDone => status == "synced" || status == "already_synced";

  bool get isFailed => status == "failed";

  /// Reason code at the head of [error] (`otp_verification_failed: {…}` →
  /// `otp_verification_failed`).
  String? get errorCode {
    final head = (error ?? reason)?.split(":").first.trim();
    return head == null || head.isEmpty ? null : head;
  }

  /// A batch the server refused as a whole, recorded per event.
  factory SyncResult.failed(SyncEvent event, {String? error}) =>
      SyncResult(clientUuid: event.clientUuid, status: "failed", error: error);

  factory SyncResult.fromJson(Map<String, dynamic> json) => SyncResult(
    clientUuid: JsonUtils.asString(json["client_uuid"]),
    status: JsonUtils.asString(json["status"]) ?? "failed",
    error: JsonUtils.asString(json["error"]),
    reason: JsonUtils.asString(json["reason"]),
    result: JsonUtils.asMapOrNull(json["result"]),
  );
}
