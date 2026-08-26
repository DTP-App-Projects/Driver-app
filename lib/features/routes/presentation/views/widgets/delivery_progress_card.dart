// intl (re-exported by easy_localization) ships its own TextDirection enum.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';

/// How far the delivery got: route code, percentage, bar and stop counter.
class DeliveryProgressCard extends StatelessWidget {
  const DeliveryProgressCard({
    super.key,
    required this.routeCode,
    required this.stopsDone,
    required this.stopsTotal,
    required this.progress,
  });

  final String routeCode;
  final int stopsDone;
  final int stopsTotal;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final number = NumberFormat.decimalPattern(locale);

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
          Row(
            children: [
              Expanded(
                child: Text(
                  routeCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                  style: Styles.font16SemiBoldBlack(context).copyWith(color: Colors.white),
                ),
              ),
              SizedBox(width: AppConstants.width10(context)),
              Text(
                NumberFormat.percentPattern(locale).format(progress),
                style: Styles.font20BoldBlack(context).copyWith(color: Colors.white),
              ),
            ],
          ),
          SizedBox(height: AppConstants.height15(context)),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.sp30(context)),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: MediaQuery.of(context).size.height * .010,
              backgroundColor: Colors.white.withValues(alpha: .25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(height: AppConstants.height10(context)),
          Text(
            "stops_count".tr(
              namedArgs: {"done": number.format(stopsDone), "total": number.format(stopsTotal)},
            ),
            style: Styles.font12MediumBlack(context).copyWith(color: Colors.white.withValues(alpha: .85)),
          ),
        ],
      ),
    );
  }
}
