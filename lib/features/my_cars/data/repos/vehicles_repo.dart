import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/features/my_cars/data/models/vehicle_model.dart';

/// 02 · Vehicles.
abstract class VehiclesRepo {
  /// `GET /api/v2/driver/vehicles/available`.
  Future<Either<Failure, List<VehicleModel>>> getAvailableVehicles();

  /// `PUT /api/v2/driver/vehicle`.
  Future<Either<Failure, Unit>> assignVehicle({required int vehicleId});
}
