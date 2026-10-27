import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/features/my_cars/data/models/vehicle_model.dart';
import 'package:digital_trade_portal_driver/features/my_cars/data/repos/vehicles_repo.dart';

part 'vehicles_state.dart';

/// Available fleet vehicles plus the one assigned to the driver.
class VehiclesCubit extends Cubit<VehiclesState> {
  VehiclesCubit(this.repo, {VehicleModel? assigned}) : super(VehiclesState(assigned: assigned));
  final VehiclesRepo repo;

  Future<void> loadVehicles() async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final result = await repo.getAvailableVehicles();
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, failure: failure)),
      (vehicles) => emit(state.copyWith(vehicles: _mark(vehicles, state.assigned), isLoading: false, hasLoaded: true)),
    );
  }

  /// `PUT /driver/vehicle`. Returns the vehicle once the server accepted it
  /// so the profile can update its default vehicle.
  Future<VehicleModel?> assign(VehicleModel vehicle) async {
    if (state.assigningId != null) return null;
    emit(state.copyWith(assigningId: vehicle.id));

    final result = await repo.assignVehicle(vehicleId: vehicle.id);
    if (isClosed) return null;

    return result.fold(
      (failure) {
        emit(state.copyWith(clearAssigning: true, message: VehiclesMessage(text: failure.errMessage, isError: true)));
        return null;
      },
      (_) {
        emit(
          state.copyWith(
            assigned: vehicle,
            vehicles: _mark(state.vehicles, vehicle),
            clearAssigning: true,
            message: VehiclesMessage(text: tr("vehicle_assigned")),
          ),
        );
        return vehicle;
      },
    );
  }

  List<VehicleModel> _mark(List<VehicleModel> vehicles, VehicleModel? assigned) {
    for (final item in vehicles) {
      item.isAssigned = assigned != null && item.id == assigned.id;
    }
    return vehicles;
  }
}
