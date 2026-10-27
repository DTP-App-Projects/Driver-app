import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';

/// One row of a [ProfileMenuSection]: tinted leading icon, label, optional
/// trailing value and a chevron. [isDestructive] paints it in the danger colour
/// and drops the chevron, for actions like log out or delete account.
class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailingText,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? trailingText;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.red : AppColors.primarySwatchColor;
    final circleSize = MediaQuery.of(context).size.height * .046;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppConstants.width15(context),
          vertical: AppConstants.height15(context),
        ),
        child: Row(
          children: [
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .10)),
              child: Icon(icon, size: circleSize * .52, color: color),
            ),
            SizedBox(width: AppConstants.width15(context)),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Styles.font14MediumBlack(context).copyWith(
                  color: isDestructive ? AppColors.red : AppColors.neutralColor[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(trailingText!, style: Styles.font12MediumGrey46(context)),
              SizedBox(width: AppConstants.width5(context)),
            ],
            if (!isDestructive)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: MediaQuery.of(context).size.height * .016,
                color: AppColors.neutralColor[400],
              ),
          ],
        ),
      ),
    );
  }
}
