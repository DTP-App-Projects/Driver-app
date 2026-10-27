import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/location_service.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/session_manager.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/van_sale_queue.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_delivery_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_sale_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_trip_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/repos/van_repo.dart';

part 'van_trip_state.dart';

/// Owns `GET /driver/van/trip` for the session: the home card and the trip
/// screen read the same trip, and every action folds the trip the server
/// answers with back in, then fetches it again so no screen shows stale stock.
class VanTripCubit extends Cubit<VanTripState> {
  VanTripCubit({required this.vanRepo, required this.routesRepo, required this.saleQueue})
    : super(const VanTripState()) {
    SessionManager.addSessionClearedListener(reset);
    _queueSubscription = saleQueue.changes.listen((_) => _syncPending());
    _rejectionSubscription = saleQueue.rejections.listen((rejection) {
      if (isClosed) return;
      emit(
        state.copyWith(
          message: _error(
            "van_sale_sync_rejected".tr(
              namedArgs: {"buyer": rejection.request.buyerName, "reason": rejection.failure.errMessage},
            ),
          ),
        ),
      );
    });
  }

  final VanRepo vanRepo;
  final RoutesRepo routesRepo;
  final VanSaleQueue saleQueue;

  StreamSubscription<List<VanSaleRequest>>? _queueSubscription;
  StreamSubscription<VanSaleRejection>? _rejectionSubscription;
  int _token = 0;
  int _loadSequence = 0;

  @override
  Future<void> close() {
    SessionManager.removeSessionClearedListener(reset);
    _queueSubscription?.cancel();
    _rejectionSubscription?.cancel();
    return super.close();
  }

  void reset() {
    if (!isClosed) emit(const VanTripState());
  }

  void _syncPending() {
    if (isClosed) return;
    final tripId = state.trip?.id;
    emit(state.copyWith(pendingSales: tripId == null ? const [] : saleQueue.pendingForTrip(tripId)));
  }

  /// [silent] keeps the current trip on screen instead of a skeleton.
  Future<void> loadTrip({bool silent = false}) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: !silent, clearFailure: true));

    // Sales made offline go first, so the stock below already reflects them.
    if (!saleQueue.isEmpty) {
      final recorded = await saleQueue.flush();
      if (isClosed) return;
      if (recorded.isNotEmpty) {
        emit(
          state.copyWith(
            sales: _mergeSales([for (final item in recorded) item.sale]),
            message: _info("van_sales_synced".tr(namedArgs: {"count": recorded.length.toString()})),
          ),
        );
      }
    }

    final sequence = ++_loadSequence;
    final result = await vanRepo.getCurrentTrip();
    if (isClosed || sequence != _loadSequence) return;

    result.fold((failure) => emit(state.copyWith(isLoading: false, hasLoaded: true, failure: failure)), (trip) {
      final previous = state.trip;
      final bool closed = previous != null && (trip == null || trip.id != previous.id);
      emit(
        VanTripState(
          trip: trip,
          hasLoaded: true,
          // A refresh never cancels a submit still running.
          busy: state.busy,
          // A different (or no) trip starts with empty lists.
          sales: closed ? const [] : state.sales,
          salesLoaded: closed ? false : state.salesLoaded,
          salesLoading: closed ? false : state.salesLoading,
          traders: closed ? const [] : state.traders,
          tradersLoaded: closed ? false : state.tradersLoaded,
          tradersLoading: closed ? false : state.tradersLoading,
          pendingSales: trip == null ? const [] : saleQueue.pendingForTrip(trip.id),
          message: closed && previous.isReturning && trip == null ? _info("van_trip_closed".tr()) : state.message,
        ),
      );
    });
  }

  void _applyTrip(VanTripModel? trip) {
    if (trip == null || isClosed) return;
    emit(state.copyWith(trip: trip));
    _syncPending();
  }

  // ------------------------------------------------------------------ load

  /// Uploads the signature first when there is one, then confirms the load
  /// with the code the warehouse keeper gave.
  Future<Either<Failure, VanTripModel?>> confirmLoad({
    required String loadCode,
    File? signature,
    String? signerName,
  }) async {
    final trip = state.trip;
    if (trip == null || state.busy != null) return left(CustomError("err_unexpected".tr()));
    emit(state.copyWith(busy: VanTripAction.load));

    String? signaturePath;
    if (signature != null) {
      final upload = await routesRepo.uploadAttachment(file: signature, module: "van_load_signature");
      if (isClosed) return left(CustomError("err_unexpected".tr()));
      final Failure? uploadFailure = upload.fold((failure) => failure, (result) {
        signaturePath = result.filePath;
        return null;
      });
      if (uploadFailure != null) {
        emit(state.copyWith(clearBusy: true));
        return left(uploadFailure);
      }
    }

    final result = await vanRepo.confirmLoad(
      tripId: trip.id,
      loadCode: loadCode,
      signaturePath: signaturePath,
      signerName: signerName,
    );
    if (isClosed) return result;

    emit(state.copyWith(clearBusy: true));
    result.fold((_) {}, (updated) {
      _applyTrip(updated);
      emit(state.copyWith(message: _info("van_load_confirmed".tr())));
      loadTrip(silent: true);
    });
    return result;
  }

  // ------------------------------------------------------------------ sell

  /// Records a walk-in sale. Offline (or a server hiccup) the sale is queued
  /// with its `client_uuid` and sent when the connection is back.
  Future<VanSaleOutcome> recordSale({
    required String buyerName,
    String? buyerPhone,
    String? buyerVatNo,
    required VanPaymentMethod paymentMethod,
    required double discountPercent,
    required List<VanSaleRequestLine> lines,
  }) async {
    final trip = state.trip;
    if (trip == null || state.busy != null) return VanSaleOutcome.failed(CustomError("err_unexpected".tr()));
    emit(state.copyWith(busy: VanTripAction.sale));

    final position = await const LocationService().currentPosition().timeout(
      const Duration(seconds: 4),
      onTimeout: () => null,
    );

    final request = VanSaleRequest(
      tripId: trip.id,
      buyerName: buyerName,
      buyerPhone: buyerPhone,
      buyerVatNo: buyerVatNo,
      paymentMethod: paymentMethod,
      discountPercent: discountPercent,
      lines: lines,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );

    final result = await vanRepo.recordSale(request: request);
    if (isClosed) return VanSaleOutcome.failed(CustomError("err_unexpected".tr()));

    return await result.fold(
      (failure) async {
        if (failure.isRetryable) {
          await saleQueue.enqueue(request);
          emit(state.copyWith(clearBusy: true, message: _info("van_sale_queued".tr())));
          _syncPending();
          return VanSaleOutcome.queued(request);
        }
        emit(state.copyWith(clearBusy: true));
        return VanSaleOutcome.failed(failure);
      },
      (recorded) async {
        emit(state.copyWith(clearBusy: true, sales: _mergeSales([recorded.sale])));
        _applyTrip(recorded.trip);
        loadTrip(silent: true);
        return VanSaleOutcome.recorded(recorded.sale);
      },
    );
  }

  List<VanSaleModel> _mergeSales(List<VanSaleModel> fresh) {
    final ids = {for (final sale in fresh) sale.id};
    return [
      ...fresh,
      for (final sale in state.sales)
        if (!ids.contains(sale.id)) sale,
    ];
  }

  Future<void> loadSales({bool silent = false}) async {
    final trip = state.trip;
    if (trip == null || state.salesLoading) return;
    emit(state.copyWith(salesLoading: !silent || !state.salesLoaded, clearSalesFailure: true));

    final result = await vanRepo.getSales(tripId: trip.id);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(salesLoading: false, salesFailure: failure)),
      (sales) => emit(state.copyWith(salesLoading: false, salesLoaded: true, sales: sales)),
    );
  }

  // --------------------------------------------------------------- deliver

  Future<void> loadTraders({bool silent = false}) async {
    final trip = state.trip;
    if (trip == null || state.tradersLoading) return;
    emit(state.copyWith(tradersLoading: !silent || !state.tradersLoaded, clearTradersFailure: true));

    final result = await vanRepo.getTraders(tripId: trip.id);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(tradersLoading: false, tradersFailure: failure)),
      (traders) => emit(state.copyWith(tradersLoading: false, tradersLoaded: true, traders: traders)),
    );
  }

  /// Creates the delivery stop; the caller hands it to the existing
  /// arrive → handoff → deliver flow.
  Future<Either<Failure, VanDeliveryResult>> createDelivery(VanDeliveryRequest request) async {
    final trip = state.trip;
    if (trip == null || state.busy != null) return left(CustomError("err_unexpected".tr()));
    emit(state.copyWith(busy: VanTripAction.delivery));

    final result = await vanRepo.createDelivery(tripId: trip.id, request: request);
    if (isClosed) return result;

    emit(state.copyWith(clearBusy: true));
    result.fold((_) {}, (created) {
      _applyTrip(created.trip);
      // Outstanding quantities of the trader's orders moved.
      loadTraders(silent: true);
    });
    return result;
  }

  // -------------------------------------------------------------- end trip

  /// Starts the return; the server answers with the return code the driver
  /// shows the warehouse keeper.
  Future<Either<Failure, VanTripModel?>> startReturn(Map<int, double> returnedQty) async {
    final trip = state.trip;
    if (trip == null || state.busy != null) return left(CustomError("err_unexpected".tr()));
    emit(state.copyWith(busy: VanTripAction.endTrip));

    final result = await vanRepo.startReturn(tripId: trip.id, returnedQty: returnedQty);
    if (isClosed) return result;

    emit(state.copyWith(clearBusy: true));
    result.fold((_) {}, (updated) {
      _applyTrip(updated);
      loadTrip(silent: true);
    });
    return result;
  }

  VanTripMessage _error(String text) => VanTripMessage(token: ++_token, text: text, isError: true);

  VanTripMessage _info(String text) => VanTripMessage(token: ++_token, text: text);
}
