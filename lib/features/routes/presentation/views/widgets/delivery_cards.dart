import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/info_row.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/delivery_format.dart';

/// The stop the driver is on, with the one action that moves it forward and
/// the live distance or drive time to it.
class CurrentStopCard extends StatelessWidget {
  const CurrentStopCard({
    super.key,
    required this.stop,
    required this.onAction,
    this.summary,
    this.isBusy = false,
    this.isPendingSync = false,
  });

  final RouteStop stop;
  final VoidCallback onAction;

  /// Road distance and drive time, or the straight line distance as a fallback.
  final String? summary;

  /// A request for this stop is in flight: the button waits for it.
  final bool isBusy;

  /// The last action is queued offline.
  final bool isPendingSync;

  /// The one action the server accepts next for this stop.
  String get _actionKey => switch (stop.status) {
    StopStatus.pending => "head_to_stop",
    StopStatus.enRoute => "mark_arrived",
    StopStatus.arrived => stop.type.confirmKey,
    _ => "complete_stop",
  };

  IconData get _actionIcon => switch (stop.status) {
    StopStatus.pending => Icons.navigation_rounded,
    StopStatus.enRoute => Icons.location_on_outlined,
    _ => stop.isReturn ? Icons.assignment_return_outlined : Icons.check_circle_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppConstants.sp20(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: AppColors.primarySwatchColor.withValues(alpha: .35)),
        // Lifts the card off the map while it floats over the full screen one.
        boxShadow: [
          BoxShadow(color: AppColors.neutralColor.withValues(alpha: .08), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.my_location_rounded,
                size: MediaQuery.of(context).size.height * .020,
                color: AppColors.primarySwatchColor,
              ),
              SizedBox(width: AppConstants.width5(context)),
              Expanded(child: Text("current_stop".tr(), style: Styles.font12MediumGrey46(context))),
              if (summary != null)
                Text(summary!, style: Styles.font11BoldBlack(context).copyWith(color: AppColors.primarySwatchColor)),
            ],
          ),
          SizedBox(height: AppConstants.height10(context)),
          Text(stop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Styles.font16SemiBoldBlack(context)),
          SizedBox(height: AppConstants.height5(context)),
          Text(
            "${stop.type.titleKey.tr()} • ${stop.status.titleKey.tr()}"
            "${isPendingSync ? " • ${"pending_sync".tr()}" : ""}",
            style: Styles.font11MediumGrey46(context),
          ),
          SizedBox(height: AppConstants.height20(context)),
          DefaultButton(
            text: _actionKey.tr(),
            gradient: AppColors.brandGradient,
            borderRadius: AppConstants.sp15(context),
            isEnabled: !isBusy,
            icon: Icon(_actionIcon, size: MediaQuery.of(context).size.height * .022, color: Colors.white),
            onPress: onAction,
          ),
        ],
      ),
    );
  }
}

/// Closing state of the delivery, in place of the current stop card. Once
/// the route was completed on the server the end of day summary shows here.
class DeliveryFinishedCard extends StatelessWidget {
  const DeliveryFinishedCard({super.key, this.isRouteCompleted = false, this.summary});

  final bool isRouteCompleted;
  final EndOfDaySummaryModel? summary;

  @override
  Widget build(BuildContext context) {
    final iconSize = MediaQuery.of(context).size.height * .08;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppConstants.sp20(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: AppColors.secondaryColor.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.secondaryColor.withValues(alpha: .10)),
            child: Icon(Icons.done_all_rounded, size: iconSize * .45, color: AppColors.secondaryColor),
          ),
          SizedBox(height: AppConstants.height15(context)),
          Text(
            (isRouteCompleted ? "route_completed_title" : "all_stops_completed").tr(),
            textAlign: TextAlign.center,
            style: Styles.font16SemiBoldBlack(context),
          ),
          SizedBox(height: AppConstants.height5(context)),
          Text(
            (isRouteCompleted ? "route_completed_hint" : "all_stops_completed_hint").tr(),
            textAlign: TextAlign.center,
            style: Styles.font12MediumGrey46(context).copyWith(height: 1.6),
          ),
          if (summary != null) ...[
            SizedBox(height: AppConstants.height15(context)),
            const Divider(height: 1, color: Color(0xffF0F2F5)),
            SizedBox(height: AppConstants.height15(context)),
            _buildSummary(context, summary!),
          ],
        ],
      ),
    );
  }

  /// End of day numbers in the same fact rows the vehicle details use.
  Widget _buildSummary(BuildContext context, EndOfDaySummaryModel summary) {
    final locale = context.locale.languageCode;
    final number = NumberFormat.decimalPattern(locale);

    final rows = <MapEntry<String, String>>[
      MapEntry("completed_stops".tr(), "${number.format(summary.completedStops)}/${number.format(summary.totalStops)}"),
      MapEntry("skipped_stops".tr(), number.format(summary.skippedStops)),
      if (summary.canceledStops > 0) MapEntry("canceled_stops".tr(), number.format(summary.canceledStops)),
      MapEntry("deliveries".tr(), number.format(summary.deliveriesDone)),
      MapEntry("pickups".tr(), number.format(summary.pickupsDone)),
      MapEntry("delivered_qty".tr(), number.format(summary.totalDeliveredQty)),
      MapEntry("returned_qty".tr(), number.format(summary.totalReturnedQty)),
      MapEntry("damaged_qty".tr(), number.format(summary.totalDamagedQty)),
      if (summary.distanceKm != null)
        MapEntry("distance_label".tr(), NumberFormat("#0.0", locale).format(summary.distanceKm)),
      if (summary.workingMinutes != null)
        MapEntry("working_time".tr(), DeliveryFormat.duration(context, Duration(minutes: summary.workingMinutes!))),
    ];

    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          if (i != 0) SizedBox(height: AppConstants.height10(context)),
          InfoRow(label: rows[i].key, value: rows[i].value),
        ],
      ],
    );
  }
}

/// Explains why the driver is not on the map, with the fix for that reason.
class LocationPermissionBanner extends StatelessWidget {
  const LocationPermissionBanner({super.key, required this.hintKey, required this.onEnable});

  final String hintKey;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    const warning = Color(0xffE8A317);

    return Container(
      padding: EdgeInsets.all(AppConstants.sp15(context)),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppConstants.sp15(context)),
        border: Border.all(color: warning.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off_rounded, size: MediaQuery.of(context).size.height * .022, color: warning),
          SizedBox(width: AppConstants.width10(context)),
          Expanded(child: Text(hintKey.tr(), style: Styles.font11MediumGrey46(context))),
          TextButton(
            onPressed: onEnable,
            child: Text(
              "enable_location".tr(),
              style: Styles.font11BoldBlack(context).copyWith(color: AppColors.primarySwatchColor),
            ),
          ),
        ],
      ),
    );
  }
}
