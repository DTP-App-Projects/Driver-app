import 'package:bloc/bloc.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/earnings_model.dart';
import 'package:digital_trade_portal_driver/features/profile/data/repos/profile_repo.dart';

part 'earnings_state.dart';

/// Read only money and KPI screen: `GET /driver/earnings` and
/// `GET /driver/performance` loaded together.
class EarningsCubit extends Cubit<EarningsState> {
  EarningsCubit(this.repo) : super(const EarningsState());
  final ProfileRepo repo;

  Future<void> load() async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final results = await Future.wait([repo.getEarnings(), repo.getPerformance()]);
    if (isClosed) return;

    EarningsModel? earnings;
    PerformanceModel? performance;
    Failure? failure;

    results[0].fold((error) => failure = error, (data) => earnings = data as EarningsModel);
    results[1].fold((error) => failure ??= error, (data) => performance = data as PerformanceModel);

    emit(
      state.copyWith(
        earnings: earnings,
        performance: performance,
        isLoading: false,
        hasLoaded: earnings != null || performance != null,
        failure: earnings == null && performance == null ? failure : null,
      ),
    );
  }
}
