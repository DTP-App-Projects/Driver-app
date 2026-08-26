import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';

/// Brand gradient panel with the driver identity: initial avatar, name, phone
/// and the duty status chip.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.name, required this.phone, this.isOnline = true});

  final String name;
  final String phone;
  final bool isOnline;

  String get _initial => name.trim().isEmpty ? "?" : name.trim().characters.first;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppConstants.width20(context),
        AppConstants.height20(context),
        AppConstants.width20(context),
        AppConstants.height30(context),
      ),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadiusDirectional.only(
          bottomStart: Radius.circular(AppConstants.sp30(context)),
          bottomEnd: Radius.circular(AppConstants.sp30(context)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: AppConstants.height10(context)),
            Row(
              children: [
                _buildAvatar(context),
                SizedBox(width: AppConstants.width15(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Styles.font20BoldBlack(context).copyWith(color: Colors.white),
                      ),
                      SizedBox(height: AppConstants.height5(context) * .5),
                      Text(
                        phone,
                        textDirection: TextDirection.ltr,
                        style: Styles.font12MediumBlack(
                          context,
                        ).copyWith(color: Colors.white.withValues(alpha: .80)),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final size = MediaQuery.of(context).size.height * .07;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white.withValues(alpha: .55), width: 3),
      ),
      child: Text(
        _initial,
        style: Styles.font24BoldBlack(context).copyWith(color: AppColors.primarySwatchColor),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final dotSize = MediaQuery.of(context).size.height * .009;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.width15(context),
        vertical: AppConstants.height5(context),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(AppConstants.sp30(context)),
        border: Border.all(color: Colors.white.withValues(alpha: .30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? const Color(0xff4ADE80) : const Color(0xffD0D5DD),
            ),
          ),
          SizedBox(width: AppConstants.width5(context)),
          Text(
            (isOnline ? "online" : "offline").tr(),
            style: Styles.font12MediumBlack(context).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
