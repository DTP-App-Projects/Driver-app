part of 'notifications_cubit.dart';

class NotificationsState {
  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.hasLoaded = false,
    this.isMarkingAll = false,
    this.failure,
    this.actionError,
  });

  final List<NotificationModel> notifications;
  final bool isLoading;

  /// True once the inbox was fetched at least once, so an empty list is a
  /// real empty state and not "not loaded yet".
  final bool hasLoaded;
  final bool isMarkingAll;
  final Failure? failure;

  /// Error of the last mark-as-read action, shown as a toast.
  final String? actionError;

  int get unreadCount => notifications.where((notification) => !notification.isRead).length;

  bool get hasUnread => unreadCount > 0;

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    bool? hasLoaded,
    bool? isMarkingAll,
    Failure? failure,
    bool clearFailure = false,
    String? actionError,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isMarkingAll: isMarkingAll ?? this.isMarkingAll,
      failure: clearFailure ? null : failure ?? this.failure,
      // Action errors are transient: only the state that set one carries it.
      actionError: actionError,
    );
  }
}
