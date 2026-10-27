import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/location_tracker.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/offline_queue.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/push_event_bus.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/van_sale_queue.dart';
import 'package:digital_trade_portal_driver/features/auth/data/repos/auth_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/emergency/data/repos/incidents_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/my_cars/data/repos/vehicles_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/notification/data/repos/notifications_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/profile/data/repos/profile_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/training/data/repos/training_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/repos/van_repo_impl.dart';
import 'api_service.dart';
//dependency Injection

final getIt = GetIt.instance;

void setup() {
  getIt.registerSingleton<ApiService>(ApiService(Dio()));
  getIt.registerSingleton<PushEventBus>(PushEventBus());

  getIt.registerSingleton<AuthRepoImpl>(AuthRepoImpl(getIt.get<ApiService>()));
  getIt.registerSingleton<ProfileRepoImpl>(ProfileRepoImpl(getIt.get<ApiService>()));
  getIt.registerSingleton<VehiclesRepoImpl>(VehiclesRepoImpl(getIt.get<ApiService>()));
  getIt.registerSingleton<RoutesRepoImpl>(RoutesRepoImpl(getIt.get<ApiService>()));
  getIt.registerSingleton<NotificationsRepoImpl>(NotificationsRepoImpl(getIt.get<ApiService>()));
  getIt.registerSingleton<IncidentsRepoImpl>(IncidentsRepoImpl(getIt.get<ApiService>()));
  getIt.registerSingleton<TrainingRepoImpl>(TrainingRepoImpl(getIt.get<ApiService>()));
  getIt.registerSingleton<VanRepoImpl>(VanRepoImpl(getIt.get<ApiService>()));

  getIt.registerSingleton<OfflineQueue>(OfflineQueue(getIt.get<RoutesRepoImpl>()));
  getIt.registerSingleton<VanSaleQueue>(VanSaleQueue(getIt.get<VanRepoImpl>()));
  getIt.registerSingleton<LocationTracker>(
    LocationTracker(routesRepo: getIt.get<RoutesRepoImpl>(), offlineQueue: getIt.get<OfflineQueue>()),
  );
}
