import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_trip_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/view_models/van_trip/van_trip_cubit.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/van_end_trip_view.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_widgets.dart';

/// What is on the van right now, item by item, with the way out (End trip).
class VanStockTab extends StatelessWidget {
  const VanStockTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VanTripCubit, VanTripState>(
      builder: (context, state) {
        final trip = state.trip;
        if (trip == null) return const SizedBox.shrink();

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primarySwatchColor,
                onRefresh: () => context.read<VanTripCubit>().loadTrip(silent: true),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(AppConstants.sp20(context)),
                  itemCount: trip.lines.length,
                  separatorBuilder: (_, _) => SizedBox(height: AppConstants.height10(context)),
                  itemBuilder: (context, index) => _VanStockLine(line: trip.lines[index]),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                AppConstants.width20(context),
                AppConstants.height10(context),
                AppConstants.width20(context),
                AppConstants.height15(context),
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xffEDEFF2))),
              ),
              child: DefaultButton(
                text: "van_end_trip".tr(),
                backgroundColor: Colors.white,
                textColor: AppColors.red,
                hasBorder: true,
                borderColor: AppColors.red,
                borderRadius: AppConstants.sp15(context),
                icon: Icon(
                  Icons.warehouse_rounded,
                  color: AppColors.red,
                  size: MediaQuery.of(context).size.height * .022,
                ),
                onPress: () => NavigationUtils.navigateTo(context: context, destinationScreen: const VanEndTripView()),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VanStockLine extends StatelessWidget {
  const _VanStockLine({required this.line});

  final VanTripLine line;

  @override
  Widget build(BuildContext context) {
    final figures = <(String, double)>[
      ("van_loaded", line.loaded),
      ("van_sold", line.sold),
      ("van_delivered", line.delivered),
      if (line.inTransit > 0) ("van_in_transit", line.inTransit),
    ];

    return SheetCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: Styles.font14MediumBlack(context)),
                SizedBox(height: AppConstants.height5(context)),
                Wrap(
                  spacing: AppConstants.width10(context),
                  runSpacing: AppConstants.height5(context) * .6,
                  children: [
                    for (final (key, value) in figures)
                      Text(
                        "${key.tr()} ${VanFormat.qty(context, value)}",
                        style: VanFormat.tabular(Styles.font11MediumGrey46(context)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: AppConstants.width10(context)),
          Column(
            children: [
              Text(
                VanFormat.qty(context, line.inVan),
                style: VanFormat.tabular(
                  Styles.font24BoldBlack(
                    context,
                  ).copyWith(color: line.inVan > 0 ? AppColors.primarySwatchColor : AppColors.neutralColor[400]),
                ),
              ),
              Text("van_in_van".tr(), style: Styles.font10MediumGrey46(context)),
            ],
          ),
        ],
      ),
    );
  }
}
