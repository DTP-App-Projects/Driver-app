import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_call.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_service.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/endpoints.dart';
import 'package:digital_trade_portal_driver/features/my_cars/data/models/vehicle_model.dart';
import 'package:digital_trade_portal_driver/features/my_cars/data/repos/vehicles_repo.dart';

class VehiclesRepoImpl implements VehiclesRepo {
  final ApiService apiService;

  VehiclesRepoImpl(this.apiService);

  @override
  Future<Either<Failure, List<VehicleModel>>> getAvailableVehicles() {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.availableVehicles),
      (response) => VehicleModel.listFromJson(response.data),
    );
  }

  @override
  Future<Either<Failure, Unit>> assignVehicle({required int vehicleId}) {
    return apiCall(
      () => apiService.putData(endPoint: EndPoints.assignVehicle, data: {"vehicle_id": vehicleId}),
      (_) => unit,
    );
  }
}
