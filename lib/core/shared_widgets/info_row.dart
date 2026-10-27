import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';

/// Label on one side, value on the other. Used for fact lists such as the
/// vehicle details or the app information.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Styles.font12MediumGrey46(context))),
        Text(
          value,
          style: Styles.font14MediumBlack(
            context,
          ).copyWith(color: valueColor ?? AppColors.neutralColor[800], fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
