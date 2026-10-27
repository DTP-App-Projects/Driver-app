import 'package:bloc/bloc.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo.dart';

part 'route_history_state.dart';

/// Completed routes, newest first, 15 per page (`GET /driver/history`).
class RouteHistoryCubit extends Cubit<RouteHistoryState> {
  RouteHistoryCubit(this.repo) : super(const RouteHistoryState());
  final RoutesRepo repo;

  Future<void> loadFirstPage() async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final result = await repo.getHistory(page: 1);
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, failure: failure)),
      (page) => emit(
        RouteHistoryState(routes: page.routes, currentPage: page.currentPage, hasMore: page.hasMore, hasLoaded: true),
      ),
    );
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    emit(state.copyWith(isLoadingMore: true));

    final result = await repo.getHistory(page: state.currentPage + 1);
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(isLoadingMore: false, failure: failure)),
      (page) => emit(
        state.copyWith(
          routes: [...state.routes, ...page.routes],
          currentPage: page.currentPage,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      ),
    );
  }
}
