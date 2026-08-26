// intl (re-exported by easy_localization) ships its own TextDirection enum.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';

/// One route card: code, readable date, status chip and the stops / distance
/// summary.
class RouteItem extends StatelessWidget {
  const RouteItem({super.key, required this.route, required this.onTap});

  final RouteModel route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppConstants.sp20(context));

    return Material(
      color: Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: const Color(0xffEDEFF2)),
          ),
          child: Padding(
            padding: EdgeInsets.all(AppConstants.sp15(context)),
            child: Row(
              children: [
                Expanded(child: _buildContent(context)),
                SizedBox(width: AppConstants.width10(context)),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: MediaQuery.of(context).size.height * .016,
                  color: AppColors.neutralColor[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final locale = context.locale.languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                route.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Styles.font14BoldBlack(context),
              ),
            ),
            SizedBox(width: AppConstants.width5(context)),
            _buildStatusChip(context),
          ],
        ),
        SizedBox(height: AppConstants.height5(context)),
        Text(DateFormat("d MMMM y • h:mm a", locale).format(route.date), style: Styles.font11MediumGrey46(context)),
        SizedBox(height: AppConstants.height10(context)),
        Row(
          children: [
            _buildMeta(
              context,
              icon: Icons.place_outlined,
              text: "stops_count".tr(
                namedArgs: {
                  "done": NumberFormat.decimalPattern(locale).format(route.stopsDone),
                  "total": NumberFormat.decimalPattern(locale).format(route.stopsTotal),
                },
              ),
            ),
            SizedBox(width: AppConstants.width15(context)),
            _buildMeta(
              context,
              icon: Icons.straighten_rounded,
              text: "distance_km".tr(namedArgs: {"distance": NumberFormat("#0.#", locale).format(route.distanceKm)}),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMeta(BuildContext context, {required IconData icon, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: MediaQuery.of(context).size.height * .016, color: AppColors.neutralColor[400]),
        SizedBox(width: AppConstants.width5(context) * .6),
        Text(text, style: Styles.font11MediumGrey46(context)),
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final color = route.isCompleted ? AppColors.secondaryColor : const Color(0xffE8A317);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.width10(context),
        vertical: AppConstants.height5(context) * .6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppConstants.sp30(context)),
      ),
      child: Text(
        (route.isCompleted ? "route_completed" : "route_in_progress").tr(),
        style: Styles.font10MediumBlack(context).copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
