import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_call.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_service.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/endpoints.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_delivery_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_sale_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_trip_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/repos/van_repo.dart';

class VanRepoImpl implements VanRepo {
  final ApiService apiService;

  VanRepoImpl(this.apiService);

  @override
  Future<Either<Failure, VanTripModel?>> getCurrentTrip() {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.vanTrip),
      (response) => VanTripModel.maybeFrom(response.body["trip"]),
    );
  }

  @override
  Future<Either<Failure, VanTripModel?>> confirmLoad({
    required int tripId,
    required String loadCode,
    String? signaturePath,
    String? signerName,
  }) {
    return apiCall(
      () => apiService.postData(
        endPoint: EndPoints.vanTripLoad(tripId),
        data: {
          "load_code": loadCode,
          if (signaturePath != null && signaturePath.isNotEmpty) "signature_path": signaturePath,
          if (signerName != null && signerName.trim().isNotEmpty) "signer_name": signerName.trim(),
        },
      ),
      (response) => VanTripModel.maybeFrom(response.body["trip"]),
    );
  }

  @override
  Future<Either<Failure, VanSaleResult>> recordSale({required VanSaleRequest request}) {
    return apiCall(
      () => apiService.postData(endPoint: EndPoints.vanTripSales(request.tripId), data: request.toApiJson()),
      (response) => VanSaleResult(
        sale: VanSaleModel.fromJson(JsonUtils.asMap(response.body["sale"])),
        trip: VanTripModel.maybeFrom(response.body["trip"]),
      ),
    );
  }

  @override
  Future<Either<Failure, List<VanSaleModel>>> getSales({required int tripId}) {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.vanTripSales(tripId)),
      (response) => [for (final item in JsonUtils.asMapList(response.body["sales"])) VanSaleModel.fromJson(item)],
    );
  }

  @override
  Future<Either<Failure, List<VanTrader>>> getTraders({required int tripId}) {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.vanTripTraders(tripId)),
      (response) => [for (final item in JsonUtils.asMapList(response.body["traders"])) VanTrader.fromJson(item)],
    );
  }

  @override
  Future<Either<Failure, VanDeliveryResult>> createDelivery({
    required int tripId,
    required VanDeliveryRequest request,
  }) {
    return apiCall(() => apiService.postData(endPoint: EndPoints.vanTripDeliveries(tripId), data: request.toJson()), (
      response,
    ) {
      final stop = JsonUtils.asMap(response.body["stop"]);
      final trip = VanTripModel.maybeFrom(response.body["trip"]);
      return VanDeliveryResult(
        stop: RouteStop.fromJson(stop),
        deliveryRouteId: JsonUtils.asInt(stop["delivery_route_id"]) ?? trip?.deliveryRouteId,
        trip: trip,
      );
    });
  }

  @override
  Future<Either<Failure, VanTripModel?>> startReturn({required int tripId, Map<int, double> returnedQty = const {}}) {
    return apiCall(
      () => apiService.postData(
        endPoint: EndPoints.vanTripReturn(tripId),
        data: {
          if (returnedQty.isNotEmpty)
            "lines": [
              for (final entry in returnedQty.entries) {"sku_id": entry.key, "returned_qty": vanQty(entry.value)},
            ],
        },
      ),
      (response) => VanTripModel.maybeFrom(response.body["trip"]),
    );
  }
}
