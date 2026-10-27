part of 'training_cubit.dart';

class TrainingState {
  const TrainingState({
    this.curriculum,
    this.isLoading = false,
    this.hasLoaded = false,
    this.failure,
    this.module,
    this.isLoadingModule = false,
    this.isSubmitting = false,
    this.quizResult,
    this.submitError,
  });

  final CurriculumModel? curriculum;
  final bool isLoading;
  final bool hasLoaded;
  final Failure? failure;

  /// Module opened for reading / quiz.
  final TrainingModuleModel? module;
  final bool isLoadingModule;
  final bool isSubmitting;
  final QuizResultModel? quizResult;

  /// Transient error of the last quiz submission.
  final String? submitError;

  TrainingState copyWith({
    CurriculumModel? curriculum,
    bool? isLoading,
    bool? hasLoaded,
    Failure? failure,
    bool clearFailure = false,
    TrainingModuleModel? module,
    bool clearModule = false,
    bool? isLoadingModule,
    bool? isSubmitting,
    QuizResultModel? quizResult,
    bool clearQuizResult = false,
    String? submitError,
  }) {
    return TrainingState(
      curriculum: curriculum ?? this.curriculum,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      failure: clearFailure ? null : failure ?? this.failure,
      module: clearModule ? null : module ?? this.module,
      isLoadingModule: isLoadingModule ?? this.isLoadingModule,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      quizResult: clearQuizResult ? null : quizResult ?? this.quizResult,
      submitError: submitError,
    );
  }
}
