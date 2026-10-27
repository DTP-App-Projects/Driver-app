part of 'van_trip_cubit.dart';

/// Request of the trip screen in flight; every submit button checks it so
/// nothing is sent twice.
enum VanTripAction { load, sale, delivery, endTrip }

/// One off toast; [token] distinguishes a new message from a rebuild.
class VanTripMessage {
  const VanTripMessage({required this.token, required this.text, this.isError = false});

  final int token;
  final String text;
  final bool isError;
}

/// What happened to a walk-in sale: recorded by the server, or queued
/// offline to be sent with the same `client_uuid` later.
class VanSaleOutcome {
  const VanSaleOutcome.recorded(VanSaleModel this.sale) : queued = null, failure = null;

  const VanSaleOutcome.queued(VanSaleRequest this.queued) : sale = null, failure = null;

  const VanSaleOutcome.failed(Failure this.failure) : sale = null, queued = null;

  final VanSaleModel? sale;
  final VanSaleRequest? queued;
  final Failure? failure;
}

class VanTripState {
  const VanTripState({
    this.trip,
    this.hasLoaded = false,
    this.isLoading = false,
    this.failure,
    this.busy,
    this.sales = const [],
    this.salesLoaded = false,
    this.salesLoading = false,
    this.salesFailure,
    this.traders = const [],
    this.tradersLoaded = false,
    this.tradersLoading = false,
    this.tradersFailure,
    this.pendingSales = const [],
    this.message,
  });

  /// Open trip, null when the driver has none.
  final VanTripModel? trip;

  /// At least one answer came back, so a null [trip] really means "no trip".
  final bool hasLoaded;
  final bool isLoading;
  final Failure? failure;
  final VanTripAction? busy;

  final List<VanSaleModel> sales;
  final bool salesLoaded;
  final bool salesLoading;
  final Failure? salesFailure;

  final List<VanTrader> traders;
  final bool tradersLoaded;
  final bool tradersLoading;
  final Failure? tradersFailure;

  /// Sales of the current trip waiting in the offline queue.
  final List<VanSaleRequest> pendingSales;
  final VanTripMessage? message;

  bool get hasTrip => trip != null;

  bool isBusy(VanTripAction action) => busy == action;

  VanTripState copyWith({
    VanTripModel? trip,
    bool clearTrip = false,
    bool? hasLoaded,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
    VanTripAction? busy,
    bool clearBusy = false,
    List<VanSaleModel>? sales,
    bool? salesLoaded,
    bool? salesLoading,
    Failure? salesFailure,
    bool clearSalesFailure = false,
    List<VanTrader>? traders,
    bool? tradersLoaded,
    bool? tradersLoading,
    Failure? tradersFailure,
    bool clearTradersFailure = false,
    List<VanSaleRequest>? pendingSales,
    VanTripMessage? message,
  }) {
    return VanTripState(
      trip: clearTrip ? null : trip ?? this.trip,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
      busy: clearBusy ? null : busy ?? this.busy,
      sales: sales ?? this.sales,
      salesLoaded: salesLoaded ?? this.salesLoaded,
      salesLoading: salesLoading ?? this.salesLoading,
      salesFailure: clearSalesFailure ? null : salesFailure ?? this.salesFailure,
      traders: traders ?? this.traders,
      tradersLoaded: tradersLoaded ?? this.tradersLoaded,
      tradersLoading: tradersLoading ?? this.tradersLoading,
      tradersFailure: clearTradersFailure ? null : tradersFailure ?? this.tradersFailure,
      pendingSales: pendingSales ?? this.pendingSales,
      message: message ?? this.message,
    );
  }
}
