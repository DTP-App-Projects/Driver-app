import 'package:bloc/bloc.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/content_models.dart';
import 'package:digital_trade_portal_driver/features/profile/data/repos/profile_repo.dart';

part 'account_deletion_state.dart';

/// Store compliance flow: file a deletion request, see its status, cancel
/// it while it is still active.
class AccountDeletionCubit extends Cubit<AccountDeletionState> {
  AccountDeletionCubit(this.repo) : super(const AccountDeletionState());
  final ProfileRepo repo;

  Future<void> loadRequest() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    final result = await repo.getAccountDeletionRequest();
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, errMessage: failure.errMessage)),
      (request) =>
          emit(state.copyWith(request: request, isLoading: false, hasLoaded: true, clearRequest: request == null)),
    );
  }

  Future<void> submit({String? reason}) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));
    final result = await repo.requestAccountDeletion(reason: reason);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isSubmitting: false, errMessage: failure.errMessage)),
      (request) => emit(state.copyWith(request: request, isSubmitting: false, hasLoaded: true, submitted: true)),
    );
  }

  Future<void> cancel() async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));
    final result = await repo.cancelAccountDeletion();
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isSubmitting: false, errMessage: failure.errMessage)),
      (_) => emit(state.copyWith(isSubmitting: false, clearRequest: true, cancelled: true)),
    );
  }
}
