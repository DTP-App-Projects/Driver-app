import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_sale_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/view_models/van_trip/van_trip_cubit.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/van_sale_receipt_view.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_widgets.dart';

/// The trip's walk-in sales, newest first; sales still waiting in the offline
/// queue on top.
class VanSalesTab extends StatefulWidget {
  const VanSalesTab({super.key});

  @override
  State<VanSalesTab> createState() => _VanSalesTabState();
}

class _VanSalesTabState extends State<VanSalesTab> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<VanTripCubit>();
    cubit.loadSales(silent: cubit.state.salesLoaded);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VanTripCubit, VanTripState>(
      builder: (context, state) {
        final cubit = context.read<VanTripCubit>();
        final padding = EdgeInsets.all(AppConstants.sp20(context));

        Widget body;
        if (state.salesLoading && state.sales.isEmpty) {
          body = ListView(padding: padding, children: const [VanListSkeleton()]);
        } else if (state.sales.isEmpty && state.pendingSales.isEmpty) {
          body = ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            children: [
              VanEmptyState(
                icon: state.salesFailure != null ? Icons.wifi_off_rounded : Icons.receipt_long_outlined,
                title: (state.salesFailure != null ? "van_sales_load_failed" : "van_no_sales").tr(),
                message: state.salesFailure?.errMessage,
                onRetry: state.salesFailure != null ? cubit.loadSales : null,
              ),
            ],
          );
        } else {
          body = ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            children: [
              for (final pending in state.pendingSales) ...[
                _VanPendingSaleItem(request: pending),
                SizedBox(height: AppConstants.height10(context)),
              ],
              for (final sale in state.sales) ...[
                _VanSaleItem(sale: sale),
                SizedBox(height: AppConstants.height10(context)),
              ],
            ],
          );
        }

        return RefreshIndicator(
          color: AppColors.primarySwatchColor,
          onRefresh: () async {
            await cubit.loadTrip(silent: true);
            await cubit.loadSales(silent: true);
          },
          child: body,
        );
      },
    );
  }
}

class _VanSaleItem extends StatelessWidget {
  const _VanSaleItem({required this.sale});

  final VanSaleModel sale;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
      onTap: () => NavigationUtils.navigateTo(
        context: context,
        destinationScreen: VanSaleReceiptView(sale: sale),
      ),
      child: SheetCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sale.buyerName, style: Styles.font14MediumBlack(context)),
                  SizedBox(height: AppConstants.height5(context) * .6),
                  Text(
                    [
                      if (sale.invoice != null) sale.invoice!.invoiceNo,
                      sale.paymentMethod.titleKey.tr(),
                      if (sale.createdAt != null)
                        DateFormat("d MMM • h:mm a", context.locale.languageCode).format(sale.createdAt!.toLocal()),
                    ].join(" · "),
                    style: VanFormat.tabular(Styles.font11MediumGrey46(context)),
                  ),
                ],
              ),
            ),
            Text(VanFormat.money(context, sale.grandTotal), style: VanFormat.tabular(Styles.font14BoldBlack(context))),
            SizedBox(width: AppConstants.width5(context)),
            Icon(
              Icons.share_rounded,
              size: MediaQuery.of(context).size.height * .02,
              color: AppColors.primarySwatchColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _VanPendingSaleItem extends StatelessWidget {
  const _VanPendingSaleItem({required this.request});

  final VanSaleRequest request;

  @override
  Widget build(BuildContext context) {
    return SheetCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.buyerName, style: Styles.font14MediumBlack(context)),
                SizedBox(height: AppConstants.height5(context) * .6),
                StatusPill(
                  text: "van_sale_pending_sync".tr(),
                  color: const Color(0xffE8A317),
                  icon: Icons.cloud_upload_outlined,
                ),
              ],
            ),
          ),
          Text(
            VanFormat.money(context, request.estimatedSubtotal),
            style: VanFormat.tabular(Styles.font14MediumGrey46(context)),
          ),
        ],
      ),
    );
  }
}
