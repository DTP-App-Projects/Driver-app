import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';

/// One account fact: tinted leading icon, the label above and the value under
/// it. [isLtr] keeps latin values such as an email or a phone number reading
/// left to right while the app is in Arabic.
class AccountInfoTile extends StatelessWidget {
  const AccountInfoTile({super.key, required this.icon, required this.label, required this.value, this.isLtr = false});

  final IconData icon;
  final String label;
  final String value;
  final bool isLtr;

  @override
  Widget build(BuildContext context) {
    final circleSize = MediaQuery.of(context).size.height * .046;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.width15(context),
        vertical: AppConstants.height15(context),
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
            child: Icon(icon, size: circleSize * .5, color: AppColors.primarySwatchColor),
          ),
          SizedBox(width: AppConstants.width15(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Styles.font11MediumGrey46(context)),
                SizedBox(height: AppConstants.height5(context) * .6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: isLtr ? TextDirection.ltr : null,
                  textAlign: TextAlign.start,
                  style: Styles.font14MediumBlack(context).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
