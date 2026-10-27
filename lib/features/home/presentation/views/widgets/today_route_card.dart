import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_loading_item.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/route_item.dart';

/// Today's route card. When the driver has routes assigned for today it lists
/// them with the same card used in the routes screen, otherwise it shows an
/// empty state that explains what will happen and offers an explicit way to
/// check again, instead of relying on the pull to refresh gesture alone.
class TodayRouteCard extends StatelessWidget {
  const TodayRouteCard({
    super.key,
    this.routes = const [],
    this.onRouteTap,
    this.onRefresh,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<RouteModel> routes;

  /// First load in flight: a loader replaces the list.
  final bool isLoading;

  /// The load failed and there is nothing cached to show.
  final String? errorMessage;

  /// Called with the tapped route so the caller can open its details.
  final ValueChanged<RouteModel>? onRouteTap;

  final VoidCallback? onRefresh;

  /// Today's route first, then overdue ones, then the upcoming ones — the
  /// order the API hands them over in.
  List<RouteModel> get sortedRoutes => routes;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: const Color(0xffEDEFF2)),
        boxShadow: [
          BoxShadow(color: AppColors.neutralColor.withValues(alpha: .04), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(context),
          const Divider(height: 1, color: Color(0xffF0F2F5)),
          if (isLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppConstants.height30(context)),
              child: const CustomLoadingItem(),
            )
          else if (routes.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.width20(context),
                vertical: AppConstants.height30(context),
              ),
              child: _buildEmptyState(context),
            )
          else
            _buildRoutesList(context),
        ],
      ),
    );
  }

  Widget _buildCardTitle(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.width20(context),
        vertical: AppConstants.height15(context),
      ),
      child: Row(
        children: [
          Icon(
            Icons.route_rounded,
            size: MediaQuery.of(context).size.height * .024,
            color: AppColors.primarySwatchColor,
          ),
          SizedBox(width: AppConstants.width10(context)),
          Expanded(child: Text("today_route".tr(), style: Styles.font16SemiBoldBlack(context))),
          if (routes.isNotEmpty) _buildCountChip(context),
        ],
      ),
    );
  }

  Widget _buildCountChip(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.width10(context),
        vertical: AppConstants.height5(context) * .6,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySwatchColor.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppConstants.sp30(context)),
      ),
      child: Text(
        NumberFormat.decimalPattern(context.locale.languageCode).format(routes.length),
        style: Styles.font10MediumBlack(
          context,
        ).copyWith(color: AppColors.primarySwatchColor, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildRoutesList(BuildContext context) {
    final items = sortedRoutes;

    return Padding(
      padding: EdgeInsets.all(AppConstants.sp15(context)),
      child: Column(
        children: [
          for (int index = 0; index < items.length; index++) ...[
            if (index != 0) SizedBox(height: AppConstants.height10(context)),
            RouteItem(route: items[index], onTap: () => onRouteTap?.call(items[index])),
          ],
        ],
      ),
    );
  }

  /// Empty state, or the failure state when the request itself failed: same
  /// layout, danger tint and the server message instead of the hint.
  Widget _buildEmptyState(BuildContext context) {
    final iconSize = MediaQuery.of(context).size.height * .10;
    final bool hasError = errorMessage != null;
    final color = hasError ? AppColors.red : AppColors.primarySwatchColor;

    return Column(
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .08)),
          child: Icon(hasError ? Icons.wifi_off_rounded : Icons.list_alt_rounded, size: iconSize * .45, color: color),
        ),
        SizedBox(height: AppConstants.height20(context)),
        Text(
          (hasError ? "route_load_failed" : "no_route_title").tr(),
          textAlign: TextAlign.center,
          style: Styles.font16SemiBoldBlack(context),
        ),
        SizedBox(height: AppConstants.height10(context)),
        Text(
          hasError ? errorMessage! : "no_route_hint".tr(),
          textAlign: TextAlign.center,
          style: Styles.font12MediumGrey46(context).copyWith(height: 1.6),
        ),
        SizedBox(height: AppConstants.height20(context)),
        _buildRefreshButton(context),
      ],
    );
  }

  Widget _buildRefreshButton(BuildContext context) {
    final iconSize = MediaQuery.of(context).size.height * .022;

    return OutlinedButton(
      onPressed: onRefresh,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primarySwatchColor,
        side: BorderSide(color: AppColors.primarySwatchColor.withValues(alpha: .35)),
        padding: EdgeInsets.symmetric(
          horizontal: AppConstants.width20(context),
          vertical: AppConstants.height10(context),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.sp15(context))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh_rounded, size: iconSize),
          SizedBox(width: AppConstants.width5(context)),
          Text(
            "refresh".tr(),
            style: Styles.font14MediumBlack(
              context,
            ).copyWith(color: AppColors.primarySwatchColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
