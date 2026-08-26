import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/delivery_format.dart';

/// Everything needed to close a stop without leaving the map: what it is, how
/// far it is, and the action that moves it forward.
class StopActionsSheet extends StatelessWidget {
  const StopActionsSheet({
    super.key,
    required this.stop,
    required this.order,
    required this.onAdvance,
    required this.onShowOnMap,
    this.distanceMeters,
  });

  final RouteStop stop;
  final int order;
  final VoidCallback onAdvance;
  final VoidCallback onShowOnMap;
  final double? distanceMeters;

  @override
  Widget build(BuildContext context) {
    final isCompleted = stop.status == StopStatus.completed;
    final isArrived = stop.status == StopStatus.arrived;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppConstants.width20(context),
        AppConstants.height15(context),
        AppConstants.width20(context),
        AppConstants.height30(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(context),
          SizedBox(height: AppConstants.height20(context)),
          Text("$order. ${stop.name}", style: Styles.font16SemiBoldBlack(context)),
          SizedBox(height: AppConstants.height5(context)),
          _buildSubtitle(context),
          SizedBox(height: AppConstants.height20(context)),
          if (isCompleted)
            _buildCompletedRow(context)
          else
            DefaultButton(
              text: (isArrived ? "complete_stop" : "mark_arrived").tr(),
              gradient: AppColors.brandGradient,
              borderRadius: AppConstants.sp15(context),
              icon: Icon(
                isArrived ? Icons.check_circle_outline_rounded : Icons.location_on_outlined,
                size: MediaQuery.of(context).size.height * .022,
                color: Colors.white,
              ),
              onPress: onAdvance,
            ),
          SizedBox(height: AppConstants.height10(context)),
          DefaultButton(
            text: "show_on_map".tr(),
            backgroundColor: Colors.white,
            textColor: AppColors.primarySwatchColor,
            hasBorder: true,
            borderColor: AppColors.primarySwatchColor,
            borderRadius: AppConstants.sp15(context),
            onPress: onShowOnMap,
          ),
        ],
      ),
    );
  }

  Widget _buildHandle(BuildContext context) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * .12,
        height: MediaQuery.of(context).size.height * .005,
        decoration: BoxDecoration(
          color: AppColors.neutralColor[200],
          borderRadius: BorderRadius.circular(AppConstants.sp30(context)),
        ),
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    return Row(
      children: [
        Text(
          "${stop.type.titleKey.tr()} • ${stop.status.titleKey.tr()}",
          style: Styles.font11MediumGrey46(context),
        ),
        if (distanceMeters != null) ...[
          SizedBox(width: AppConstants.width10(context)),
          Icon(
            Icons.near_me_rounded,
            size: MediaQuery.of(context).size.height * .014,
            color: AppColors.primarySwatchColor,
          ),
          SizedBox(width: AppConstants.width5(context) * .6),
          Text(
            DeliveryFormat.distanceAway(context, distanceMeters!),
            style: Styles.font11BoldBlack(context).copyWith(color: AppColors.primarySwatchColor),
          ),
        ],
      ],
    );
  }

  Widget _buildCompletedRow(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: MediaQuery.of(context).size.height * .022,
          color: AppColors.secondaryColor,
        ),
        SizedBox(width: AppConstants.width5(context)),
        Text(
          "route_completed".tr(),
          style: Styles.font12MediumBlack(
            context,
          ).copyWith(color: AppColors.secondaryColor, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
