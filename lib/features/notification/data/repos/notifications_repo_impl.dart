import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_call.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_service.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/endpoints.dart';
import 'package:digital_trade_portal_driver/features/notification/data/models/notification_model.dart';
import 'package:digital_trade_portal_driver/features/notification/data/repos/notifications_repo.dart';

class NotificationsRepoImpl implements NotificationsRepo {
  final ApiService apiService;

  NotificationsRepoImpl(this.apiService);

  @override
  Future<Either<Failure, List<NotificationModel>>> getNotifications() {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.notifications),
      // `{data:[]}` when the inbox is not migrated yet is a valid empty feed.
      (response) => NotificationModel.listFromJson(response.data),
    );
  }

  @override
  Future<Either<Failure, Unit>> markRead({required int notificationId}) {
    return apiCall(
      () => apiService.patchData(endPoint: EndPoints.notificationRead(notificationId), data: const {}),
      (_) => unit,
    );
  }

  @override
  Future<Either<Failure, Unit>> markAllRead() {
    return apiCall(() => apiService.patchData(endPoint: EndPoints.notificationsReadAll, data: const {}), (_) => unit);
  }

  @override
  Future<Either<Failure, Unit>> registerPushToken({
    required String token,
    required String platform,
    required String locale,
    String? deviceId,
    String? deviceModel,
    String? osVersion,
  }) {
    return apiCall(
      () => apiService.postData(
        endPoint: EndPoints.pushRegister,
        data: {
          "token": token,
          "platform": platform,
          "app_variant": "driver",
          "locale": locale,
          "device_id": ?deviceId,
          "device_model": ?deviceModel,
          "os_version": ?osVersion,
        },
      ),
      (_) => unit,
    );
  }

  @override
  Future<Either<Failure, Unit>> unregisterPushToken({required String token}) {
    return apiCall(() => apiService.postData(endPoint: EndPoints.pushUnregister, data: {"token": token}), (_) => unit);
  }
}
