import 'dart:async';
import 'dart:io';
import 'package:digital_trade_portal_driver/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:digital_trade_portal_driver/features/main_layout/presentation/view_model/change_nav_bar_status/change_nav_bar_status_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/cache_keys.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/location_tracker.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/offline_queue.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/push_event_bus.dart';
import 'package:digital_trade_portal_driver/features/notification/data/repos/notifications_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/notification/presentation/view_models/notifications/notifications_cubit.dart';
import 'package:digital_trade_portal_driver/features/profile/data/repos/profile_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/driver_profile/driver_profile_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/today_route/today_route_cubit.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/van_sale_queue.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/repos/van_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/view_models/van_trip/van_trip_cubit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/utils/roots/app_router.dart';
import 'core/utils/services/local_services/cache_helper.dart';
import 'core/utils/services/remote_services/service_locator.dart';
import 'core/utils/theme/app_theme.dart';

// Local Notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Background handler for FCM
@pragma('vm:entry-point')
Future _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // On iOS, background messages with a notification payload are handled
  // automatically by the system — no need to show a local notification.
  // Only show local notifications for data-only messages.
  if (message.notification == null) {
    final title = message.data['title'];
    final body = message.data['body'];
    if (title != null && body != null) {
      flutterLocalNotificationsPlugin.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'dtp_driver_channel_id',
            'DigitalTradePortalDriver',
            channelDescription: 'dtp_driver_channel_description',
            importance: Importance.max,
            priority: Priority.high,
            icon: 'notification_icon',
            colorized: true,
            color: Color(0xff03745f),
          ),
          // ✅ إضافة إعدادات iOS للإشعارات المحلية
          iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        ),
      );
    }
  }
}

// Show a local notification for messages with a notification section
void _showLocalNotification(RemoteMessage message) {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'dtp_driver_channel_id',
    'DigitalTradePortalDriver',
    channelDescription: 'dtp_driver_channel_description',
    importance: Importance.max,
    priority: Priority.high,
    icon: 'notification_icon',
    colorized: true,
    color: Color(0xff03745f),
  );

  // ✅ إضافة إعدادات iOS للإشعارات المحلية
  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const NotificationDetails platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

  flutterLocalNotificationsPlugin.show(
    id: message.notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: message.notification?.title,
    body: message.notification?.body,
    notificationDetails: platformDetails,
  );
}

/// Route pushes (`click_action = route`: shipment / route canceled, stop
/// removed) go to the cubits through the bus so the route is fetched again
/// at once and the driver sees the alert on the route screen.
void _publishRoutePush(RemoteMessage message) {
  getIt.get<PushEventBus>().publishData(
    message.data,
    title: message.notification?.title,
    body: message.notification?.body,
  );
}

Future<void> _safeSubscribeToTopic(String topic) async {
  try {
    // ✅ على iOS لازم نستنى الـ APNs token الأول قبل ما نجيب FCM token
    if (Platform.isIOS) {
      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken == null) {
        debugPrint('Waiting for APNs token...');
        // ننتظر شوية ونحاول تاني
        await Future.delayed(const Duration(seconds: 3));
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('APNs token still null — cannot get FCM token on iOS');
          return;
        }
      }
      debugPrint('APNs Token: $apnsToken');
    }

    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await CacheKeysManger.saveDeviceToken(token);
      debugPrint("Device Token: $token");
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('Successfully subscribed to topic: $topic');
    } else {
      debugPrint('Failed to get device token, cannot subscribe to topic');
    }
  } catch (e) {
    debugPrint('Error subscribing to topic $topic: $e');
  }
}

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw behind the status and navigation bars so screen backgrounds
  // (the brand gradient) reach the very edges of the screen.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await EasyLocalization.ensureInitialized();

  // Load the date symbols for every locale so DateFormat can render Arabic dates.
  await initializeDateFormatting();

  await CacheHelper.init();

  // Services first: the messaging callbacks below hand route pushes to
  // the event bus registered here.
  setup();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ تسجيل background handler قبل أي حاجة تانية
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notifications
  const AndroidInitializationSettings androidInitSettings = AndroidInitializationSettings('notification_icon');
  const DarwinInitializationSettings iosInitSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initSettings = InitializationSettings(
    android: androidInitSettings,
    iOS: iosInitSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint('Tapped notification payload: ${response.payload}');
    },
  );

  // ✅ طلب صلاحيات iOS للإشعارات المحلية مع await
  if (Platform.isIOS) {
    final bool? granted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    debugPrint('iOS local notification permissions granted: $granted');
  }

  // ✅ طلب صلاحيات Firebase Messaging مع await
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  debugPrint('Firebase Messaging permission status: ${settings.authorizationStatus}');

  // ✅ ضبط عرض الإشعارات في الـ foreground مع await
  await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

  // Handlers
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('onMessage received: ${message.messageId}');
    _publishRoutePush(message);
    // ✅ على iOS لما التطبيق في الـ foreground:
    // setForegroundNotificationPresentationOptions بيتكفل بالعرض
    // للـ messages اللي فيها notification payload.
    // بس لو عايز تتحكم أكتر، ممكن تعرض local notification:
    if (message.notification != null) {
      // على Android بنعرض local notification عشان مفيش
      // setForegroundNotificationPresentationOptions
      if (Platform.isAndroid) {
        _showLocalNotification(message);
      }
      // على iOS الـ system بيعرض الإشعار تلقائياً بسبب
      // setForegroundNotificationPresentationOptions
      // لو عايز تعرضه manual برضو على iOS، شيل الـ if condition
    }

    // ✅ لو data-only message، اعرضها على كل الأنظمة
    if (message.notification == null) {
      final title = message.data['title'];
      final body = message.data['body'];
      if (title != null && body != null) {
        flutterLocalNotificationsPlugin.show(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'dtp_driver_channel_id',
              'DigitalTradePortalDriver',
              channelDescription: 'dtp_driver_channel_description',
              importance: Importance.max,
              priority: Priority.high,
              icon: 'notification_icon',
              colorized: true,
              color: Color(0xff03745f),
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
          ),
        );
      }
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('onMessageOpenedApp data: ${message.data}');
    _publishRoutePush(message);
  });

  // ✅ التعامل مع الإشعار اللي فتح التطبيق وهو مغلق
  RemoteMessage? initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('App opened from terminated state with data: ${initialMessage.data}');
    _publishRoutePush(initialMessage);
  }

  _safeSubscribeToTopic('all');

  if (CacheKeysManger.getUserLanguage().isEmpty) {
    await CacheHelper.saveData(key: 'lang', value: 'ar');
  }

  // A refreshed FCM token must reach the backend (`POST /push/register`) or
  // the driver silently stops receiving assignments.
  FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
    await CacheKeysManger.saveDeviceToken(token);
    _driverProfileCubit.registerPushToken();
  });

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale("ar"), Locale("en")],
      saveLocale: true,
      startLocale: Locale("ar"),
      path: "lib/core/language",
      child: const DigitalTradePortalDriver(),
    ),
  );
}

/// Session wide cubits, created once so the token refresh listener above and
/// every screen share the same instances.
final DriverProfileCubit _driverProfileCubit = DriverProfileCubit(
  profileRepo: getIt.get<ProfileRepoImpl>(),
  notificationsRepo: getIt.get<NotificationsRepoImpl>(),
);

class DigitalTradePortalDriver extends StatelessWidget {
  const DigitalTradePortalDriver({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => ChangeLanguageCubit()),
        BlocProvider(create: (context) => ChangeNavBarStatusCubit()),
        BlocProvider.value(value: _driverProfileCubit),
        BlocProvider(
          create: (context) => TodayRouteCubit(
            routesRepo: getIt.get<RoutesRepoImpl>(),
            locationTracker: getIt.get<LocationTracker>(),
            offlineQueue: getIt.get<OfflineQueue>(),
            pushEvents: getIt.get<PushEventBus>(),
          ),
        ),
        BlocProvider(
          create: (context) => VanTripCubit(
            vanRepo: getIt.get<VanRepoImpl>(),
            routesRepo: getIt.get<RoutesRepoImpl>(),
            saleQueue: getIt.get<VanSaleQueue>(),
          ),
        ),
        BlocProvider(
          create: (context) =>
              NotificationsCubit(getIt.get<NotificationsRepoImpl>(), pushEvents: getIt.get<PushEventBus>()),
        ),
      ],
      child: BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
        builder: (context, langState) {
          return MaterialApp.router(
            title: "التكامل التجاري الرقمي مناديب",
            theme: themeDataLight,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
                child: child!,
              );
            },
            debugShowCheckedModeBanner: false,
            routerConfig: AppRouter.router,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
          );
        },
      ),
    );
  }
}
