part of 'earnings_cubit.dart';

class EarningsState {
  const EarningsState({this.earnings, this.performance, this.isLoading = false, this.hasLoaded = false, this.failure});

  final EarningsModel? earnings;
  final PerformanceModel? performance;
  final bool isLoading;
  final bool hasLoaded;
  final Failure? failure;

  EarningsState copyWith({
    EarningsModel? earnings,
    PerformanceModel? performance,
    bool? isLoading,
    bool? hasLoaded,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return EarningsState(
      earnings: earnings ?? this.earnings,
      performance: performance ?? this.performance,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}
