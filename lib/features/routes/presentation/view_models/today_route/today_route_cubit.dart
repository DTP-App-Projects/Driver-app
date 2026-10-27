import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/location_tracker.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/offline_queue.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/push_event_bus.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/session_manager.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_push_event.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/sync_event.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo.dart';

part 'today_route_state.dart';

/// Owns `GET /driver/today_route` for the session: the home card, the route
/// details screen and the delivery screen all read the same payload, and
/// every stop / route mutation is folded back in here so no screen shows a
/// stale status.
class TodayRouteCubit extends Cubit<TodayRouteState> {
  TodayRouteCubit({
    required this.routesRepo,
    required this.locationTracker,
    required this.offlineQueue,
    PushEventBus? pushEvents,
  }) : super(const TodayRouteState()) {
    SessionManager.addSessionClearedListener(reset);
    // Once queued offline actions went through, the server statuses moved on.
    _queueSubscription = offlineQueue.changes.listen((events) {
      final bool drained = _hadPending && events.isEmpty;
      _hadPending = events.isNotEmpty;
      if (drained && !isClosed && state.hasData) loadTodayRoute(silent: true);
    });
    _hadPending = !offlineQueue.isEmpty;

    if (pushEvents != null) {
      _pushSubscription = pushEvents.events.listen((event) {
        pushEvents.takePending();
        handlePushEvent(event);
      });
      // A push that arrived before this cubit existed (cold start from the
      // notification tap) is handled on the first load instead.
      _pendingPush = pushEvents.takePending();
    }
  }

  final RoutesRepo routesRepo;
  final LocationTracker locationTracker;
  final OfflineQueue offlineQueue;

  int _token = 0;
  StreamSubscription<List<SyncEvent>>? _queueSubscription;
  StreamSubscription<RoutePushEvent>? _pushSubscription;
  RoutePushEvent? _pendingPush;
  bool _reloadAfterCurrent = false;
  int _loadSequence = 0;
  bool _hadPending = false;

  int get _nextToken => ++_token;

  @override
  Future<void> close() {
    SessionManager.removeSessionClearedListener(reset);
    _queueSubscription?.cancel();
    _pushSubscription?.cancel();
    return super.close();
  }

  void reset() {
    if (!isClosed) emit(const TodayRouteState());
  }

  // ------------------------------------------------------------ push events

  /// A route push from the supplier side: the payload is fetched again right
  /// away, and a cancellation stays on screen as an alert until dismissed.
  Future<void> handlePushEvent(RoutePushEvent event) async {
    if (isClosed) return;

    if (event.removesRoute) await _purgeRoute(event.routeId);

    if (event.isBlocking) {
      emit(
        state.copyWith(
          alert: RouteAlert(token: _nextToken, event: event),
        ),
      );
    }

    // A load already in flight may have been answered before the change
    // landed, so one more runs right after it.
    if (state.isLoading) {
      _reloadAfterCurrent = true;
    } else {
      await loadTodayRoute(silent: state.hasData);
    }
  }

  void dismissAlert() {
    if (state.alert != null) emit(state.copyWith(clearAlert: true));
  }

  /// The route is gone on the server (canceled, or closed because no open
  /// stop was left): forget what was queued for its stops and drop it from
  /// the payload so no screen keeps offering it.
  Future<void> _purgeRoute(int? routeId) async {
    final data = state.data;
    final route = routeId == null ? null : data?.routeById(routeId);
    if (data == null || route == null) return;

    await offlineQueue.removeForStops([for (final stop in route.stops) stop.id]);
    if (isClosed) return;

    emit(
      state.copyWith(
        data: TodayRouteModel(
          route: data.route?.id == routeId ? null : data.route,
          eta: data.route?.id == routeId ? null : data.eta,
          lateRoutes: [
            for (final item in data.lateRoutes)
              if (item.id != routeId) item,
          ],
          upcomingRoutes: [
            for (final item in data.upcomingRoutes)
              if (item.id != routeId) item,
          ],
        ),
      ),
    );
    _syncTracking();
  }

  /// [silent] keeps the current list on screen instead of a loader, for
  /// refreshes after a mutation.
  Future<void> loadTodayRoute({bool silent = false}) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: !silent, clearFailure: true));

    // Replay anything queued offline first so the payload reflects it.
    if (!offlineQueue.isEmpty) await offlineQueue.flush();

    // Silent refreshes may overlap (push, app resume, queue drained); only
    // the answer to the latest request may land, or a stale one would undo it.
    final sequence = ++_loadSequence;
    final result = await routesRepo.getTodayRoute();
    if (isClosed || sequence != _loadSequence) return;

    result.fold((failure) => emit(state.copyWith(isLoading: false, failure: failure)), (data) {
      emit(state.copyWith(data: data, revision: state.revision + 1, isLoading: false, clearFailure: true));
      _syncTracking();
    });

    final pending = _pendingPush;
    if (pending != null) {
      _pendingPush = null;
      if (pending.isBlocking) {
        emit(
          state.copyWith(
            alert: RouteAlert(token: _nextToken, event: pending),
          ),
        );
      }
    }

    if (_reloadAfterCurrent) {
      _reloadAfterCurrent = false;
      await loadTodayRoute(silent: true);
    }
  }

  /// `assigned → in_progress`. The server flips the first stop to en_route,
  /// so the payload is fetched again afterwards.
  Future<bool> startRoute(RouteModel route) async {
    if (state.submittingRouteId != null) return false;
    emit(state.copyWith(submittingRouteId: route.id));

    final result = await routesRepo.startRoute(routeId: route.id);
    if (isClosed) return false;

    return await result.fold(
      (failure) {
        emit(state.copyWith(clearSubmitting: true, message: _error(failure.errMessage)));
        return false;
      },
      (updated) async {
        _applyRoute(updated ?? route.copyWith(status: RouteStatus.inProgress));
        emit(state.copyWith(clearSubmitting: true, message: _info(tr("api_route_started"))));
        await loadTodayRoute(silent: true);
        return true;
      },
    );
  }

  /// `in_progress → completed`, then the end of day summary for the closing
  /// screen.
  Future<bool> completeRoute(RouteModel route) async {
    if (state.submittingRouteId != null) return false;
    emit(state.copyWith(submittingRouteId: route.id));

    final result = await routesRepo.completeRoute(routeId: route.id);
    if (isClosed) return false;

    return await result.fold(
      (failure) {
        emit(state.copyWith(clearSubmitting: true, message: _error(failure.errMessage)));
        return false;
      },
      (updated) async {
        _applyRoute(updated ?? route.copyWith(status: RouteStatus.completed));
        emit(state.copyWith(clearSubmitting: true, message: _info(tr("api_route_completed"))));
        await locationTracker.stop();
        await loadEndOfDaySummary();
        await loadTodayRoute(silent: true);
        return true;
      },
    );
  }

  Future<void> loadEndOfDaySummary({String? date}) async {
    final result = await routesRepo.getEndOfDaySummary(date: date);
    if (isClosed) return;
    result.fold((_) {}, (summary) => emit(state.copyWith(summary: summary)));
  }

  /// Folds a stop the server returned (arrive, pickup, deliver, skip) into
  /// whichever route holds it.
  void applyStop(RouteStop stop) {
    final data = state.data;
    if (data == null) return;

    for (final route in data.allRoutes) {
      if (route.stops.any((item) => item.id == stop.id)) {
        _applyRoute(route.withStop(stop));
        return;
      }
    }
  }

  void _applyRoute(RouteModel route) {
    final data = state.data;
    if (data == null) return;
    emit(state.copyWith(data: data.withRoute(route)));
    _syncTracking();
  }

  /// Location pings (and live sharing) run only while a route is in
  /// progress; a completed, canceled or closed route stops them, which also
  /// removes the Firebase node.
  void _syncTracking() {
    final active = state.activeRoute;
    if (active != null) {
      locationTracker.start(routeId: active.id);
    } else if (locationTracker.isRunning) {
      locationTracker.stop();
    }
  }

  RouteMessage _error(String text) => RouteMessage(token: _nextToken, text: text, isError: true);

  RouteMessage _info(String text) => RouteMessage(token: _nextToken, text: text);
}
