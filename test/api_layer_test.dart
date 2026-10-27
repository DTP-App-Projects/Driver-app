import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_response.dart';
import 'package:digital_trade_portal_driver/features/auth/data/models/login_model.dart';
import 'package:digital_trade_portal_driver/features/notification/data/models/notification_model.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/content_models.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/driver_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/live_session_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_push_event.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/stop_execution_models.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/sync_event.dart';

Response _response(dynamic body, int status) => Response(
  requestOptions: RequestOptions(path: "/x"),
  data: body,
  statusCode: status,
);

void main() {
  setUpAll(() {
    final en = jsonDecode(File("lib/core/language/en.json").readAsStringSync()) as Map<String, dynamic>;
    Localization.load(const Locale("en"), translations: Translations(en));
  });

  group("ApiResponse normalisation", () {
    test("bare envelope keeps payload beside msg", () {
      final response = ApiResponse.fromDio(
        _response({
          "msg": "arrived",
          "stop": {"id": 41},
        }, 200),
      );
      expect(response.isSuccess, isTrue);
      expect(response.msg, "arrived");
      expect(response.body["stop"]["id"], 41);
    });

    test("wrapped envelope uses the body status", () {
      final response = ApiResponse.fromDio(_response({"status": 401, "message": "not_a_driver"}, 200));
      expect(response.isSuccess, isFalse);
      expect(response.statusCode, 401);
      final failure = ServerFailure.fromApiResponse(response);
      expect(failure.isNotADriver, isTrue);
    });

    test("barcode mismatch is HTTP 200 with success false", () {
      final response = ApiResponse.fromDio(_response({"success": false, "msg": "barcode_mismatch"}, 200));
      expect(response.isSuccess, isFalse);
      expect(BarcodeResult.fromJson(response.body).success, isFalse);
    });

    test("validation bag is parsed", () {
      final failure = ServerFailure.fromApiResponse(
        ApiResponse.fromDio(
          _response({
            "msg": "validation_error",
            "bag": {
              "email": ["The email field is required."],
            },
          }, 400),
        ),
      );
      expect(failure.isValidation, isTrue);
      expect(failure.bag["email"], ["The email field is required."]);
      expect(failure.errMessage, "The email field is required.");
    });
  });

  group("Failure mapping", () {
    test("known codes are localized", () {
      final failure = ServerFailure.fromApiResponse(ApiResponse.fromDio(_response({"msg": "invalid_password"}, 401)));
      expect(failure.isUnauthenticated, isFalse);
      expect(failure.errMessage, "Incorrect password.");
    });

    test("a localized sentence in msg is shown as is (production login)", () {
      final failure = ServerFailure.fromApiResponse(ApiResponse.fromDio(_response({"msg": "بريد إلكتروني خاطئ"}, 401)));
      expect(failure.isUnauthenticated, isFalse);
      expect(failure.errMessage, "بريد إلكتروني خاطئ");
    });

    test("only session codes log the driver out", () {
      expect(ServerFailure.isSessionInvalid("unauthenticated", {"msg": "unauthenticated"}), isTrue);
      expect(ServerFailure.isSessionInvalid("Unauthenticated.", {"message": "Unauthenticated."}), isTrue);
      expect(ServerFailure.isSessionInvalid("unauthorized", {"msg": "unauthorized"}), isTrue);
      expect(ServerFailure.isSessionInvalid("invalid_password", {"msg": "invalid_password"}), isFalse);
    });

    test("bare 500 becomes a retryable server failure, never a logout", () {
      final failure = ServerFailure.fromApiResponse(ApiResponse.fromDio(_response({"message": "Server Error"}, 500)));
      expect(failure.kind, FailureKind.server);
      expect(failure.isRetryable, isTrue);
      expect(failure.isUnauthenticated, isFalse);
    });

    test("429 is rate limited", () {
      final failure = ServerFailure.fromApiResponse(
        ApiResponse.fromDio(_response({"message": "Too Many Attempts."}, 429)),
      );
      expect(failure.isRateLimited, isTrue);
    });

    test("pickup_failed keeps the embedded detail and item ids", () {
      final failure = ServerFailure.fromApiResponse(
        ApiResponse.fromDio(
          _response({
            "msg": "pickup_failed",
            "error": jsonEncode({
              "msg": "quantity_validation_failed",
              "errors": [
                {"item_id": 90, "expected_qty": 10, "loaded_qty": 12},
              ],
            }),
          }, 422),
        ),
      );
      expect(failure.code, "pickup_failed");
      expect(failure.failedItemIds, {90});
      expect(failure.detailLines, isNotEmpty);
    });

    test("delivery_failed reads the reason and item list behind the prefix", () {
      final failure = ServerFailure.fromApiResponse(
        ApiResponse.fromDio(
          _response({
            "msg": "delivery_failed",
            "error": 'barcode_validation_failed: [{"error":"barcode_mismatch","item_id":13}]',
          }, 422),
        ),
      );
      expect(failure.reason, "barcode_validation_failed");
      expect(failure.itemErrors, {13: "barcode_mismatch"});
      expect(failure.errMessage, "Some items still need a verified barcode.");

      final canceled = ServerFailure.fromApiResponse(
        ApiResponse.fromDio(
          _response({"msg": "pickup_failed", "error": "shipment_not_ready_for_pickup:canceled"}, 422),
        ),
      );
      expect(canceled.reason, "shipment_not_ready_for_pickup");
      expect(canceled.errMessage, "This shipment is no longer available for pickup");
    });
  });

  group("Live tracking session", () {
    test("an enabled session carries everything a write needs", () {
      final live = LiveSessionModel.fromJson({
        "live": {
          "enabled": true,
          "token": "t",
          "uid": "driver_12",
          "database_url": "https://x.firebasedatabase.app",
          "expires_at": "2026-09-27T02:00:00+03:00",
          "path": "live/drivers/12",
          "driver_id": 12,
          "route_id": "345",
          "sup": 7,
          "write_interval_seconds": 5,
          "history_interval_seconds": 60,
        },
      });
      expect(live.isUsable, isTrue);
      expect(live.sup, 7);
      expect(live.routeId, 345);
      expect(live.writeInterval, const Duration(seconds: 5));
      expect(live.historyInterval, const Duration(seconds: 60));
      expect(live.expiresAt!.toUtc().hour, 23);
    });

    test("disabled or incomplete sessions never write", () {
      expect(
        LiveSessionModel.fromJson({
          "live": {"enabled": false},
        }).isUsable,
        isFalse,
      );
      expect(
        LiveSessionModel.fromJson({
          "msg": "no_active_route",
          "live": {"enabled": false},
        }).enabled,
        isFalse,
      );
      final noSup = LiveSessionModel.fromJson({
        "live": {"enabled": true, "token": "t", "database_url": "https://x", "path": "live/drivers/1"},
      });
      expect(noSup.isUsable, isFalse);
      final defaults = LiveSessionModel.fromJson({
        "live": {"enabled": true},
      });
      expect(defaults.historyInterval, LiveSessionModel.defaultHistoryInterval);
    });
  });

  group("Delivery handoff", () {
    test("handoff QR is parsed and rejected when malformed", () {
      final qr = HandoffQr.tryParse(" TJD1:5821:482913 ")!;
      expect(qr.stopId, 5821);
      expect(qr.code, "482913");
      expect(HandoffQr.tryParse("6281000000011"), isNull);
      expect(HandoffQr.tryParse("TJD1:5821:48291"), isNull);
      expect(HandoffQr.tryParse("XYZ1:5821:482913"), isNull);
    });

    test("expired code outcomes ask for a new code", () {
      for (final msg in ["otp_expired", "max_attempts_reached", "no_active_otp"]) {
        expect(OtpResult.fromJson({"success": false, "msg": msg}).needsNewCode, isTrue);
      }
      expect(OtpResult.fromJson({"success": false, "msg": "invalid_code"}).needsNewCode, isFalse);
      expect(OtpResult.fromJson({"success": true, "msg": "otp_verified"}).success, isTrue);
    });

    test("deliver body carries the offline capture, bypass and item barcodes", () {
      const request = DeliveryRequest(
        handoffQr: "TJD1:5821:482913",
        items: [DeliveryItemRequest(itemId: 13, loadedQty: 50, deliveredQty: 48, returnedQty: 2, barcodeValue: "628")],
        sealNumbers: ["S-1001"],
      );
      final json = request.toJson();
      expect(json["handoff_qr"], "TJD1:5821:482913");
      expect(json.containsKey("otp_code"), isFalse);
      expect(json["verified_seal_numbers"], ["S-1001"]);
      expect((json["items"] as List).single["barcode_value"], "628");

      const bypass = DeliveryRequest(bypassReason: "receiver_absent");
      expect(bypass.toJson(), {"bypass_reason": "receiver_absent"});
      expect(handoffBypassReasons, ["receiver_absent", "no_signal", "receiver_refused_code"]);
    });

    test("pickup lines no longer send the client side barcode verdict", () {
      const item = PickupItemRequest(itemId: 12, loadedQty: 40, barcodeValue: "6281000000011");
      expect(item.toJson(), {"item_id": 12, "loaded_qty": 40.0, "barcode_value": "6281000000011"});
    });

    test("delivery split is based on the loaded quantity", () {
      final short = StopItemModel.fromJson({"id": 1, "expected_qty": 50, "loaded_qty": 40});
      expect(short.deliverableQty, 40);
      expect(short.isShortLoaded, isTrue);
      final notPicked = StopItemModel.fromJson({"id": 2, "expected_qty": 50, "loaded_qty": 0});
      expect(notPicked.deliverableQty, 50);
    });

    test("sync refusals the driver must fix are told apart from retryable ones", () {
      final deliver = SyncEvent(actionType: SyncActionType.deliver, payload: {"stop_id": 5821});
      final failed = SyncResult.fromJson({
        "client_uuid": deliver.clientUuid,
        "status": "failed",
        "error": "otp_verification_failed: {}",
      });
      expect(failed.errorCode, "otp_verification_failed");
      expect(SyncRejection.applies(deliver, failed), isTrue);

      final arrive = SyncEvent(actionType: SyncActionType.arrive, payload: {"stop_id": 5821});
      expect(SyncRejection.applies(arrive, failed), isFalse);

      final transient = SyncResult.fromJson({"status": "failed", "error": "must_arrive_before_delivery"});
      expect(SyncRejection.applies(deliver, transient), isFalse);
    });

    test("a proof upload without its picture is never queued", () {
      expect(SyncEvent(actionType: SyncActionType.proofUpload, payload: {"stop_id": 1}).isSendable, isFalse);
      expect(
        SyncEvent(actionType: SyncActionType.proofUpload, payload: {"stop_id": 1, "file_path": "p/x.jpg"}).isSendable,
        isTrue,
      );
    });
  });

  group("Models tolerate JSON_NUMERIC_CHECK", () {
    test("login keeps the jwt and strips the m_p phone marker", () {
      final model = LoginModel.fromJson({
        "user": {"id": "7", "jwt": "abc", "phone": "m_p512345678", "first_name": "Ahmed", "last_name": "Ali"},
      });
      expect(model.user.id, 7);
      expect(model.jwt, "abc");
      expect(model.user.phone, "512345678");
      expect(model.user.fullName, "Ahmed Ali");
    });

    test("driver profile: terms from timestamp, vehicle relation, numeric fields", () {
      final driver = DriverModel.fromJson({
        "id": 3,
        "user_id": "7",
        "terms_accepted_at": "2026-08-01 09:00:00",
        "rating": "4.5",
        "total_deliveries": "315",
        "can_bypass_otp": 1,
        "user": {"id": 7, "name": "خالد ماهر", "phone": 966500000000, "email": "d@x.com"},
        "defaultVehicle": {
          "id": 9,
          "plate_number": 1234,
          "vehicle_type": "truck",
          "is_refrigerated": true,
          "capacity_kg": 3500,
        },
      });
      expect(driver.termsAccepted, isTrue);
      expect(driver.rating, 4.5);
      expect(driver.totalDeliveries, 315);
      expect(driver.canBypassOtp, isTrue);
      expect(driver.phone, "966500000000");
      expect(driver.displayName, "خالد ماهر");
      expect(driver.defaultVehicle!.plate, "1234");
      expect(driver.defaultVehicle!.isAssigned, isTrue);
      expect(driver.defaultVehicle!.capacityTons, 3.5);
    });

    test("today route parses stops, items, sku and statuses", () {
      final today = TodayRouteModel.fromJson({
        "route": {
          "id": 12,
          "code": "RT-0001",
          "route_date": "2026-08-26",
          "status": "in_progress",
          "total_stops": 2,
          "completed_stops": 1,
          "stops": [
            {
              "id": 41,
              "stop_order": 1,
              "stop_type": "pickup",
              "status": "completed",
              "branch": {"id": 1, "name": "مستودع الرياض", "latitude": "24.7136", "longitude": 46.6753},
              "items": [
                {
                  "id": 90,
                  "expected_qty": "10",
                  "barcode_required": 1,
                  "sku": {
                    "id": 5,
                    "sku": 6281000000001,
                    "barcode": "6281000000001",
                    "product": {"id": 2, "name": "Milk"},
                  },
                },
              ],
            },
            {
              "id": 42,
              "stop_order": 2,
              "stop_type": "internal_transfer_delivery",
              "status": "en_route",
              "branch": {"id": 2, "name": "Panda"},
            },
          ],
        },
        "eta": {"next_stop_id": 42, "eta_minutes": 14},
        "late_routes": [],
        "upcoming_routes": [
          {"id": 13, "code": "RT-0002", "route_date": "2026-08-27", "status": "assigned"},
        ],
      });
      final route = today.route!;
      expect(route.isInProgress, isTrue);
      expect(route.stops.first.hasLocation, isTrue);
      expect(route.stops.first.latitude, 24.7136);
      expect(route.stops.first.items.first.expectedQty, 10);
      expect(route.stops.first.items.first.barcodeRequired, isTrue);
      expect(route.stops.first.items.first.sku!.code, "6281000000001");
      expect(route.stops.first.items.first.productName, "Milk");
      expect(route.stops[1].type, StopType.internalTransferDelivery);
      expect(route.stops[1].type.isDelivery, isTrue);
      expect(route.stops[1].status, StopStatus.enRoute);
      expect(route.stops[1].hasLocation, isFalse);
      expect(route.stopsDone, 1);
      expect(today.eta!.etaMinutes, 14);
      expect(today.allRoutes.length, 2);
      expect(today.routeById(13)!.isAssigned, isTrue);
    });

    test("arrival response carries the OTP dispatch details", () {
      final stop = RouteStop(id: 41, stopOrder: 1, type: StopType.delivery, status: StopStatus.enRoute);
      final arrival = ArrivalResult.fromJson({
        "msg": "arrived",
        "stop": {"id": 41, "status": "arrived"},
        "otp_required": true,
        "otp_sent_to": "05xxxxxxxx",
        "otp_expires_at": "2026-08-26 14:05:00",
        "expected_seal_numbers": ["SEAL-1", "SEAL-2"],
      }, current: stop);
      expect(arrival.stop.status, StopStatus.arrived);
      expect(arrival.otpRequired, isTrue);
      expect(arrival.expectedSealNumbers, ["SEAL-1", "SEAL-2"]);
      expect(arrival.otpExpiresAt, isNotNull);
    });

    test("otp verify failure exposes attempts and resend need", () {
      final otp = OtpResult.fromJson({"success": false, "msg": "max_attempts_reached", "requires_generation": true});
      expect(otp.success, isFalse);
      expect(otp.requiresGeneration, isTrue);
      final invalid = OtpResult.fromJson({"success": false, "msg": "invalid_code", "attempts_remaining": 2});
      expect(invalid.isInvalidCode, isTrue);
      expect(invalid.attemptsRemaining, 2);
    });

    test("delivery request enforces the quantity balance locally", () {
      const balanced = DeliveryItemRequest(itemId: 1, loadedQty: 10, deliveredQty: 9, returnedQty: 1);
      const unbalanced = DeliveryItemRequest(itemId: 2, loadedQty: 10, deliveredQty: 9);
      expect(balanced.isBalanced, isTrue);
      expect(unbalanced.isBalanced, isFalse);
      const request = DeliveryRequest(otpCode: "123456", items: [balanced, unbalanced], signerName: "Khalid");
      expect(request.unbalancedItems.map((item) => item.itemId), [2]);
      final json = request.toJson();
      expect(json["otp_code"], "123456");
      expect(json.containsKey("bypass_reason"), isFalse);
      expect(json["signer_name"], "Khalid");
    });

    test("proof request only sends watermark for photo types", () {
      final photo = ProofRequest(
        proofType: ProofType.deliveryPhoto,
        proofCategory: ProofCategory.delivery,
        filePath: "uploads/x.jpg",
        clientUuid: "u",
        watermarkData: const {"driver": "A"},
        capturedAt: DateTime(2026, 8, 26, 14, 3, 11),
      ).toJson();
      expect(photo["proof_type"], "delivery_photo");
      expect(photo["watermark_data"], isNotNull);
      expect(photo["captured_at"], "2026-08-26 14:03:11");
      expect(ProofType.signature.requiresWatermark, isFalse);
    });

    test("proof request with a file goes multipart and omits file_path", () {
      final request = ProofRequest(
        proofType: ProofType.pickupPhoto,
        proofCategory: ProofCategory.pickup,
        file: File("x.jpg"),
        clientUuid: "u",
        watermarkData: const {"text": "A", "latitude": 24.7, "longitude": 46.6},
      );
      expect(request.isMultipart, isTrue);
      expect(request.toJson().containsKey("file_path"), isFalse);
      expect(request.toJson()["watermark_data"], isA<Map<String, dynamic>>());
      expect(
        ProofModel.fromJson({"id": 1, "file_path": "proofs/a.jpg", "file_url": "https://cdn/a.jpg"}).displayUrl,
        "https://cdn/a.jpg",
      );
      expect(ProofModel.fromJson({"id": 1, "file_path": "proofs/a.jpg"}).displayUrl, isNull);
      expect(ProofModel.fromJson({"id": 1, "file_path": "https://s3/a.jpg"}).displayUrl, "https://s3/a.jpg");
    });

    test("upload result reads the live `file` envelope as well as `data`", () {
      final live = ApiResponse.fromDio(
        _response({
          "msg": "attachment_uploaded",
          "file": {"file_path": "uploads/a.jpg", "file_url": "https://x/a.jpg"},
        }, 200),
      );
      final documented = ApiResponse.fromDio(
        _response({
          "msg": "attachment_uploaded",
          "data": {"file_path": "uploads/b.jpg"},
        }, 200),
      );
      expect(UploadResult.fromJson(JsonUtils.asMapOrNull(live.body["file"]) ?? live.dataMap).filePath, "uploads/a.jpg");
      expect(
        UploadResult.fromJson(JsonUtils.asMapOrNull(documented.body["file"]) ?? documented.dataMap).filePath,
        "uploads/b.jpg",
      );
    });

    test("expected barcode comes from the line, falls back to the sku, and blocks a required scan", () {
      final withExpected = StopItemModel.fromJson({
        "id": 1,
        "expected_qty": 1,
        "barcode_required": true,
        "expected_barcode": "6281000000009",
        "sku": {"id": 5, "sku": "SKU-2-DEFAULT", "barcode": "old"},
      });
      expect(withExpected.barcode, "6281000000009");
      expect(withExpected.needsBarcodeScan, isTrue);
      expect(withExpected.copyWith(barcodeMatch: true).needsBarcodeScan, isFalse);
      expect(withExpected.copyWith(barcodeMatch: true).expectedBarcode, "6281000000009");

      final legacy = StopItemModel.fromJson({
        "id": 2,
        "expected_qty": 1,
        "expected_barcode": null,
        "sku": {"id": 5, "barcode": "6281000000001"},
      });
      expect(legacy.barcode, "6281000000001");
      expect(legacy.needsBarcodeScan, isFalse);

      final none = StopItemModel.fromJson({
        "id": 3,
        "expected_qty": 1,
        "sku": {"id": 5, "barcode": ""},
      });
      expect(none.barcode, isNull);
    });

    test("barcode mismatch lists the codes the stop expected", () {
      final mismatch = BarcodeResult.fromJson({
        "success": false,
        "msg": "barcode_mismatch",
        "expected_barcodes": ["6281000000001", 6281000000002],
      }, barcode: "x");
      expect(mismatch.success, isFalse);
      expect(mismatch.expectedBarcodes, ["6281000000001", "6281000000002"]);
      expect(BarcodeResult.fromJson({"success": true, "item_id": 90}).expectedBarcodes, isEmpty);
    });

    test("notification type is derived from the event code and read_at", () {
      final items = NotificationModel.listFromJson([
        {
          "id": 1,
          "event_code": "route.assigned",
          "title": "t",
          "body": "b",
          "read_at": null,
          "created_at": "2026-08-26 10:00:00",
        },
        {
          "id": 2,
          "event_code": "delivery_note.dispatched",
          "title": "t",
          "body": "b",
          "read_at": "2026-08-26 10:00:00",
          "created_at": "2026-08-26 10:00:00",
        },
        {"id": 3, "event_code": "x", "incident_id": 5, "title": "t", "body": "b", "created_at": "2026-08-26 10:00:00"},
      ]);
      expect(items[0].type, NotificationType.route);
      expect(items[0].isRead, isFalse);
      expect(items[1].type, NotificationType.order);
      expect(items[1].isRead, isTrue);
      expect(items[2].type, NotificationType.alert);
    });

    test("content endpoints: {text: html} pages and numeric support phones", () {
      final terms = ContentPageModel.fromJson({"text": "<p>Hello <b>world</b></p>"}, language: "en");
      expect(terms.body, "<p>Hello <b>world</b></p>");
      final support = SupportChannelModel.listFromJson({
        "phone": 966500863430,
        "whatsapp": 966500863430,
        "email": "support@tajerid.com",
        "hours": "Sun - Thu",
      });
      expect(support.length, 4);
      expect(support.first.value, "966500863430");
      expect(support.first.isPhone, isTrue);
      expect(support[1].type, "whatsapp");
      expect(support[2].isEmail, isTrue);
    });

    test("sync events round trip through storage with their uuid", () {
      final event = SyncEvent(actionType: SyncActionType.deliver, payload: {"stop_id": 41});
      final restored = SyncEvent.fromStorageJson(jsonDecode(jsonEncode(event.toStorageJson())));
      expect(restored!.clientUuid, event.clientUuid);
      expect(restored.actionType, SyncActionType.deliver);
      expect(restored.stopId, 41);
      expect(event.toApiJson()["action_type"], "deliver");
    });

    test("return_to_base stop and supplier skips (API changes 2026-09-19)", () {
      final route = RouteModel.fromJson({
        "id": 12,
        "code": "RT-0001",
        "route_date": "2026-09-19",
        "status": "in_progress",
        "stops": [
          {"id": 41, "stop_order": 1, "stop_type": "pickup", "status": "completed"},
          {
            "id": 42,
            "stop_order": 2,
            "stop_type": "delivery",
            "status": "canceled",
            "failure_reason": "shipment_canceled",
          },
          {"id": 43, "stop_order": 3, "stop_type": "delivery", "status": "skipped", "failure_reason": "المحل مغلق"},
          {"id": 44, "stop_order": 4, "stop_type": "internal_transfer_pickup", "status": "pending"},
          {
            "id": 45,
            "stop_order": 5,
            "stop_type": "return_to_base",
            "status": "pending",
            "reference_type": "delivery_note",
            "reference_id": 7,
            "branch": {"id": 1, "name": "Warehouse"},
          },
          {
            "id": 46,
            "stop_order": 6,
            "stop_type": "delivery",
            "status": "skipped",
            "failure_reason": "rescheduled_by_supplier",
          },
        ],
      });

      final canceled = route.stops[1];
      expect(canceled.status, StopStatus.canceled);
      expect(canceled.status.isClosed, isTrue);
      expect(canceled.status.isDropped, isTrue);
      expect(canceled.status.canSkip, isFalse);
      expect(canceled.status.canArrive, isFalse);
      expect(canceled.isClosedBySupplier, isTrue);
      expect(canceled.failureReasonLabel, "Shipment canceled");
      expect(canceled.status.titleKey, "stop_canceled");
      expect(route.stops[2].status, StopStatus.skipped);
      expect(route.stops[2].isClosedBySupplier, isFalse);
      expect(route.stops[2].failureReasonLabel, "المحل مغلق");
      expect(route.stops[5].isClosedBySupplier, isTrue);
      expect(route.stops[5].failureReasonLabel, "Rescheduled");
      expect(route.stops[3].type, StopType.internalTransferPickup);
      expect(route.stops[3].isPickup, isTrue);

      final back = route.stops[4];
      expect(back.type, StopType.returnToBase);
      expect(back.isReturn, isTrue);
      expect(back.isPickup, isFalse);
      expect(back.type.isDelivery, isFalse);
      expect(back.type.confirmKey, "confirm_return");
      expect(back.hasDeliveryNote, isTrue);
      expect(route.stopsDone, 4);

      final summary = EndOfDaySummaryModel.fromJson({
        "summary": {"total_stops": 6, "completed_stops": 4, "skipped_stops": 2, "canceled_stops": 1},
      });
      expect(summary.canceledStops, 1);

      // `arrive` on a return stop has no OTP keys.
      final arrival = ArrivalResult.fromJson({
        "msg": "arrived",
        "stop": {"id": 45, "status": "arrived"},
      }, current: back);
      expect(arrival.otpRequired, isFalse);
      expect(arrival.stop.status, StopStatus.arrived);

      final returned = back.mergeServer({"id": 45, "status": "completed"});
      expect(returned.status, StopStatus.completed);
      expect(returned.branch!.name, "Warehouse");

      expect(const ReturnRequest(latitude: 24.7, notes: "  ").toJson(), {"latitude": 24.7});
    });

    test("return actions queue with action_type return for sync/batch", () {
      final event = SyncEvent(actionType: SyncActionType.returnToBase, payload: {"stop_id": 45, "notes": "ok"});
      expect(event.toApiJson()["action_type"], "return");
      expect(event.toApiJson()["payload"], {"stop_id": 45, "notes": "ok"});
      final restored = SyncEvent.fromStorageJson(jsonDecode(jsonEncode(event.toStorageJson())));
      expect(restored!.actionType, SyncActionType.returnToBase);
      expect(SyncResult.failed(event, error: "stop_is_not_a_return").isFailed, isTrue);
    });

    test("return errors surface the sub code from error", () {
      final failure = ServerFailure.fromApiResponse(
        ApiResponse.fromDio(_response({"msg": "return_failed", "error": "stop_is_not_a_return"}, 422)),
      );
      expect(failure.code, "return_failed");
      expect(failure.errMessage, "This stop is not a return stop.");
      expect(failure.isRetryable, isFalse);
    });

    test("route pushes are parsed from the FCM data map", () {
      final canceled = RoutePushEvent.fromData({
        "click_action": "route",
        "event_code": "shipment_canceled",
        "route_id": "12",
        "route_code": "RT-0001",
        "route_status": "in_progress",
        "route_closed": "0",
        "stop_id": "42",
        "delivery_note_id": "7",
        "return_to_base": "1",
        "return_stop_id": "45",
      }, title: "أُلغيت الشحنة")!;
      expect(canceled.type, RoutePushEventType.shipmentCanceled);
      expect(canceled.routeId, 12);
      expect(canceled.stopId, 42);
      expect(canceled.returnToBase, isTrue);
      expect(canceled.returnStopId, 45);
      expect(canceled.isBlocking, isTrue);
      expect(canceled.routeClosed, isFalse);
      expect(canceled.removesRoute, isFalse);
      expect(canceled.title, "أُلغيت الشحنة");

      final closed = RoutePushEvent.fromData({
        "click_action": "route",
        "event_code": "shipment_canceled",
        "route_id": "12",
        "route_status": "canceled",
        "return_to_base": "0",
        "route_closed": "1",
      })!;
      expect(closed.routeClosed, isTrue);
      expect(closed.removesRoute, isTrue);
      expect(RouteStatusData.fromApi(closed.routeStatus), RouteStatus.cancelled);

      final routeGone = RoutePushEvent.fromData({
        "click_action": "route",
        "event_code": "route_canceled",
        "route_id": 12,
        "route_date": "2026-09-19",
        "return_to_base": "0",
      })!;
      expect(routeGone.type, RoutePushEventType.routeCanceled);
      expect(routeGone.returnToBase, isFalse);
      expect(routeGone.removesRoute, isTrue);

      final removed = RoutePushEvent.fromData({"click_action": "route", "event_code": "route_stop_removed"})!;
      expect(removed.type, RoutePushEventType.stopRemoved);
      expect(removed.isBlocking, isFalse);

      expect(RoutePushEvent.fromData({"click_action": "incident", "event_code": "incident_created"}), isNull);
    });

    test("json utils keep leading zeros and parse server dates", () {
      expect(JsonUtils.asString("0501234567"), "0501234567");
      expect(JsonUtils.asInt("12"), 12);
      expect(JsonUtils.asDouble("4.5"), 4.5);
      expect(JsonUtils.asBool("1"), isTrue);
      expect(JsonUtils.asDate("2026-08-26 14:03:11")!.hour, 14);
      expect(JsonUtils.formatServerDateTime(DateTime(2026, 8, 26, 14, 3, 11)), "2026-08-26 14:03:11");
    });
  });
}
