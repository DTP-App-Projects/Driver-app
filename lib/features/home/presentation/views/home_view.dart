import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/features/emergency/presentation/views/emergency_view.dart';
import 'package:digital_trade_portal_driver/features/home/presentation/views/widgets/home_header.dart';
import 'package:digital_trade_portal_driver/features/home/presentation/views/widgets/today_route_card.dart';
import 'package:digital_trade_portal_driver/features/notification/presentation/views/notification_view.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/routes_details_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // TODO: replace with the today routes endpoint once it exists.
  late List<RouteModel> todayRoutes = RouteModel.todayDemoData();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F7FA),
          body: SafeArea(
            bottom: false,
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
                HomeHeader(
                  driverName: "خالد ماهر",
                  hasUnreadNotifications: true,
                  onNotificationsTap: () => NavigationUtils.navigateTo(
                    context: context,
                    destinationScreen: const NotificationView(),
                  ),
                  onEmergencyTap: () => NavigationUtils.navigateTo(
                    context: context,
                    destinationScreen: const EmergencyView(),
                  ),
                ),
                SizedBox(height: AppConstants.height24(context)),
                TodayRouteCard(
                  routes: todayRoutes,
                  onRouteTap: (route) => NavigationUtils.navigateTo(
                    context: context,
                    destinationScreen: RoutesDetailsView(route: route),
                  ),
                  onRefresh: () => setState(() => todayRoutes = RouteModel.todayDemoData()),
                ),
                SizedBox(height: AppConstants.height30(context)),
                // QuickActionsSection(onActionTap: onQuickAction),
              ],
            ),
          ),
        );
      },
    );
  }
}
