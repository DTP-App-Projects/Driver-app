part of 'today_route_cubit.dart';

/// One off toast for the driver; [token] distinguishes a new message from a
/// rebuild that still carries the old one.
class RouteMessage {
  const RouteMessage({required this.token, required this.text, this.isError = false});

  final int token;
  final String text;
  final bool isError;
}

/// A supplier side change pushed while the driver works (shipment or route
/// canceled). Stays on the route screen until the driver dismisses it.
class RouteAlert {
  const RouteAlert({required this.token, required this.event});

  final int token;
  final RoutePushEvent event;

  int? get routeId => event.routeId;

  bool get isRouteCanceled => event.type == RoutePushEventType.routeCanceled;

  /// The route was closed by the server because nothing was left on it.
  bool get isRouteClosed => event.routeClosed;

  /// `completed` / `canceled` as the server closed it, when the push says.
  RouteStatus? get closedStatus => event.routeStatus == null ? null : RouteStatusData.fromApi(event.routeStatus);

  /// The goods of the canceled shipment are on the truck: a `return_to_base`
  /// stop was added at the end of the route.
  bool get returnToBase => event.returnToBase;

  /// Whether the alert concerns [routeId] (or any route when the push did
  /// not name one).
  bool concerns(int routeId) => event.routeId == null || event.routeId == routeId;
}

class TodayRouteState {
  const TodayRouteState({
    this.data,
    this.revision = 0,
    this.isLoading = false,
    this.failure,
    this.submittingRouteId,
    this.summary,
    this.message,
    this.alert,
  });

  /// Last successful `today_route` payload, kept while a refresh runs.
  final TodayRouteModel? data;

  /// Bumped on every payload fetched from the server, so screens holding
  /// their own copy of a route know when to take the server's version.
  final int revision;
  final bool isLoading;

  /// Why the last load failed; [data] may still hold the previous payload.
  final Failure? failure;

  /// Route whose start / complete request is in flight.
  final int? submittingRouteId;

  /// End of day summary fetched after the route was completed.
  final EndOfDaySummaryModel? summary;
  final RouteMessage? message;

  /// Pending supplier alert, null once dismissed.
  final RouteAlert? alert;

  bool get hasData => data != null;

  /// The alert to show on the screen of [routeId], if any.
  RouteAlert? alertFor(int routeId) => alert != null && alert!.concerns(routeId) ? alert : null;

  RouteModel? get route => data?.route;

  /// Every route the home card lists: today's, overdue ones, upcoming ones.
  List<RouteModel> get routes => data?.allRoutes ?? const [];

  /// The route currently being driven, wherever it sits in the payload.
  RouteModel? get activeRoute {
    for (final route in routes) {
      if (route.isInProgress) return route;
    }
    return null;
  }

  bool isSubmitting(int routeId) => submittingRouteId == routeId;

  TodayRouteState copyWith({
    TodayRouteModel? data,
    int? revision,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
    int? submittingRouteId,
    bool clearSubmitting = false,
    EndOfDaySummaryModel? summary,
    bool clearSummary = false,
    RouteMessage? message,
    RouteAlert? alert,
    bool clearAlert = false,
  }) {
    return TodayRouteState(
      data: data ?? this.data,
      revision: revision ?? this.revision,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
      submittingRouteId: clearSubmitting ? null : submittingRouteId ?? this.submittingRouteId,
      summary: clearSummary ? null : summary ?? this.summary,
      message: message ?? this.message,
      alert: clearAlert ? null : alert ?? this.alert,
    );
  }
}
