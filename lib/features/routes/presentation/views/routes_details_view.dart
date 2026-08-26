// intl (re-exported by easy_localization) ships its own TextDirection enum.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/stat_card.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/delivery_tracking_view.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/route_stop_item.dart';

class RoutesDetailsView extends StatelessWidget {
  const RoutesDetailsView({super.key, required this.route});

  final RouteModel route;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F7FA),
          body: SafeArea(
            child: Column(
              children: [
                CustomAppBar(title: "route_details".tr()),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppConstants.width20(context),
                      AppConstants.height10(context),
                      AppConstants.width20(context),
                      AppConstants.height30(context),
                    ),
                    children: [
                      _buildHeaderCard(context),
                      SizedBox(height: AppConstants.height20(context)),
                      _buildStats(context),
                      SizedBox(height: AppConstants.height24(context)),
                      Text("stops".tr(), style: Styles.font16SemiBoldBlack(context)),
                      SizedBox(height: AppConstants.height15(context)),
                      ..._buildStops(context),
                    ],
                  ),
                ),
                // A finished route has nothing left to start.
                if (!route.isCompleted) _buildStartDeliveryBar(context),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Pinned call to action so the driver can start the delivery without
  /// scrolling back through the stops.
  Widget _buildStartDeliveryBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppConstants.width20(context),
        AppConstants.height15(context),
        AppConstants.width20(context),
        AppConstants.height15(context),
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xffEDEFF2))),
      ),
      child: DefaultButton(
        text: "start_delivery".tr(),
        gradient: AppColors.brandGradient,
        borderRadius: AppConstants.sp15(context),
        icon: Icon(
          Icons.local_shipping_rounded,
          size: MediaQuery.of(context).size.height * .022,
          color: Colors.white,
        ),
        onPress: () => NavigationUtils.navigateTo(
          context: context,
          destinationScreen: DeliveryTrackingView(route: route),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppConstants.sp20(context)),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            route.code,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.start,
            style: Styles.font20BoldBlack(context).copyWith(color: Colors.white),
          ),
          SizedBox(height: AppConstants.height5(context)),
          Text(
            DateFormat("d MMMM y • h:mm a", context.locale.languageCode).format(route.date),
            style: Styles.font12MediumBlack(context).copyWith(color: Colors.white.withValues(alpha: .80)),
          ),
          SizedBox(height: AppConstants.height15(context)),
          _buildStatusChip(context),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.width15(context),
        vertical: AppConstants.height5(context),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp30(context)),
      ),
      child: Text(
        (route.isCompleted ? "route_completed" : "route_in_progress").tr(),
        style: Styles.font12MediumBlack(context).copyWith(
          color: route.isCompleted ? AppColors.secondaryColor : const Color(0xffE8A317),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final locale = context.locale.languageCode;
    final number = NumberFormat.decimalPattern(locale);

    return StatCardsRow(
      cards: [
        StatCard(
          label: "stops".tr(),
          value: number.format(route.stopsTotal),
          color: AppColors.neutralColor,
        ),
        StatCard(
          label: "completed_stops".tr(),
          value: number.format(route.stopsDone),
          color: AppColors.secondaryColor,
        ),
        StatCard(
          label: "distance_label".tr(),
          value: NumberFormat("#0.0", locale).format(route.distanceKm),
          color: AppColors.primarySwatchColor,
        ),
      ],
    );
  }

  List<Widget> _buildStops(BuildContext context) {
    return [
      for (int i = 0; i < route.stops.length; i++) ...[
        if (i != 0) SizedBox(height: AppConstants.height10(context)),
        RouteStopItem(stop: route.stops[i], order: i + 1),
      ],
    ];
  }
}
