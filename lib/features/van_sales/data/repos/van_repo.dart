import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_delivery_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_sale_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_trip_model.dart';

/// 15 · Van sales: the supplier loads stock on the driver's van, the driver
/// sells and delivers from it on the road and returns what is left.
abstract class VanRepo {
  /// `GET /api/v2/driver/van/trip` — null when there is no open trip.
  Future<Either<Failure, VanTripModel?>> getCurrentTrip();

  /// `POST /api/v2/driver/van/trips/{trip_id}/load` (status `draft`).
  Future<Either<Failure, VanTripModel?>> confirmLoad({
    required int tripId,
    required String loadCode,
    String? signaturePath,
    String? signerName,
  });

  /// `POST /api/v2/driver/van/trips/{trip_id}/sales` (status `on_road`).
  Future<Either<Failure, VanSaleResult>> recordSale({required VanSaleRequest request});

  /// `GET /api/v2/driver/van/trips/{trip_id}/sales`.
  Future<Either<Failure, List<VanSaleModel>>> getSales({required int tripId});

  /// `GET /api/v2/driver/van/trips/{trip_id}/traders`.
  Future<Either<Failure, List<VanTrader>>> getTraders({required int tripId});

  /// `POST /api/v2/driver/van/trips/{trip_id}/deliveries`.
  Future<Either<Failure, VanDeliveryResult>> createDelivery({required int tripId, required VanDeliveryRequest request});

  /// `POST /api/v2/driver/van/trips/{trip_id}/return` with the driver's own
  /// count (sku id → returned qty), which is optional.
  Future<Either<Failure, VanTripModel?>> startReturn({required int tripId, Map<int, double> returnedQty = const {}});
}
