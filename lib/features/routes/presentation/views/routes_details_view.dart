// intl (re-exported by easy_localization) ships its own TextDirection enum.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/stat_card.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/today_route/today_route_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/delivery_tracking_view.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/route_alert_banner.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/route_stop_item.dart';

class RoutesDetailsView extends StatelessWidget {
  const RoutesDetailsView({super.key, required this.route});

  /// Snapshot handed over by the list. While the route is part of today's
  /// payload the live copy from the cubit is shown instead, so a start or a
  /// completed stop is reflected here too.
  final RouteModel route;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return BlocConsumer<TodayRouteCubit, TodayRouteState>(
          listenWhen: (previous, current) => current.message != null && current.message != previous.message,
          listener: (context, state) =>
              toast(context: context, text: state.message!.text, isSuccess: !state.message!.isError),
          builder: (context, state) {
            final live = state.data?.routeById(route.id) ?? route;
            final alert = state.alertFor(route.id);

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
                          if (alert != null) ...[
                            RouteAlertBanner(alert: alert),
                            SizedBox(height: AppConstants.height15(context)),
                          ],
                          _buildHeaderCard(context, live),
                          SizedBox(height: AppConstants.height20(context)),
                          _buildStats(context, live),
                          SizedBox(height: AppConstants.height24(context)),
                          Text("stops".tr(), style: Styles.font16SemiBoldBlack(context)),
                          SizedBox(height: AppConstants.height15(context)),
                          ..._buildStops(context, live),
                        ],
                      ),
                    ),
                    // A finished (or cancelled / draft) route has nothing left to
                    // start; neither has one the supplier just canceled.
                    if ((live.isAssigned || live.isInProgress) &&
                        !(alert?.isRouteCanceled ?? false) &&
                        !(alert?.isRouteClosed ?? false))
                      _buildStartDeliveryBar(context, live, state),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Pinned call to action so the driver can start the delivery without
  /// scrolling back through the stops. An assigned route is started on the
  /// server first (`POST /routes/{id}/start`); one already in progress opens
  /// the tracking screen straight away.
  Widget _buildStartDeliveryBar(BuildContext context, RouteModel live, TodayRouteState state) {
    final bool isSubmitting = state.isSubmitting(live.id);

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
        text: (live.isInProgress ? "continue_delivery" : "start_delivery").tr(),
        gradient: AppColors.brandGradient,
        borderRadius: AppConstants.sp15(context),
        isEnabled: !isSubmitting,
        icon: Icon(Icons.local_shipping_rounded, size: MediaQuery.of(context).size.height * .022, color: Colors.white),
        onPress: () => _startDelivery(context, live),
      ),
    );
  }

  Future<void> _startDelivery(BuildContext context, RouteModel live) async {
    final cubit = context.read<TodayRouteCubit>();

    if (live.isAssigned) {
      final started = await cubit.startRoute(live);
      if (!started || !context.mounted) return;
    }

    final current = cubit.state.data?.routeById(live.id) ?? live;
    if (context.mounted) {
      NavigationUtils.navigateTo(
        context: context,
        destinationScreen: DeliveryTrackingView(route: current),
      );
    }
  }

  Widget _buildHeaderCard(BuildContext context, RouteModel live) {
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
            live.code,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.start,
            style: Styles.font20BoldBlack(context).copyWith(color: Colors.white),
          ),
          SizedBox(height: AppConstants.height5(context)),
          Text(
            DateFormat(live.hasTime ? "d MMMM y • h:mm a" : "d MMMM y", context.locale.languageCode).format(live.date),
            style: Styles.font12MediumBlack(context).copyWith(color: Colors.white.withValues(alpha: .80)),
          ),
          if (live.vehicle != null) ...[
            SizedBox(height: AppConstants.height5(context)),
            Text(
              "${"plate".tr()}: ${live.vehicle!.plate}",
              style: Styles.font12MediumBlack(context).copyWith(color: Colors.white.withValues(alpha: .80)),
            ),
          ],
          SizedBox(height: AppConstants.height15(context)),
          _buildStatusChip(context, live),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, RouteModel live) {
    final bool isLate = live.isLate;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppConstants.width15(context), vertical: AppConstants.height5(context)),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppConstants.sp30(context))),
      child: Text(
        (isLate ? "route_late" : live.status.titleKey).tr(),
        style: Styles.font12MediumBlack(
          context,
        ).copyWith(color: isLate ? AppColors.red : live.status.color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildStats(BuildContext context, RouteModel live) {
    final locale = context.locale.languageCode;
    final number = NumberFormat.decimalPattern(locale);

    return StatCardsRow(
      cards: [
        StatCard(label: "stops".tr(), value: number.format(live.stopsTotal), color: AppColors.neutralColor),
        StatCard(label: "completed_stops".tr(), value: number.format(live.stopsDone), color: AppColors.secondaryColor),
        StatCard(
          label: "distance_label".tr(),
          value: live.distanceKm == null ? "—" : NumberFormat("#0.0", locale).format(live.distanceKm),
          color: AppColors.primarySwatchColor,
        ),
      ],
    );
  }

  List<Widget> _buildStops(BuildContext context, RouteModel live) {
    return [
      for (int i = 0; i < live.stops.length; i++) ...[
        if (i != 0) SizedBox(height: AppConstants.height10(context)),
        RouteStopItem(stop: live.stops[i], order: i + 1),
      ],
    ];
  }
}
