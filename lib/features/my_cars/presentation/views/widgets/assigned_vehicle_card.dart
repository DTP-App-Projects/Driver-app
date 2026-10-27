import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/my_cars/data/models/vehicle_model.dart';

/// Brand gradient card for the vehicle currently assigned to the driver.
class AssignedVehicleCard extends StatelessWidget {
  const AssignedVehicleCard({super.key, required this.vehicle});

  final VehicleModel vehicle;

  @override
  Widget build(BuildContext context) {
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
              Icon(vehicle.type.icon, size: MediaQuery.of(context).size.height * .05, color: Colors.white),
              SizedBox(width: AppConstants.width15(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "plate".tr(),
                      style: Styles.font12MediumBlack(context).copyWith(color: Colors.white.withValues(alpha: .80)),
                    ),
                    SizedBox(height: AppConstants.height5(context) * .6),
                    Text(
                      vehicle.plate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Styles.font24BoldBlack(context).copyWith(color: Colors.white, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppConstants.height20(context)),
          Divider(color: Colors.white.withValues(alpha: .25), height: 1),
          SizedBox(height: AppConstants.height15(context)),
          Row(
            children: [
              _buildFact(context, label: "vehicle_type".tr(), value: vehicle.type.titleKey.tr()),
              _buildFact(context, label: "vehicle_model".tr(), value: vehicle.model ?? "—"),
              _buildFact(
                context,
                label: "capacity".tr(),
                value: "tons".tr(
                  namedArgs: {"value": NumberFormat("#0.#", context.locale.languageCode).format(vehicle.capacityTons)},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFact(BuildContext context, {required String label, required String value}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Styles.font11MediumBlack(context).copyWith(color: Colors.white.withValues(alpha: .75)),
          ),
          SizedBox(height: AppConstants.height5(context) * .6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Styles.font14BoldBlack(context).copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
