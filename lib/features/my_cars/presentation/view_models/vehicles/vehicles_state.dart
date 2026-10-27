part of 'vehicles_cubit.dart';

/// Transient toast; a fresh instance per emit so listeners see each one.
class VehiclesMessage {
  const VehiclesMessage({required this.text, this.isError = false});

  final String text;
  final bool isError;
}

class VehiclesState {
  const VehiclesState({
    this.vehicles = const [],
    this.assigned,
    this.isLoading = false,
    this.hasLoaded = false,
    this.failure,
    this.assigningId,
    this.message,
  });

  final List<VehicleModel> vehicles;

  /// The driver's default vehicle, from the profile or the last assignment.
  final VehicleModel? assigned;
  final bool isLoading;
  final bool hasLoaded;
  final Failure? failure;
  final int? assigningId;
  final VehiclesMessage? message;

  VehiclesState copyWith({
    List<VehicleModel>? vehicles,
    VehicleModel? assigned,
    bool? isLoading,
    bool? hasLoaded,
    Failure? failure,
    bool clearFailure = false,
    int? assigningId,
    bool clearAssigning = false,
    VehiclesMessage? message,
  }) {
    return VehiclesState(
      vehicles: vehicles ?? this.vehicles,
      assigned: assigned ?? this.assigned,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      failure: clearFailure ? null : failure ?? this.failure,
      assigningId: clearAssigning ? null : assigningId ?? this.assigningId,
      message: message,
    );
  }
}
