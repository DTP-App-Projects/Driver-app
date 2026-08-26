import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';

/// One stop of a route: order number, place name, what happens there and the
/// stop status.
class RouteStopItem extends StatelessWidget {
  const RouteStopItem({super.key, required this.stop, required this.order, this.onTap});

  final RouteStop stop;
  final int order;

  /// Set while a delivery is running, to open the actions for this stop.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppConstants.sp20(context));
    final card = _buildCard(context);

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(onTap: onTap, borderRadius: radius, child: card),
    );
  }

  Widget _buildCard(BuildContext context) {
    final circleSize = MediaQuery.of(context).size.height * .046;

    return Container(
      padding: EdgeInsets.all(AppConstants.sp15(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: const Color(0xffEDEFF2)),
      ),
      child: Row(
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primarySwatchColor.withValues(alpha: .10),
            ),
            child: Text(
              NumberFormat.decimalPattern(context.locale.languageCode).format(order),
              style: Styles.font14BoldBlack(context).copyWith(color: AppColors.primarySwatchColor),
            ),
          ),
          SizedBox(width: AppConstants.width15(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Styles.font14MediumBlack(context).copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: AppConstants.height5(context) * .6),
                Text(stop.type.titleKey.tr(), style: Styles.font11MediumGrey46(context)),
              ],
            ),
          ),
          SizedBox(width: AppConstants.width10(context)),
          _buildStatusChip(context),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.width10(context),
        vertical: AppConstants.height5(context) * .6,
      ),
      decoration: BoxDecoration(
        color: stop.status.color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppConstants.sp30(context)),
      ),
      child: Text(
        stop.status.titleKey.tr(),
        style: Styles.font10MediumBlack(context).copyWith(color: stop.status.color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
