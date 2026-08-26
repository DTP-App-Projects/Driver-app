import 'package:go_router/go_router.dart';
import 'package:digital_trade_portal_driver/features/auth/presentation/views/login_view.dart';
import 'package:digital_trade_portal_driver/features/main_layout/presentation/views/main_layout_view.dart';
import '../../../features/splash/presentation/views/splash_view.dart';

abstract class AppRouter {
  static final router = GoRouter(
    routes: [
      //Splash Roots
      GoRoute(path: "/", builder: (context, state) => const SplashView()),
      GoRoute(path: "/loginView", builder: (context, state) => const LoginView()),
      GoRoute(path: "/mainLayoutView", builder: (context, state) => MainLayoutView()),
    ],
  );
}
