part of 'route_history_cubit.dart';

class RouteHistoryState {
  const RouteHistoryState({
    this.routes = const [],
    this.currentPage = 1,
    this.hasMore = false,
    this.hasLoaded = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.failure,
  });

  final List<RouteModel> routes;
  final int currentPage;
  final bool hasMore;
  final bool hasLoaded;
  final bool isLoading;
  final bool isLoadingMore;
  final Failure? failure;

  RouteHistoryState copyWith({
    List<RouteModel>? routes,
    int? currentPage,
    bool? hasMore,
    bool? hasLoaded,
    bool? isLoading,
    bool? isLoadingMore,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return RouteHistoryState(
      routes: routes ?? this.routes,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}
