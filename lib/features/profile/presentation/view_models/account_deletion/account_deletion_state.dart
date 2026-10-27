part of 'account_deletion_cubit.dart';

class AccountDeletionState {
  const AccountDeletionState({
    this.request,
    this.isLoading = false,
    this.hasLoaded = false,
    this.isSubmitting = false,
    this.errMessage,
    this.submitted = false,
    this.cancelled = false,
  });

  /// Most recent request, regardless of status; null when none was filed.
  final DeletionRequestModel? request;
  final bool isLoading;
  final bool hasLoaded;
  final bool isSubmitting;
  final String? errMessage;

  /// One-shot flags for the sheet to toast on.
  final bool submitted;
  final bool cancelled;

  bool get hasActiveRequest => request != null && request!.isActive;

  AccountDeletionState copyWith({
    DeletionRequestModel? request,
    bool clearRequest = false,
    bool? isLoading,
    bool? hasLoaded,
    bool? isSubmitting,
    String? errMessage,
    bool clearError = false,
    bool submitted = false,
    bool cancelled = false,
  }) {
    return AccountDeletionState(
      request: clearRequest ? null : request ?? this.request,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errMessage: clearError ? null : errMessage ?? this.errMessage,
      submitted: submitted,
      cancelled: cancelled,
    );
  }
}
