part of 'report_incident_cubit.dart';

sealed class ReportIncidentState {}

final class ReportIncidentInitial extends ReportIncidentState {}

final class ReportIncidentLoadingState extends ReportIncidentState {}

final class ReportIncidentSuccessState extends ReportIncidentState {
  final IncidentModel? incident;

  ReportIncidentSuccessState({this.incident});
}

/// Stored locally, will reach the server with the next sync.
final class ReportIncidentQueuedState extends ReportIncidentState {}

final class ReportIncidentErrorState extends ReportIncidentState {
  final String errMessage;

  ReportIncidentErrorState({required this.errMessage});
}
