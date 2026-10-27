import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_trip_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/view_models/van_trip/van_trip_cubit.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_widgets.dart';

/// Back at the warehouse: the driver enters what is left on the van (their
/// own count, optional) and gets the return code for the warehouse keeper.
class VanEndTripView extends StatefulWidget {
  const VanEndTripView({super.key});

  @override
  State<VanEndTripView> createState() => _VanEndTripViewState();
}

class _VanEndTripViewState extends State<VanEndTripView> {
  /// sku id → counted quantity; starts at what the server thinks is in the van.
  final Map<int, int> counts = {};
  String? error;

  @override
  void initState() {
    super.initState();
    final trip = context.read<VanTripCubit>().state.trip;
    for (final line in trip?.lines ?? const <VanTripLine>[]) {
      counts[line.skuId] = line.inVan.floor();
    }
  }

  Future<void> submit() async {
    setState(() => error = null);
    final result = await context.read<VanTripCubit>().startReturn({
      for (final entry in counts.entries) entry.key: entry.value.toDouble(),
    });
    if (!mounted) return;
    // The trip screen behind switches to the return code by itself.
    result.fold((failure) => setState(() => error = failure.errMessage), (_) => Navigator.of(context).pop());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VanTripCubit, VanTripState>(
      builder: (context, state) {
        final trip = state.trip;
        final bool isBusy = state.isBusy(VanTripAction.endTrip);

        return Scaffold(
          backgroundColor: const Color(0xffF5F7FA),
          body: SafeArea(
            child: Column(
              children: [
                CustomAppBar(title: "van_end_trip".tr()),
                Expanded(
                  child: trip == null
                      ? const SizedBox.shrink()
                      : ListView(
                          padding: EdgeInsets.fromLTRB(
                            AppConstants.width20(context),
                            AppConstants.height10(context),
                            AppConstants.width20(context),
                            AppConstants.height30(context),
                          ),
                          children: [
                            Text(
                              "van_end_trip_hint".tr(),
                              style: Styles.font12MediumGrey46(context).copyWith(height: 1.6),
                            ),
                            SizedBox(height: AppConstants.height15(context)),
                            SheetSectionLabel(title: "van_count_left".tr()),
                            for (final line in trip.lines) ...[
                              _buildLine(context, line),
                              SizedBox(height: AppConstants.height10(context)),
                            ],
                            SizedBox(height: AppConstants.height10(context)),
                            SheetCard(
                              child: VanTotalRow(
                                label: "van_cash_total".tr(),
                                value: VanFormat.money(context, trip.cashSalesTotal),
                                emphasize: true,
                              ),
                            ),
                            if (error != null) ...[
                              SizedBox(height: AppConstants.height15(context)),
                              SheetErrorBox(message: error!),
                            ],
                            SizedBox(height: AppConstants.height20(context)),
                            DefaultButton(
                              text: "van_get_return_code".tr(),
                              backgroundColor: AppColors.red,
                              borderRadius: AppConstants.sp15(context),
                              isEnabled: !isBusy,
                              icon: isBusy ? const VanButtonBusy() : null,
                              onPress: submit,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLine(BuildContext context, VanTripLine line) {
    // The driver may count more than the system expects; leave room for it.
    final max = line.loaded.floor();

    return SheetCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: Styles.font14MediumBlack(context)),
                SizedBox(height: AppConstants.height5(context) * .6),
                Text(
                  "${"van_expected_in_van".tr()} ${VanFormat.qty(context, line.inVan)}",
                  style: VanFormat.tabular(Styles.font11MediumGrey46(context)),
                ),
              ],
            ),
          ),
          VanQtyStepper(
            value: (counts[line.skuId] ?? 0).clamp(0, max),
            max: max,
            onChanged: (qty) => setState(() => counts[line.skuId] = qty),
          ),
        ],
      ),
    );
  }
}
