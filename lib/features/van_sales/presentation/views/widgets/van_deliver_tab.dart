import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_delivery_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/view_models/van_trip/van_trip_cubit.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/van_delivery_form_view.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_widgets.dart';

/// Registered traders the van can deliver to: fill one of their open orders
/// or take a spot order at the shop.
class VanDeliverTab extends StatefulWidget {
  const VanDeliverTab({super.key});

  @override
  State<VanDeliverTab> createState() => _VanDeliverTabState();
}

class _VanDeliverTabState extends State<VanDeliverTab> {
  final TextEditingController search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cubit = context.read<VanTripCubit>();
    cubit.loadTraders(silent: cubit.state.tradersLoaded);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VanTripCubit, VanTripState>(
      builder: (context, state) {
        final cubit = context.read<VanTripCubit>();
        final padding = EdgeInsets.all(AppConstants.sp20(context));
        final query = search.text.trim().toLowerCase();
        final traders = [
          for (final trader in state.traders)
            if (query.isEmpty || trader.name.toLowerCase().contains(query)) trader,
        ];

        Widget body;
        if (state.tradersLoading && state.traders.isEmpty) {
          body = ListView(padding: padding, children: const [VanListSkeleton()]);
        } else if (state.traders.isEmpty) {
          body = ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            children: [
              VanEmptyState(
                icon: state.tradersFailure != null ? Icons.wifi_off_rounded : Icons.storefront_outlined,
                title: (state.tradersFailure != null ? "van_traders_load_failed" : "van_no_traders").tr(),
                message: state.tradersFailure?.errMessage,
                onRetry: cubit.loadTraders,
              ),
            ],
          );
        } else {
          body = ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            children: [
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "van_search_trader".tr(),
                  hintStyle: Styles.font14MediumGrey46(context),
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(vertical: AppConstants.height10(context)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.sp15(context)),
                    borderSide: const BorderSide(color: Color(0xffEDEFF2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.sp15(context)),
                    borderSide: const BorderSide(color: Color(0xffEDEFF2)),
                  ),
                ),
              ),
              SizedBox(height: AppConstants.height15(context)),
              for (final trader in traders) ...[
                _VanTraderItem(trader: trader),
                SizedBox(height: AppConstants.height10(context)),
              ],
            ],
          );
        }

        return RefreshIndicator(
          color: AppColors.primarySwatchColor,
          onRefresh: () async {
            await cubit.loadTrip(silent: true);
            await cubit.loadTraders(silent: true);
          },
          child: body,
        );
      },
    );
  }
}

class _VanTraderItem extends StatelessWidget {
  const _VanTraderItem({required this.trader});

  final VanTrader trader;

  void _open(BuildContext context, {VanOpenOrder? order}) {
    NavigationUtils.navigateTo(
      context: context,
      destinationScreen: VanDeliveryFormView(trader: trader, order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = MediaQuery.of(context).size.height * .022;

    return SheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_rounded, size: iconSize, color: AppColors.primarySwatchColor),
              SizedBox(width: AppConstants.width10(context)),
              Expanded(child: Text(trader.name, style: Styles.font14BoldBlack(context))),
            ],
          ),
          if (trader.defaultBranch != null) ...[
            SizedBox(height: AppConstants.height5(context) * .6),
            Text(trader.defaultBranch!.name, style: Styles.font11MediumGrey46(context)),
          ],
          for (final order in trader.openOrders) ...[
            SizedBox(height: AppConstants.height10(context)),
            InkWell(
              onTap: () => _open(context, order: order),
              borderRadius: BorderRadius.circular(AppConstants.sp10(context)),
              child: Container(
                padding: EdgeInsets.all(AppConstants.sp10(context)),
                decoration: BoxDecoration(
                  color: const Color(0xffF9FAFB),
                  borderRadius: BorderRadius.circular(AppConstants.sp10(context)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, size: iconSize, color: AppColors.secondaryColor),
                    SizedBox(width: AppConstants.width10(context)),
                    Expanded(
                      child: Text(
                        order.code,
                        textAlign: TextAlign.start,
                        style: VanFormat.tabular(Styles.font12BoldBlack(context)),
                      ),
                    ),
                    Text(
                      "van_fill_order".tr(),
                      style: Styles.font12BoldBlack(context).copyWith(color: AppColors.primarySwatchColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
          SizedBox(height: AppConstants.height10(context)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              onPressed: trader.branches.isEmpty ? null : () => _open(context),
              icon: Icon(Icons.add_shopping_cart_rounded, size: iconSize),
              label: Text("van_spot_order".tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primarySwatchColor,
                side: BorderSide(color: AppColors.primarySwatchColor.withValues(alpha: .35)),
                textStyle: Styles.font12BoldBlack(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.sp15(context))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
