import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/push_event_bus.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/session_manager.dart';
import 'package:digital_trade_portal_driver/features/notification/data/models/notification_model.dart';
import 'package:digital_trade_portal_driver/features/notification/data/repos/notifications_repo.dart';

part 'notifications_state.dart';

/// The in-app inbox. Shared between the home header (unread dot) and the
/// notifications screen.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this.repo, {PushEventBus? pushEvents}) : super(const NotificationsState()) {
    SessionManager.addSessionClearedListener(reset);
    // Every push also lands in the inbox; pull it so the unread dot is right.
    _pushSubscription = pushEvents?.events.listen((_) {
      if (!isClosed && state.hasLoaded) loadNotifications(silent: true);
    });
  }

  final NotificationsRepo repo;
  StreamSubscription? _pushSubscription;

  @override
  Future<void> close() {
    SessionManager.removeSessionClearedListener(reset);
    _pushSubscription?.cancel();
    return super.close();
  }

  void reset() {
    if (!isClosed) emit(const NotificationsState());
  }

  Future<void> loadNotifications({bool silent = false}) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: !silent, clearFailure: true));

    final result = await repo.getNotifications();
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, failure: failure)),
      (items) => emit(state.copyWith(notifications: items, isLoading: false, clearFailure: true, hasLoaded: true)),
    );
  }

  /// Marks locally first so the row updates at once, then tells the server.
  Future<void> markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;
    notification.isRead = true;
    emit(state.copyWith(notifications: List.of(state.notifications)));

    final result = await repo.markRead(notificationId: notification.id);
    if (isClosed) return;
    result.fold((failure) {
      notification.isRead = false;
      emit(state.copyWith(notifications: List.of(state.notifications), actionError: failure.errMessage));
    }, (_) {});
  }

  Future<void> markAllAsRead() async {
    if (state.unreadCount == 0 || state.isMarkingAll) return;
    emit(state.copyWith(isMarkingAll: true));

    final result = await repo.markAllRead();
    if (isClosed) return;

    result.fold((failure) => emit(state.copyWith(isMarkingAll: false, actionError: failure.errMessage)), (_) {
      for (final notification in state.notifications) {
        notification.isRead = true;
      }
      emit(state.copyWith(notifications: List.of(state.notifications), isMarkingAll: false));
    });
  }
}
