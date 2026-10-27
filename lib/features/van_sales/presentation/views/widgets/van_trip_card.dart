import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_loading_text.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_trip_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/view_models/van_trip/van_trip_cubit.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/van_trip_view.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_widgets.dart';

/// Home entry of the van trip. Hidden when the driver has no open trip.
class VanTripCard extends StatelessWidget {
  const VanTripCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VanTripCubit, VanTripState>(
      builder: (context, state) {
        final trip = state.trip;
        if (trip == null) {
          // First load: a skeleton keeps the layout from jumping when a trip appears.
          if (state.isLoading && !state.hasLoaded) return _wrap(context, _buildSkeleton(context));
          return const SizedBox.shrink();
        }
        return _wrap(
          context,
          InkWell(
            borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
            onTap: () => NavigationUtils.navigateTo(context: context, destinationScreen: const VanTripView()),
            child: _buildContent(context, trip, state.pendingSales.length),
          ),
        );
      },
    );
  }

  Widget _wrap(BuildContext context, Widget child) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppConstants.height20(context)),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
            border: Border.all(color: const Color(0xffEDEFF2)),
            boxShadow: [
              BoxShadow(
                color: AppColors.neutralColor.withValues(alpha: .04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.all(AppConstants.sp20(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomLoadingText(width: width * .35),
          SizedBox(height: AppConstants.height15(context)),
          CustomLoadingText(width: width * .6),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, VanTripModel trip, int pendingCount) {
    final iconSize = MediaQuery.of(context).size.height * .024;

    return Padding(
      padding: EdgeInsets.all(AppConstants.sp20(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_rounded, size: iconSize, color: AppColors.primarySwatchColor),
              SizedBox(width: AppConstants.width10(context)),
              Expanded(child: Text("van_trip".tr(), style: Styles.font16SemiBoldBlack(context))),
              VanStatusChip(status: trip.status),
            ],
          ),
          SizedBox(height: AppConstants.height10(context)),
          Text(trip.code, textDirection: TextDirection.ltr, style: VanFormat.tabular(Styles.font14BoldBlack(context))),
          if (trip.supplierName.isNotEmpty) ...[
            SizedBox(height: AppConstants.height5(context) * .6),
            Text(trip.supplierName, style: Styles.font12MediumGrey46(context)),
          ],
          SizedBox(height: AppConstants.height15(context)),
          Row(
            children: [
              Expanded(child: _buildFigure(context, "van_in_van_total".tr(), VanFormat.qty(context, trip.totalInVan))),
              Expanded(
                child: _buildFigure(context, "van_cash_total".tr(), VanFormat.money(context, trip.cashSalesTotal)),
              ),
            ],
          ),
          if (pendingCount > 0) ...[
            SizedBox(height: AppConstants.height10(context)),
            Text(
              "van_pending_sales_count".tr(namedArgs: {"count": VanFormat.qty(context, pendingCount)}),
              style: Styles.font12MediumBlack(
                context,
              ).copyWith(color: const Color(0xffE8A317), fontWeight: FontWeight.w700),
            ),
          ],
          if (trip.isDraft) ...[
            SizedBox(height: AppConstants.height10(context)),
            Text("van_draft_hint".tr(), style: Styles.font12MediumGrey46(context).copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _buildFigure(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Styles.font11MediumGrey46(context)),
        SizedBox(height: AppConstants.height5(context) * .6),
        Text(value, style: VanFormat.tabular(Styles.font16BoldBlack(context))),
      ],
    );
  }
}
