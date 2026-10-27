import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/live_location_publisher.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/location_service.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/offline_queue.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/stop_execution_models.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/sync_event.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo.dart';

/// Feeds `POST /driver/location` while a route is in progress. Samples are
/// buffered and sent as one batch every [interval] — the shape the backend
/// is tuned for — and kept when the device is offline so the trail is
/// replayed with the original timestamps once connectivity returns.
///
/// When the server enables live tracking, [live] also writes the latest fix
/// to Firebase every few seconds for the trader, and the Laravel history
/// slows down to the session's `history_interval_seconds` (60 s).
///
/// Runs only while the app is alive: no background service, no wake locks.
class LocationTracker {
  LocationTracker({
    required this.routesRepo,
    required this.offlineQueue,
    LocationService? locationService,
    LiveLocationPublisher? live,
  }) : locationService = locationService ?? const LocationService(),
       live = live ?? LiveLocationPublisher(routesRepo: routesRepo);

  final RoutesRepo routesRepo;
  final OfflineQueue offlineQueue;
  final LocationService locationService;
  final LiveLocationPublisher live;

  /// Recommended by the API: 15–30 s while `in_progress`, without live tracking.
  static const Duration interval = Duration(seconds: 30);

  /// The most `POST /driver/location` takes in one call. Past this many
  /// buffered samples the batch moves to the offline queue, so a long outage
  /// neither grows unbounded nor is lost.
  static const int maxBufferedPoints = 500;

  StreamSubscription<Position>? _subscription;
  Timer? _timer;
  final List<LocationPoint> _buffer = [];
  bool _sending = false;
  int? _routeId;

  /// Bumped on every start / stop so a live session that arrives after the
  /// route ended is dropped.
  int _generation = 0;

  bool get isRunning => _subscription != null;

  /// Starts for the route being driven. Calling it again for the same route
  /// is a no-op; another route restarts the live session.
  Future<void> start({int? routeId}) async {
    if (isRunning) {
      if (routeId != null && routeId != _routeId) {
        _routeId = routeId;
        await _startLive();
      }
      return;
    }

    final failure = await locationService.ensurePermission();
    if (failure != null) {
      debugPrint("LocationTracker: not started ($failure)");
      return;
    }
    if (isRunning) return;

    _routeId = routeId;
    _subscription = locationService.positionStream().listen(_onPosition, onError: (_) {});
    _restartTimer(interval);
    debugPrint("LocationTracker: started");
    await _startLive();
  }

  Future<void> stop() async {
    _generation++;
    await _subscription?.cancel();
    _subscription = null;
    _timer?.cancel();
    _timer = null;
    _routeId = null;
    await live.stop();
    await flush();
    debugPrint("LocationTracker: stopped");
  }

  /// Back in the foreground with a route in progress: fetch a fresh live
  /// session (the old token may have expired while in the background).
  Future<void> onAppResumed() async {
    if (isRunning) await _startLive();
  }

  Future<void> _startLive() async {
    final generation = ++_generation;
    final session = await live.start();
    if (generation != _generation || !isRunning) {
      // The route ended while the session was on its way.
      if (!isRunning) await live.stop();
      return;
    }
    // Live: the trader follows Firebase, Laravel only needs the history.
    _restartTimer(session.isUsable ? session.historyInterval : interval);
  }

  void _restartTimer(Duration every) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => flush());
  }

  /// Lets a screen that already streams the position (the delivery map)
  /// share its fixes instead of opening a second GPS stream.
  void addPosition(Position position) => _onPosition(position);

  void _onPosition(Position position) {
    live.addPosition(position);
    _buffer.add(
      LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        loggedAt: position.timestamp,
        speedKmh: position.speed.isFinite && position.speed >= 0 ? position.speed * 3.6 : null,
        heading: position.heading.isFinite && position.heading >= 0 ? position.heading : null,
        accuracyMeters: position.accuracy.isFinite ? position.accuracy : null,
      ),
    );

    if (_buffer.length >= maxBufferedPoints) _spillToQueue();
  }

  /// Sends what was collected since the last tick, and replays anything the
  /// offline queue is holding while the network is back.
  Future<void> flush() async {
    if (!offlineQueue.isEmpty) await offlineQueue.flush();
    if (_sending || _buffer.isEmpty) return;
    _sending = true;

    final batch = List<LocationPoint>.of(_buffer.take(maxBufferedPoints));
    try {
      final result = await routesRepo.sendLocations(points: batch);
      result.fold((failure) {
        // Offline: keep the samples for the next tick; anything else is
        // dropped — a rejected ping is not worth retrying forever.
        if (!failure.isRetryable) _buffer.removeRange(0, batch.length);
      }, (_) => _buffer.removeRange(0, batch.length));
    } finally {
      _sending = false;
    }
  }

  void _spillToQueue() {
    final batch = List<LocationPoint>.of(_buffer);
    _buffer.clear();
    offlineQueue.enqueue(
      SyncEvent(
        actionType: SyncActionType.locationBatch,
        payload: {
          "locations": [for (final point in batch) point.toJson()],
        },
      ),
    );
  }
}
