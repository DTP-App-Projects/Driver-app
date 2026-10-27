import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_call.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_response.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_service.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/endpoints.dart';
import 'package:digital_trade_portal_driver/features/emergency/data/models/issue_type.dart';
import 'package:digital_trade_portal_driver/features/emergency/data/repos/incidents_repo.dart';

class IncidentsRepoImpl implements IncidentsRepo {
  final ApiService apiService;

  IncidentsRepoImpl(this.apiService);

  /// The report call answers bare `{msg, incident}`, the lifecycle calls the
  /// wrapped `{status, data}`; both may carry the row under either key.
  IncidentModel? _incidentFrom(ApiResponse response) {
    final json = JsonUtils.asMapOrNull(response.body["incident"] ?? response.dataMap["incident"] ?? response.data);
    return json == null || json["id"] == null ? null : IncidentModel.fromJson(json);
  }

  @override
  Future<Either<Failure, IncidentModel?>> reportIncident({
    required IssueType type,
    required IssueSeverity severity,
    String? description,
    int? routeId,
    int? stopId,
    double? latitude,
    double? longitude,
  }) {
    return apiCall(
      () => apiService.postData(
        endPoint: EndPoints.reportIncident,
        data: {
          "incident_type": type.apiValue,
          "severity": severity.apiValue,
          if (description != null && description.isNotEmpty) "description": description,
          "route_id": ?routeId,
          "stop_id": ?stopId,
          "latitude": ?latitude,
          "longitude": ?longitude,
        },
      ),
      _incidentFrom,
    );
  }

  @override
  Future<Either<Failure, IncidentModel?>> acknowledge({required int incidentId, String? notes}) {
    return apiCall(
      () => apiService.postData(
        endPoint: EndPoints.incidentAcknowledge(incidentId),
        data: {if (notes != null && notes.isNotEmpty) "notes": notes},
      ),
      _incidentFrom,
    );
  }

  @override
  Future<Either<Failure, IncidentModel?>> investigate({required int incidentId, String? notes}) {
    return apiCall(
      () => apiService.postData(
        endPoint: EndPoints.incidentInvestigate(incidentId),
        data: {if (notes != null && notes.isNotEmpty) "notes": notes},
      ),
      _incidentFrom,
    );
  }

  @override
  Future<Either<Failure, IncidentModel?>> resolve({
    required int incidentId,
    required String resolutionNotes,
    String outcome = "resolved",
  }) {
    return apiCall(
      () => apiService.postData(
        endPoint: EndPoints.incidentResolve(incidentId),
        data: {"resolution_notes": resolutionNotes, "outcome": outcome},
      ),
      _incidentFrom,
    );
  }

  @override
  Future<Either<Failure, IncidentModel?>> reopen({required int incidentId, required String reason}) {
    return apiCall(
      () => apiService.postData(endPoint: EndPoints.incidentReopen(incidentId), data: {"reason": reason}),
      _incidentFrom,
    );
  }

  @override
  Future<Either<Failure, IncidentAgeModel>> getAge({required int incidentId}) {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.incidentAge(incidentId)),
      (response) => IncidentAgeModel.fromJson(response.dataMap),
    );
  }
}
