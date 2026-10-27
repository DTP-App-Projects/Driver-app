import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_trip_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/view_models/van_trip/van_trip_cubit.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_widgets.dart';

/// Status `returning`: the large return code the warehouse keeper enters on
/// the web, and the cash to hand over. The keeper closes the trip there,
/// after which the trip disappears on the next refresh.
class VanReturnCodeSection extends StatelessWidget {
  const VanReturnCodeSection({super.key, required this.trip, required this.header});

  final VanTripModel trip;
  final Widget header;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VanTripCubit>();
    final bool isLoading = context.select<VanTripCubit, bool>((cubit) => cubit.state.isLoading);
    final code = trip.returnCode ?? "——————";

    return RefreshIndicator(
      color: AppColors.primarySwatchColor,
      onRefresh: () => cubit.loadTrip(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: AppConstants.height30(context)),
        children: [
          header,
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppConstants.width20(context),
              AppConstants.height20(context),
              AppConstants.width20(context),
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetCard(
                  padding: EdgeInsets.all(AppConstants.sp20(context)),
                  child: Column(
                    children: [
                      Text("van_return_code".tr(), style: Styles.font14MediumGrey46(context)),
                      SizedBox(height: AppConstants.height10(context)),
                      FittedBox(
                        child: Text(
                          code.split("").join(" "),
                          textDirection: TextDirection.ltr,
                          style: VanFormat.tabular(
                            Styles.font24BoldBlack(context).copyWith(
                              fontSize: MediaQuery.of(context).size.height * .055,
                              letterSpacing: 2,
                              color: AppColors.primarySwatchColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: AppConstants.height10(context)),
                      Text(
                        "van_return_code_hint".tr(),
                        textAlign: TextAlign.center,
                        style: Styles.font12MediumGrey46(context).copyWith(height: 1.6),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppConstants.height15(context)),
                SheetCard(
                  padding: EdgeInsets.all(AppConstants.sp20(context)),
                  child: Column(
                    children: [
                      Text("van_cash_to_hand_over".tr(), style: Styles.font14MediumGrey46(context)),
                      SizedBox(height: AppConstants.height5(context)),
                      Text(
                        VanFormat.money(context, trip.cashSalesTotal),
                        style: VanFormat.tabular(Styles.font24BoldBlack(context)),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppConstants.height15(context)),
                SheetSectionLabel(title: "van_returning_items".tr()),
                SheetCard(
                  child: Column(
                    children: [
                      for (final line in trip.lines)
                        VanTotalRow(label: line.name, value: VanFormat.qty(context, line.driverReturned ?? line.inVan)),
                    ],
                  ),
                ),
                SizedBox(height: AppConstants.height20(context)),
                DefaultButton(
                  text: "van_check_closed".tr(),
                  backgroundColor: Colors.white,
                  textColor: AppColors.primarySwatchColor,
                  hasBorder: true,
                  borderColor: AppColors.primarySwatchColor,
                  borderRadius: AppConstants.sp15(context),
                  isEnabled: !isLoading,
                  icon: isLoading ? const VanButtonBusy() : null,
                  onPress: () => cubit.loadTrip(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
