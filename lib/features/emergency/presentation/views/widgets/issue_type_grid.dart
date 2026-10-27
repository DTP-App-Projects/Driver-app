import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/emergency/data/models/issue_type.dart';

/// Two column picker for the issue type, one card per [IssueType].
class IssueTypeGrid extends StatelessWidget {
  const IssueTypeGrid({super.key, required this.selected, required this.onSelect});

  final IssueType? selected;
  final ValueChanged<IssueType> onSelect;

  @override
  Widget build(BuildContext context) {
    final spacing = AppConstants.width10(context);

    return Column(
      children: [
        for (int row = 0; row < IssueType.values.length; row += 2) ...[
          if (row != 0) SizedBox(height: spacing),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int column = row; column < row + 2 && column < IssueType.values.length; column++) ...[
                  if (column != row) SizedBox(width: spacing),
                  Expanded(
                    child: IssueTypeCard(
                      type: IssueType.values[column],
                      isSelected: selected == IssueType.values[column],
                      onTap: () => onSelect(IssueType.values[column]),
                    ),
                  ),
                ],
                // Keeps a lone last card at half width, in its column.
                if (row + 1 >= IssueType.values.length) ...[
                  SizedBox(width: spacing),
                  const Expanded(child: SizedBox()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class IssueTypeCard extends StatelessWidget {
  const IssueTypeCard({super.key, required this.type, required this.isSelected, required this.onTap});

  final IssueType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppConstants.sp20(context));
    final circleSize = MediaQuery.of(context).size.height * .058;

    return Material(
      color: isSelected ? AppColors.primarySwatchColor.withValues(alpha: .06) : Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isSelected ? AppColors.primarySwatchColor : const Color(0xffEDEFF2),
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppConstants.width10(context),
              vertical: AppConstants.height20(context),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: type.color.withValues(alpha: .12)),
                  child: Icon(type.icon, size: circleSize * .5, color: type.color),
                ),
                SizedBox(height: AppConstants.height10(context)),
                Text(
                  type.titleKey.tr(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: Styles.font12MediumBlack(context).copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primarySwatchColor : AppColors.neutralColor[800],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
