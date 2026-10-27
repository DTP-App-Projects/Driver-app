import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/features/emergency/data/models/issue_type.dart';

/// 09 · Incidents.
abstract class IncidentsRepo {
  /// `POST /api/v2/driver/incidents`.
  Future<Either<Failure, IncidentModel?>> reportIncident({
    required IssueType type,
    required IssueSeverity severity,
    String? description,
    int? routeId,
    int? stopId,
    double? latitude,
    double? longitude,
  });

  /// `POST /api/v2/incidents/{id}/acknowledge`.
  Future<Either<Failure, IncidentModel?>> acknowledge({required int incidentId, String? notes});

  /// `POST /api/v2/incidents/{id}/investigate`.
  Future<Either<Failure, IncidentModel?>> investigate({required int incidentId, String? notes});

  /// `POST /api/v2/incidents/{id}/resolve`.
  Future<Either<Failure, IncidentModel?>> resolve({
    required int incidentId,
    required String resolutionNotes,
    String outcome = "resolved",
  });

  /// `POST /api/v2/incidents/{id}/reopen`.
  Future<Either<Failure, IncidentModel?>> reopen({required int incidentId, required String reason});

  /// `GET /api/v2/incidents/{id}/age`.
  Future<Either<Failure, IncidentAgeModel>> getAge({required int incidentId});
}
