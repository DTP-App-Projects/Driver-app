import 'package:bloc/bloc.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/features/training/data/models/training_models.dart';
import 'package:digital_trade_portal_driver/features/training/data/repos/training_repo.dart';

part 'training_state.dart';

/// Curriculum, module content, quiz submission and certificate state.
class TrainingCubit extends Cubit<TrainingState> {
  TrainingCubit(this.repo) : super(const TrainingState());
  final TrainingRepo repo;

  Future<void> loadCurriculum() async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final result = await repo.getCurriculum();
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, failure: failure)),
      (curriculum) => emit(state.copyWith(curriculum: curriculum, isLoading: false, hasLoaded: true)),
    );
  }

  /// Loads the module content and marks it started on the server.
  Future<void> openModule(int moduleId) async {
    emit(state.copyWith(isLoadingModule: true, clearModule: true, clearQuizResult: true, clearFailure: true));

    final result = await repo.getModule(moduleId: moduleId);
    if (isClosed) return;

    await result.fold((failure) async => emit(state.copyWith(isLoadingModule: false, failure: failure)), (
      module,
    ) async {
      emit(state.copyWith(module: module, isLoadingModule: false));
      if (!module.isPassed) await repo.startModule(moduleId: moduleId);
    });
  }

  Future<void> submitQuiz(Map<int, String> answers) async {
    final module = state.module;
    if (module == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final result = await repo.submitQuiz(moduleId: module.id, answers: answers);
    if (isClosed) return;

    await result.fold((failure) async => emit(state.copyWith(isSubmitting: false, submitError: failure.errMessage)), (
      quizResult,
    ) async {
      emit(state.copyWith(isSubmitting: false, quizResult: quizResult));
      // Progress and certificate state changed on the server.
      final refreshed = await repo.getCurriculum();
      if (isClosed) return;
      refreshed.fold((_) {}, (curriculum) => emit(state.copyWith(curriculum: curriculum)));
    });
  }
}
