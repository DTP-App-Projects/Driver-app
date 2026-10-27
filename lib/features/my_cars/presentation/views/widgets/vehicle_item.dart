import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/my_cars/data/models/vehicle_model.dart';

/// One vehicle of the fleet. The assigned one is marked with a check and is not
/// tappable, the rest can be picked.
class VehicleItem extends StatelessWidget {
  const VehicleItem({super.key, required this.vehicle, required this.onTap});

  final VehicleModel vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isAssigned = vehicle.isAssigned;
    final radius = BorderRadius.circular(AppConstants.sp20(context));
    final circleSize = MediaQuery.of(context).size.height * .046;

    return Material(
      color: isAssigned ? AppColors.secondaryColor.withValues(alpha: .05) : Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: isAssigned ? null : onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isAssigned ? AppColors.secondaryColor.withValues(alpha: .30) : const Color(0xffEDEFF2),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(AppConstants.sp15(context)),
            child: Row(
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primarySwatchColor.withValues(alpha: .10),
                  ),
                  child: Icon(vehicle.type.icon, size: circleSize * .52, color: AppColors.primarySwatchColor),
                ),
                SizedBox(width: AppConstants.width15(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.plate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Styles.font14BoldBlack(context),
                      ),
                      SizedBox(height: AppConstants.height5(context) * .6),
                      Text(
                        "${vehicle.type.titleKey.tr()} • ${vehicle.fullName}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Styles.font11MediumGrey46(context),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppConstants.width10(context)),
                _buildTrailing(context, isAssigned: isAssigned),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrailing(BuildContext context, {required bool isAssigned}) {
    final size = MediaQuery.of(context).size.height * .022;

    if (isAssigned) {
      return Icon(Icons.check_circle_rounded, size: size, color: AppColors.secondaryColor);
    }

    return Icon(Icons.arrow_forward_rounded, size: size, color: AppColors.neutralColor[400]);
  }
}
