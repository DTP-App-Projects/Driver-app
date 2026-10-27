import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/location_service.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/offline_queue.dart';
import 'package:digital_trade_portal_driver/features/emergency/data/models/issue_type.dart';
import 'package:digital_trade_portal_driver/features/emergency/data/repos/incidents_repo.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/sync_event.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo.dart';

part 'report_incident_state.dart';

/// Sends the road incident form to `POST /driver/incidents`. Photos go
/// through the driver upload endpoint first (the incident body has no file
/// field), and their stored paths are appended to the description so the
/// fleet console can open them. Offline, the report is queued for
/// `sync/batch` under the `incident` action.
class ReportIncidentCubit extends Cubit<ReportIncidentState> {
  ReportIncidentCubit({
    required this.incidentsRepo,
    required this.routesRepo,
    required this.offlineQueue,
    LocationService? locationService,
  }) : locationService = locationService ?? const LocationService(),
       super(ReportIncidentInitial());

  final IncidentsRepo incidentsRepo;
  final RoutesRepo routesRepo;
  final OfflineQueue offlineQueue;
  final LocationService locationService;

  Future<void> report({
    required IssueType type,
    required IssueSeverity severity,
    required String description,
    List<File> photos = const [],
    int? routeId,
    int? stopId,
  }) async {
    if (state is ReportIncidentLoadingState) return;
    emit(ReportIncidentLoadingState());

    final position = await locationService.currentPosition();

    final uploaded = <String>[];
    for (final photo in photos) {
      final result = await routesRepo.uploadAttachment(file: photo, module: "incident");
      result.fold((_) {}, (upload) => uploaded.add(upload.filePath));
    }
    if (isClosed) return;

    final fullDescription = uploaded.isEmpty
        ? description
        : "$description\n\nAttachments:\n${uploaded.map((path) => "- $path").join("\n")}";

    final result = await incidentsRepo.reportIncident(
      type: type,
      severity: severity,
      description: fullDescription,
      routeId: routeId,
      stopId: stopId,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
    if (isClosed) return;

    result.fold((failure) {
      if (failure.isNetwork) {
        offlineQueue.enqueue(
          SyncEvent(
            actionType: SyncActionType.incident,
            payload: {
              "incident_type": type.apiValue,
              "severity": severity.apiValue,
              "description": fullDescription,
              "route_id": ?routeId,
              "stop_id": ?stopId,
              "latitude": ?position?.latitude,
              "longitude": ?position?.longitude,
            },
          ),
        );
        emit(ReportIncidentQueuedState());
        return;
      }
      emit(ReportIncidentErrorState(errMessage: failure.errMessage));
    }, (incident) => emit(ReportIncidentSuccessState(incident: incident)));
  }
}
