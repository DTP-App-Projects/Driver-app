import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/cache_helper.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/sync_event.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo.dart';

/// Durable queue of driver actions taken without connectivity. Events keep
/// their `client_uuid` across retries so `POST /driver/sync/batch` can
/// deduplicate them; the queue survives app restarts through shared
/// preferences.
class OfflineQueue {
  OfflineQueue(this.routesRepo) {
    _load();
  }

  final RoutesRepo routesRepo;

  static const String _storageKey = "offlineSyncQueue";

  final List<SyncEvent> _events = [];
  final StreamController<List<SyncEvent>> _changes = StreamController.broadcast();
  final StreamController<SyncRejection> _rejections = StreamController.broadcast();
  final Map<int, SyncRejection> _rejectedByStop = {};
  bool _flushing = false;

  List<SyncEvent> get events => List.unmodifiable(_events);

  int get pendingCount => _events.length;

  bool get isEmpty => _events.isEmpty;

  Stream<List<SyncEvent>> get changes => _changes.stream;

  /// Pickups / deliveries the server refused at sync time for a reason the
  /// driver has to fix; see [SyncRejection].
  Stream<SyncRejection> get rejections => _rejections.stream;

  /// The last refusal for [stopId], kept until the driver redoes the stop.
  SyncRejection? rejectionForStop(int stopId) => _rejectedByStop[stopId];

  void clearRejection(int stopId) => _rejectedByStop.remove(stopId);

  /// Events still waiting for [stopId].
  List<SyncEvent> pendingForStop(int stopId) => [
    for (final event in _events)
      if (event.stopId == stopId) event,
  ];

  bool hasPendingForStop(int stopId) => _events.any((event) => event.stopId == stopId);

  void _load() {
    final stored = CacheHelper.getListOFData(key: _storageKey);
    if (stored is! List) return;
    for (final item in stored) {
      try {
        final event = SyncEvent.fromStorageJson(JsonUtils.asMap(jsonDecode(item.toString())));
        if (event != null) _events.add(event);
      } catch (_) {
        // A corrupt entry is dropped rather than blocking the whole queue.
      }
    }
  }

  Future<void> _persist() async {
    await CacheHelper.saveData(
      key: _storageKey,
      value: [for (final event in _events) jsonEncode(event.toStorageJson())],
    );
    _changes.add(events);
  }

  Future<SyncEvent> enqueue(SyncEvent event) async {
    if (!event.isSendable) {
      // A proof without its picture: the server would only fail it.
      debugPrint("OfflineQueue: dropped ${event.actionType.apiValue} without a file");
      return event;
    }
    _events.removeWhere((item) => item.clientUuid == event.clientUuid);
    _events.add(event);
    _events.sort((a, b) => a.clientCreatedAt.compareTo(b.clientCreatedAt));
    await _persist();
    debugPrint("OfflineQueue: queued ${event.actionType.apiValue} (${_events.length} pending)");
    return event;
  }

  Future<void> remove(String clientUuid) async {
    _events.removeWhere((item) => item.clientUuid == clientUuid);
    await _persist();
  }

  Future<void> clear() async {
    _events.clear();
    await _persist();
  }

  /// Drops whatever is queued for [stopIds] — the stops of a route the
  /// supplier canceled, which the server would refuse anyway.
  Future<void> removeForStops(Iterable<int> stopIds) async {
    final ids = stopIds.toSet();
    final before = _events.length;
    _events.removeWhere((event) => ids.contains(event.stopId));
    if (_events.length != before) await _persist();
  }

  /// Replays the queue in one batch. Returns the results the server sent,
  /// or null when the request itself could not be made (still offline).
  Future<List<SyncResult>?> flush() async {
    if (_flushing || _events.isEmpty) return null;
    _flushing = true;

    try {
      final batch = List<SyncEvent>.of(_events);
      final result = await routesRepo.syncBatch(events: batch);

      final List<SyncResult>? results = result.fold(
        // The whole batch was rejected for a non transient reason: recorded
        // on every event so the UI can show what is stuck.
        (failure) => failure.isRetryable
            ? null
            : [for (final event in batch) SyncResult.failed(event, error: failure.errMessage)],
        (items) => items,
      );
      if (results == null) return null;

      for (final item in results) {
        final uuid = item.clientUuid;
        if (uuid == null) continue;
        final event = _events.where((event) => event.clientUuid == uuid).firstOrNull;
        if (item.isDone) {
          _events.removeWhere((event) => event.clientUuid == uuid);
        } else if (event != null && SyncRejection.applies(event, item)) {
          // Retrying cannot help: drop it so the stop reopens for the driver.
          _events.remove(event);
          final rejection = SyncRejection(event: event, result: item);
          final stopId = event.stopId;
          if (stopId != null) _rejectedByStop[stopId] = rejection;
          _rejections.add(rejection);
        } else {
          for (final event in _events.where((event) => event.clientUuid == uuid)) {
            event.attempts += 1;
            event.lastError = item.error ?? item.reason ?? item.status;
          }
        }
      }

      _persist();
      return results;
    } finally {
      _flushing = false;
    }
  }

  void dispose() {
    _changes.close();
    _rejections.close();
  }
}
