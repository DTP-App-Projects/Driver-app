import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/live_session_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo.dart';

/// Shares the driver position with the trader in real time through Firebase
/// Realtime Database (`live/drivers/{driverId}`), on top of the history the
/// [LocationTracker] keeps sending to Laravel.
///
/// Best effort by design: any failure (server not configured, no route,
/// auth, rules, plugin) leaves [isLive] false and the app works exactly as
/// before. The Firebase sign-in is separate from the app's own login.
class LiveLocationPublisher {
  LiveLocationPublisher({required this.routesRepo});

  final RoutesRepo routesRepo;

  /// Renew this long before the custom token expires.
  static const Duration renewBefore = Duration(minutes: 10);

  /// A fix is worth writing when the driver moved this far or this long
  /// passed since the last write.
  static const double minMoveMeters = 10;
  static const Duration minWriteGap = Duration(seconds: 5);

  LiveSessionModel _session = LiveSessionModel.disabled;
  DatabaseReference? _ref;
  Timer? _writeTimer;
  Timer? _renewTimer;
  StreamSubscription<DatabaseEvent>? _connectedSubscription;
  bool _connected = true;
  bool _starting = false;

  /// One renewal per permission error: set when a renewal was made because
  /// of a denial, cleared by the next successful write. A denial while set
  /// stops live sharing instead of looping.
  bool _renewedAfterDenial = false;

  Position? _latest;
  Position? _lastWritten;
  DateTime? _lastWriteAt;

  /// Writing to Firebase right now.
  bool get isLive => _ref != null && _session.isUsable;

  LiveSessionModel get session => _session;

  /// Fetches a session and starts writing when the server enables it.
  /// Returns the session, [LiveSessionModel.disabled] when live tracking is
  /// off or failed.
  Future<LiveSessionModel> start() async {
    if (_starting) return _session;
    _starting = true;
    try {
      final result = await routesRepo.getLiveSession();
      final session = result.fold((_) => LiveSessionModel.disabled, (value) => value);
      if (!session.isUsable) {
        await _teardown(removeNode: isLive);
        _session = LiveSessionModel.disabled;
        return _session;
      }

      await FirebaseAuth.instance.signInWithCustomToken(session.token!);
      final database = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: session.databaseUrl);
      final bool sameNode =
          _ref != null && _session.path == session.path && _session.databaseUrl == session.databaseUrl;

      _session = session;
      if (!sameNode) {
        _ref = database.ref(session.path!);
        await _connectedSubscription?.cancel();
        _connectedSubscription = database
            .ref(".info/connected")
            .onValue
            .listen((event) => _connected = event.snapshot.value == true, onError: (_) {});
      }

      _writeTimer?.cancel();
      _writeTimer = Timer.periodic(session.writeInterval, (_) => _writeLatest());
      _scheduleRenewal();
      debugPrint("LiveLocationPublisher: live on ${session.path}");
      return _session;
    } catch (error) {
      debugPrint("LiveLocationPublisher: disabled ($error)");
      await _teardown(removeNode: false);
      _session = LiveSessionModel.disabled;
      return _session;
    } finally {
      _starting = false;
    }
  }

  /// Latest fix; only the newest one is ever written, stale ones are dropped.
  void addPosition(Position position) => _latest = position;

  /// Stops writing, removes the node (the server also does when the route
  /// closes) and signs out of Firebase only.
  Future<void> stop() async {
    await _teardown(removeNode: true);
    _session = LiveSessionModel.disabled;
    _latest = null;
    _lastWritten = null;
    _lastWriteAt = null;
    _renewedAfterDenial = false;
  }

  void _scheduleRenewal() {
    _renewTimer?.cancel();
    final expiresAt = _session.expiresAt;
    if (expiresAt == null) return;
    var wait = expiresAt.difference(DateTime.now()) - renewBefore;
    if (wait.isNegative) wait = const Duration(minutes: 1);
    _renewTimer = Timer(wait, () => start());
  }

  /// Whether the session is about to expire, so a foreground return renews it.
  bool get needsRenewal {
    final expiresAt = _session.expiresAt;
    return expiresAt != null && expiresAt.difference(DateTime.now()) <= renewBefore;
  }

  Future<void> _writeLatest() async {
    final ref = _ref;
    final position = _latest;
    if (ref == null || position == null || !_session.isUsable) return;
    // Offline: the SDK would queue the write and replay a stale position.
    if (!_connected) return;

    final previous = _lastWritten;
    final lastAt = _lastWriteAt;
    final moved = previous == null
        ? double.infinity
        : Geolocator.distanceBetween(previous.latitude, previous.longitude, position.latitude, position.longitude);
    final waited = lastAt == null ? minWriteGap : DateTime.now().difference(lastAt);
    if (moved < minMoveMeters && waited < minWriteGap) return;

    try {
      await ref.set({
        "lat": position.latitude,
        "lng": position.longitude,
        "ts": ServerValue.timestamp,
        "sup": _session.sup,
        "route_id": ?_session.routeId,
        if (position.heading.isFinite && position.heading >= 0) "heading": position.heading,
        if (position.speed.isFinite && position.speed >= 0) "speed_kmh": position.speed * 3.6,
        if (position.accuracy.isFinite) "acc": position.accuracy,
      });
      _lastWritten = position;
      _lastWriteAt = DateTime.now();
      _renewedAfterDenial = false;
    } catch (error) {
      if (!_isPermissionDenied(error)) return;
      if (_renewedAfterDenial) {
        debugPrint("LiveLocationPublisher: denied again after renewal, live sharing stopped");
        await _teardown(removeNode: false);
        _session = LiveSessionModel.disabled;
        return;
      }
      _renewedAfterDenial = true;
      await start();
    }
  }

  static bool _isPermissionDenied(Object error) {
    final code = error is FirebaseException ? error.code : error.toString();
    return code.toLowerCase().contains("permission");
  }

  Future<void> _teardown({required bool removeNode}) async {
    _writeTimer?.cancel();
    _writeTimer = null;
    _renewTimer?.cancel();
    _renewTimer = null;
    await _connectedSubscription?.cancel();
    _connectedSubscription = null;

    final ref = _ref;
    _ref = null;
    try {
      // Bounded: offline, the SDK would hold the future until reconnected.
      if (removeNode && ref != null) await ref.remove().timeout(const Duration(seconds: 5));
    } catch (_) {}
    try {
      if (FirebaseAuth.instance.currentUser != null) await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
