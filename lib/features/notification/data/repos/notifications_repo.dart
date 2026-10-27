import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/features/notification/data/models/notification_model.dart';

/// 10 · Notifications & push.
abstract class NotificationsRepo {
  /// `GET /api/v2/driver/notifications` — latest 100, newest first.
  Future<Either<Failure, List<NotificationModel>>> getNotifications();

  /// `PATCH /api/v2/driver/notifications/{id}/read`.
  Future<Either<Failure, Unit>> markRead({required int notificationId});

  /// `PATCH /api/v2/driver/notifications/read_all`.
  Future<Either<Failure, Unit>> markAllRead();

  /// `POST /api/v2/push/register`.
  Future<Either<Failure, Unit>> registerPushToken({
    required String token,
    required String platform,
    required String locale,
    String? deviceId,
    String? deviceModel,
    String? osVersion,
  });

  /// `POST /api/v2/push/unregister`.
  Future<Either<Failure, Unit>> unregisterPushToken({required String token});
}
