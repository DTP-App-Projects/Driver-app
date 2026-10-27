import 'package:digital_trade_portal_driver/core/utils/assets/assets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Greeting block: time based greeting, driver name and today's date, with the
/// notifications button on the opposite side.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    this.driverName,
    this.hasUnreadNotifications = false,
    this.onNotificationsTap,
    this.onEmergencyTap,
  });

  final String? driverName;
  final bool hasUnreadNotifications;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onEmergencyTap;

  String get _greetingKey => DateTime.now().hour < 12 ? "good_morning" : "good_evening";

  @override
  Widget build(BuildContext context) {
    final date = DateFormat("EEEE، d MMMM y", context.locale.languageCode).format(DateTime.now());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greetingKey.tr(), style: Styles.font14MediumGrey46(context)),
              SizedBox(height: AppConstants.height5(context)),
              Text(
                driverName ?? "welcome_driver".tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Styles.font24BoldBlack(context),
              ),
              SizedBox(height: AppConstants.height5(context)),
              Text(date, style: Styles.font12MediumGrey46(context)),
            ],
          ),
        ),
        SizedBox(width: AppConstants.width10(context)),
        _EmergencyButton(onTap: onEmergencyTap),
        SizedBox(width: AppConstants.width5(context)),
        _NotificationsButton(hasUnread: hasUnreadNotifications, onTap: onNotificationsTap),
      ],
    );
  }
}

/// Shortcut to the report an issue screen, tinted in the danger colour so it
/// reads as the urgent action next to the neutral bell.
class _EmergencyButton extends StatelessWidget {
  const _EmergencyButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.height * .052;

    return Semantics(
      button: true,
      label: "report_issue".tr(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.red.withValues(alpha: .08),
            border: Border.all(color: AppColors.red.withValues(alpha: .25)),
          ),
          child: Icon(Icons.warning_amber_rounded, size: size * .5, color: AppColors.red),
        ),
      ),
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton({required this.hasUnread, this.onTap});

  final bool hasUnread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.height * .052;

    return Semantics(
      button: true,
      label: "notifications".tr(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xffEDEFF2)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SvgPicture.asset(AssetData.notification),
              if (hasUnread)
                PositionedDirectional(
                  top: size * .24,
                  end: size * .26,
                  child: Container(
                    width: size * .16,
                    height: size * .16,
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
