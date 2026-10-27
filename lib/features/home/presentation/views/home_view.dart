import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/features/emergency/presentation/views/emergency_view.dart';
import 'package:digital_trade_portal_driver/features/home/presentation/views/widgets/home_header.dart';
import 'package:digital_trade_portal_driver/features/home/presentation/views/widgets/today_route_card.dart';
import 'package:digital_trade_portal_driver/features/notification/presentation/view_models/notifications/notifications_cubit.dart';
import 'package:digital_trade_portal_driver/features/notification/presentation/views/notification_view.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/driver_profile/driver_profile_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/today_route/today_route_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/routes_details_view.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/view_models/van_trip/van_trip_cubit.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_trip_card.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  Future<void> _refresh(BuildContext context) async {
    await Future.wait([
      context.read<TodayRouteCubit>().loadTodayRoute(silent: true),
      context.read<VanTripCubit>().loadTrip(silent: true),
      context.read<NotificationsCubit>().loadNotifications(silent: true),
      context.read<DriverProfileCubit>().loadProfile(silent: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F7FA),
          body: SafeArea(
            bottom: false,
            child: BlocConsumer<TodayRouteCubit, TodayRouteState>(
              listenWhen: (previous, current) => current.message != null && current.message != previous.message,
              listener: (context, state) =>
                  toast(context: context, text: state.message!.text, isSuccess: !state.message!.isError),
              builder: (context, routeState) {
                return RefreshIndicator(
                  color: AppColors.primarySwatchColor,
                  onRefresh: () => _refresh(context),
                  child: ListView(
                    // Always scrollable so pull to refresh works on a short page.
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      AppConstants.width20(context),
                      AppConstants.height20(context),
                      AppConstants.width20(context),
                      AppConstants.height30(context),
                    ),
                    children: [
                      _buildHeader(context),
                      SizedBox(height: AppConstants.height24(context)),
                      const VanTripCard(),
                      TodayRouteCard(
                        routes: routeState.routes,
                        isLoading: routeState.isLoading && !routeState.hasData,
                        errorMessage: routeState.hasData ? null : routeState.failure?.errMessage,
                        onRouteTap: (route) => NavigationUtils.navigateTo(
                          context: context,
                          destinationScreen: RoutesDetailsView(route: route),
                        ),
                        onRefresh: () => context.read<TodayRouteCubit>().loadTodayRoute(),
                      ),
                      SizedBox(height: AppConstants.height30(context)),
                      // QuickActionsSection(onActionTap: onQuickAction),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return BlocBuilder<DriverProfileCubit, DriverProfileState>(
      builder: (context, profileState) {
        return BlocBuilder<NotificationsCubit, NotificationsState>(
          builder: (context, notificationsState) {
            final name = profileState.driver?.displayName;
            return HomeHeader(
              driverName: name == null || name.isEmpty ? null : name,
              hasUnreadNotifications: notificationsState.hasUnread,
              onNotificationsTap: () =>
                  NavigationUtils.navigateTo(context: context, destinationScreen: const NotificationView()),
              onEmergencyTap: () =>
                  NavigationUtils.navigateTo(context: context, destinationScreen: const EmergencyView()),
            );
          },
        );
      },
    );
  }
}
