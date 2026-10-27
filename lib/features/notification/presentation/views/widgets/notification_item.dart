import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/notification/data/models/notification_model.dart';

/// One row of the notifications list. Unread rows keep a tinted surface, a
/// stronger title and a trailing dot so they stay scannable at a glance.
class NotificationItem extends StatelessWidget {
  const NotificationItem({super.key, required this.notification, required this.onTap});

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isUnread = !notification.isRead;
    final radius = BorderRadius.circular(AppConstants.sp20(context));
    final circleSize = MediaQuery.of(context).size.height * .052;

    return Material(
      color: isUnread ? AppColors.primarySwatchColor.withValues(alpha: .05) : Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isUnread ? AppColors.primarySwatchColor.withValues(alpha: .18) : const Color(0xffEDEFF2),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(AppConstants.sp15(context)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: notification.color.withValues(alpha: .10)),
                  child: Icon(notification.icon, size: circleSize * .5, color: notification.color),
                ),
                SizedBox(width: AppConstants.width15(context)),
                Expanded(child: _buildContent(context, isUnread: isUnread)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, {required bool isUnread}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: Styles.font14MediumBlack(
                  context,
                ).copyWith(fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600),
              ),
            ),
            if (isUnread) ...[
              SizedBox(width: AppConstants.width5(context)),
              Padding(
                padding: EdgeInsets.only(top: AppConstants.height5(context)),
                child: Container(
                  width: AppConstants.width5(context),
                  height: AppConstants.width5(context),
                  decoration: BoxDecoration(color: AppColors.primarySwatchColor, shape: BoxShape.circle),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: AppConstants.height5(context)),
        Text(
          notification.body,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Styles.font12MediumGrey46(context).copyWith(height: 1.6),
        ),
        SizedBox(height: AppConstants.height10(context)),
        Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: MediaQuery.of(context).size.height * .016,
              color: AppColors.neutralColor[400],
            ),
            SizedBox(width: AppConstants.width5(context)),
            Text(
              _timeLabel(context),
              style: Styles.font10MediumGrey46(context).copyWith(color: AppColors.neutralColor[400]),
            ),
          ],
        ),
      ],
    );
  }

  /// Time of day for anything sent today, day and month for older entries.
  String _timeLabel(BuildContext context) {
    final locale = context.locale.languageCode;
    final now = DateTime.now();
    final isToday =
        notification.date.year == now.year && notification.date.month == now.month && notification.date.day == now.day;

    return isToday
        ? DateFormat.jm(locale).format(notification.date)
        : DateFormat("d MMMM، h:mm a", locale).format(notification.date);
  }
}
