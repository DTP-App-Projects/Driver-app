import 'package:bloc/bloc.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/content_models.dart';
import 'package:digital_trade_portal_driver/features/profile/data/repos/profile_repo.dart';

part 'content_state.dart';

/// Loads one of the public content pages (about / terms / support).
class ContentCubit extends Cubit<ContentState> {
  ContentCubit(this.repo) : super(ContentInitial());
  final ProfileRepo repo;

  Future<void> loadAbout() => _loadPage(repo.getAbout);

  Future<void> loadTerms() => _loadPage(repo.getTerms);

  Future<void> _loadPage(Future Function() call) async {
    emit(ContentLoadingState());
    final result = await call();
    if (isClosed) return;
    result.fold(
      (failure) => emit(ContentErrorState(errMessage: failure.errMessage)),
      (page) => emit(ContentPageSuccessState(page: page)),
    );
  }

  Future<void> loadSupport() async {
    emit(ContentLoadingState());
    final result = await repo.getSupport();
    if (isClosed) return;
    result.fold(
      (failure) => emit(ContentErrorState(errMessage: failure.errMessage)),
      (channels) => emit(ContentSupportSuccessState(channels: channels)),
    );
  }
}
