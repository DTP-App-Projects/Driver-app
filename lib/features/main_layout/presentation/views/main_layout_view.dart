import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_loading_item.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/exit_alert.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/location_tracker.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/home/presentation/views/home_view.dart';
import 'package:digital_trade_portal_driver/features/main_layout/presentation/view_model/change_nav_bar_status/change_nav_bar_status_cubit.dart';
import 'package:digital_trade_portal_driver/features/main_layout/presentation/views/widgets/bottom_nav_bar.dart';
import 'package:digital_trade_portal_driver/features/notification/presentation/view_models/notifications/notifications_cubit.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/driver_profile/driver_profile_cubit.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/profile_view.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/terms_view.dart';
import 'package:digital_trade_portal_driver/features/main_layout/presentation/views/widgets/nav_tabs.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/today_route/today_route_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/routes_view.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/view_models/van_trip/van_trip_cubit.dart';

class MainLayoutView extends StatefulWidget {
  const MainLayoutView({super.key, this.initialIndex});

  final int? initialIndex;

  @override
  State<MainLayoutView> createState() => _MainLayoutViewState();
}

class _MainLayoutViewState extends State<MainLayoutView> with WidgetsBindingObserver {
  /// Tabs opened at least once, so screens are built lazily and keep their
  /// state afterwards.
  final Set<int> _visited = {};

  /// The terms gate is pushed once per session, not on every rebuild.
  bool _termsShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final navCubit = ChangeNavBarStatusCubit.get(context);
    if (widget.initialIndex != null) {
      navCubit.currentIndex = widget.initialIndex!;
    }
    _visited.add(navCubit.currentIndex);

    // App boot: the profile decides whether the route UI can show at all.
    final profileCubit = context.read<DriverProfileCubit>();
    if (!profileCubit.state.hasDriver) {
      profileCubit.loadProfile();
    } else if (profileCubit.state.needsTerms) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openTermsGate());
    }
    context.read<TodayRouteCubit>().loadTodayRoute(silent: context.read<TodayRouteCubit>().state.hasData);
    context.read<VanTripCubit>().loadTrip(silent: context.read<VanTripCubit>().state.hasTrip);
    context.read<NotificationsCubit>().loadNotifications(silent: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app: replay anything queued offline and refresh the
  /// route and inbox so the screen matches the server again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    getIt.get<LocationTracker>().onAppResumed();
    context.read<TodayRouteCubit>().loadTodayRoute(silent: true);
    // Also replays walk-in sales made offline.
    context.read<VanTripCubit>().loadTrip(silent: true);
    context.read<NotificationsCubit>().loadNotifications(silent: true);
  }

  Widget buildScreen(int index) {
    // لو الـ screen مش اتزارت، نرجع SizedBox.shrink() عشان ما تتبنيش
    if (!_visited.contains(index)) return const SizedBox.shrink();

    switch (index) {
      case 0:
        return const HomeView();
      case 1:
        return const RoutesView(withBack: false);
      case 2:
        return const ProfileView();
      default:
        return const SizedBox.shrink();
    }
  }

  void _openTermsGate() {
    if (_termsShown) return;
    _termsShown = true;
    NavigationUtils.navigateTo(context: context, destinationScreen: const TermsView(mustAccept: true));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        // Transparent so the white bottom bar itself reaches the screen edge.
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) exitDialog(context);
        },
        child: BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
          builder: (context, _) {
            return BlocConsumer<DriverProfileCubit, DriverProfileState>(
              listenWhen: (previous, current) => current.needsTerms && !previous.needsTerms,
              listener: (context, state) => _openTermsGate(),
              builder: (context, profileState) {
                // Not provisioned as a driver: the account exists but there is
                // no route to show, so the tabs stay hidden.
                if (profileState.isNotADriver) return _buildNotADriver(context);

                // The boot call failed and nothing is cached (offline, or the
                // backend answered 5xx for a stale token): explain and offer
                // retry / logout instead of empty tabs.
                if (!profileState.hasDriver && profileState.failure != null) {
                  return _buildNotADriver(context, failure: profileState.failure);
                }

                return Scaffold(
                  backgroundColor: Colors.white,
                  resizeToAvoidBottomInset: false,
                  body: BlocBuilder<ChangeNavBarStatusCubit, ChangeNavBarStatusState>(
                    builder: (context, state) {
                      final currentIndex = ChangeNavBarStatusCubit.get(context).currentIndex;
                      _visited.add(currentIndex);

                      return IndexedStack(index: currentIndex, children: List.generate(navTabs.length, buildScreen));
                    },
                  ),
                  bottomNavigationBar: const BottomNavBar(),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotADriver(BuildContext context, {Failure? failure}) {
    final iconSize = MediaQuery.of(context).size.height * .12;
    final bool isError = failure != null;

    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppConstants.width30(context)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.red.withValues(alpha: .08)),
                child: Icon(
                  isError ? Icons.wifi_off_rounded : Icons.badge_outlined,
                  size: iconSize * .45,
                  color: AppColors.red,
                ),
              ),
              SizedBox(height: AppConstants.height20(context)),
              Text(
                (isError ? "profile_load_failed" : "not_a_driver_title").tr(),
                textAlign: TextAlign.center,
                style: Styles.font18SemiBoldBlack(context),
              ),
              SizedBox(height: AppConstants.height10(context)),
              Text(
                isError ? failure.errMessage : "api_not_a_driver".tr(),
                textAlign: TextAlign.center,
                style: Styles.font12MediumGrey46(context).copyWith(height: 1.6),
              ),
              SizedBox(height: AppConstants.height30(context)),
              BlocBuilder<DriverProfileCubit, DriverProfileState>(
                builder: (context, state) {
                  if (state.isLoading) return const CustomLoadingItem();
                  return Column(
                    children: [
                      DefaultButton(
                        onPress: context.read<DriverProfileCubit>().loadProfile,
                        text: "retry".tr(),
                        borderRadius: AppConstants.sp15(context),
                        gradient: AppColors.brandGradient,
                      ),
                      SizedBox(height: AppConstants.height10(context)),
                      DefaultButton(
                        onPress: () async {
                          final router = GoRouter.of(context);
                          await context.read<DriverProfileCubit>().logout();
                          router.go("/loginView");
                        },
                        text: "logout".tr(),
                        backgroundColor: Colors.white,
                        hasBorder: true,
                        borderColor: AppColors.red,
                        textColor: AppColors.red,
                        borderRadius: AppConstants.sp15(context),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
