// intl (re-exported by easy_localization) ships its own TextDirection enum.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/today_route/today_route_cubit.dart';

/// A supplier side cancellation pushed while the driver works, pinned above
/// the route until the driver acknowledges it. The text is the notification
/// title / body the server sent (already in the driver's language); when the
/// push carried none the app's own copy for the event is shown.
class RouteAlertBanner extends StatelessWidget {
  const RouteAlertBanner({super.key, required this.alert});

  final RouteAlert alert;

  @override
  Widget build(BuildContext context) {
    final event = alert.event;
    final title = event.title?.trim().isNotEmpty == true
        ? event.title!
        : (alert.isRouteCanceled ? "alert_route_canceled_title" : "alert_shipment_canceled_title").tr();
    final body = event.body?.trim().isNotEmpty == true
        ? event.body!
        : (alert.isRouteCanceled ? "alert_route_canceled_body" : "alert_shipment_canceled_body").tr();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppConstants.sp15(context)),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(AppConstants.sp15(context)),
        border: Border.all(color: AppColors.red.withValues(alpha: .45), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.report_rounded, size: MediaQuery.of(context).size.height * .026, color: AppColors.red),
              SizedBox(width: AppConstants.width10(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Styles.font14MediumBlack(
                        context,
                      ).copyWith(color: AppColors.red, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: AppConstants.height5(context) * .6),
                    Text(body, style: Styles.font12MediumBlack(context).copyWith(height: 1.5)),
                    if (event.routeCode != null) ...[
                      SizedBox(height: AppConstants.height5(context) * .6),
                      Text(
                        event.routeCode!,
                        textDirection: TextDirection.ltr,
                        style: Styles.font11MediumGrey46(context),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (alert.returnToBase) ...[
            SizedBox(height: AppConstants.height10(context)),
            _buildHint(context, Icons.assignment_return_outlined, "alert_return_to_base_hint".tr()),
          ],
          if (alert.isRouteClosed) ...[
            SizedBox(height: AppConstants.height10(context)),
            _buildHint(
              context,
              Icons.flag_circle_outlined,
              (alert.closedStatus == RouteStatus.completed
                      ? "alert_route_closed_completed"
                      : "alert_route_closed_canceled")
                  .tr(),
            ),
          ],
          SizedBox(height: AppConstants.height15(context)),
          DefaultButton(
            text: "alert_dismiss".tr(),
            backgroundColor: AppColors.red,
            borderRadius: AppConstants.sp15(context),
            onPress: context.read<TodayRouteCubit>().dismissAlert,
          ),
        ],
      ),
    );
  }

  /// What the cancellation means for the driver right now: goods already on
  /// the truck go back to the warehouse (the new last stop), or nothing is
  /// left on the route and the server closed it.
  Widget _buildHint(BuildContext context, IconData icon, String text) {
    return Container(
      padding: EdgeInsets.all(AppConstants.sp10(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp10(context)),
        border: Border.all(color: const Color(0xffEDEFF2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: MediaQuery.of(context).size.height * .022, color: AppColors.primarySwatchColor),
          SizedBox(width: AppConstants.width10(context)),
          Expanded(child: Text(text, style: Styles.font11MediumGrey46(context).copyWith(height: 1.5))),
        ],
      ),
    );
  }
}

/// Replaces the current stop card once the supplier canceled the route the
/// driver was on.
class RouteCanceledCard extends StatelessWidget {
  const RouteCanceledCard({super.key});

  @override
  Widget build(BuildContext context) {
    final iconSize = MediaQuery.of(context).size.height * .08;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppConstants.sp20(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: AppColors.red.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.red.withValues(alpha: .10)),
            child: Icon(Icons.block_rounded, size: iconSize * .45, color: AppColors.red),
          ),
          SizedBox(height: AppConstants.height15(context)),
          Text(
            "alert_route_canceled_title".tr(),
            textAlign: TextAlign.center,
            style: Styles.font16SemiBoldBlack(context),
          ),
          SizedBox(height: AppConstants.height5(context)),
          Text(
            "alert_route_canceled_body".tr(),
            textAlign: TextAlign.center,
            style: Styles.font12MediumGrey46(context).copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}
