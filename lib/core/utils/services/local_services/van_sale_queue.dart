import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/cache_helper.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_sale_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/repos/van_repo.dart';

/// A queued sale the server refused when it was finally sent (stock gone,
/// trip no longer on the road…). It is dropped so it is never retried.
class VanSaleRejection {
  const VanSaleRejection({required this.request, required this.failure});

  final VanSaleRequest request;
  final Failure failure;
}

/// Walk-in sales recorded without connectivity. The van sales endpoint is not
/// part of `POST /driver/sync/batch`, so each sale is replayed on its own
/// endpoint with its `client_uuid`: a retry returns the same sale, never a
/// second invoice. Survives app restarts through shared preferences.
class VanSaleQueue {
  VanSaleQueue(this.vanRepo) {
    _load();
  }

  final VanRepo vanRepo;

  static const String _storageKey = "vanSaleQueue";

  final List<VanSaleRequest> _sales = [];
  final StreamController<List<VanSaleRequest>> _changes = StreamController.broadcast();
  final StreamController<VanSaleRejection> _rejections = StreamController.broadcast();
  bool _flushing = false;

  List<VanSaleRequest> get sales => List.unmodifiable(_sales);

  bool get isEmpty => _sales.isEmpty;

  Stream<List<VanSaleRequest>> get changes => _changes.stream;

  Stream<VanSaleRejection> get rejections => _rejections.stream;

  List<VanSaleRequest> pendingForTrip(int tripId) => [
    for (final sale in _sales)
      if (sale.tripId == tripId) sale,
  ];

  void _load() {
    final stored = CacheHelper.getListOFData(key: _storageKey);
    if (stored is! List) return;
    for (final item in stored) {
      try {
        final sale = VanSaleRequest.fromStorageJson(JsonUtils.asMap(jsonDecode(item.toString())));
        if (sale != null) _sales.add(sale);
      } catch (_) {
        // A corrupt entry is dropped rather than blocking the whole queue.
      }
    }
  }

  Future<void> _persist() async {
    await CacheHelper.saveData(key: _storageKey, value: [for (final sale in _sales) jsonEncode(sale.toStorageJson())]);
    _changes.add(sales);
  }

  Future<void> enqueue(VanSaleRequest request) async {
    _sales.removeWhere((item) => item.clientUuid == request.clientUuid);
    _sales.add(request);
    await _persist();
    debugPrint("VanSaleQueue: queued sale ${request.clientUuid} (${_sales.length} pending)");
  }

  Future<void> clear() async {
    _sales.clear();
    await _persist();
  }

  /// Sends the queued sales in the order they were made. Stops at the first
  /// one that could not reach the server (still offline). Returns the sales
  /// the server recorded.
  Future<List<VanSaleResult>> flush() async {
    if (_flushing || _sales.isEmpty) return const [];
    _flushing = true;

    final recorded = <VanSaleResult>[];
    try {
      for (final request in List<VanSaleRequest>.of(_sales)) {
        final result = await vanRepo.recordSale(request: request);
        final bool keepGoing = result.fold(
          (failure) {
            if (failure.isRetryable) {
              request.lastError = failure.errMessage;
              return false;
            }
            _sales.remove(request);
            _rejections.add(VanSaleRejection(request: request, failure: failure));
            return true;
          },
          (sale) {
            _sales.remove(request);
            recorded.add(sale);
            return true;
          },
        );
        if (!keepGoing) break;
      }
      await _persist();
      return recorded;
    } finally {
      _flushing = false;
    }
  }

  void dispose() {
    _changes.close();
    _rejections.close();
  }
}
