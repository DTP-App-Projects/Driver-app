import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_trip_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/view_models/van_trip/van_trip_cubit.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_deliver_tab.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_load_section.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_return_code_section.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_sales_tab.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_sell_tab.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_stock_tab.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_widgets.dart';

/// Home of the van trip: header (code, status, cash to hand over) and, by
/// status, the load confirmation, the on-road tabs (Stock · Sell · Deliver ·
/// Sales) or the return code.
class VanTripView extends StatefulWidget {
  const VanTripView({super.key});

  @override
  State<VanTripView> createState() => _VanTripViewState();
}

class _VanTripViewState extends State<VanTripView> {
  @override
  void initState() {
    super.initState();
    context.read<VanTripCubit>().loadTrip(silent: context.read<VanTripCubit>().state.hasTrip);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, _) {
        return BlocConsumer<VanTripCubit, VanTripState>(
          listenWhen: (previous, current) => current.message != null && current.message != previous.message,
          listener: (context, state) =>
              toast(context: context, text: state.message!.text, isSuccess: !state.message!.isError),
          builder: (context, state) {
            return Scaffold(
              backgroundColor: const Color(0xffF5F7FA),
              body: SafeArea(
                child: Column(
                  children: [
                    CustomAppBar(title: "van_trip".tr()),
                    Expanded(child: _buildBody(context, state)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, VanTripState state) {
    final trip = state.trip;
    final padding = EdgeInsets.symmetric(horizontal: AppConstants.width20(context));

    if (trip == null) {
      if (!state.hasLoaded || state.isLoading) {
        return ListView(padding: padding, children: const [VanListSkeleton(count: 5)]);
      }
      return ListView(
        padding: padding,
        children: [
          VanEmptyState(
            icon: state.failure != null ? Icons.wifi_off_rounded : Icons.local_shipping_outlined,
            title: (state.failure != null ? "van_load_failed" : "van_no_trip").tr(),
            message: state.failure?.errMessage ?? "van_no_trip_hint".tr(),
            onRetry: () => context.read<VanTripCubit>().loadTrip(),
          ),
        ],
      );
    }

    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        AppConstants.width20(context),
        AppConstants.height10(context),
        AppConstants.width20(context),
        0,
      ),
      child: VanTripHeader(trip: trip),
    );

    return switch (trip.status) {
      VanTripStatus.draft => VanLoadSection(trip: trip, header: header),
      VanTripStatus.returning => VanReturnCodeSection(trip: trip, header: header),
      VanTripStatus.onRoad => _buildOnRoad(context, trip, header),
    };
  }

  Widget _buildOnRoad(BuildContext context, VanTripModel trip, Widget header) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          header,
          SizedBox(height: AppConstants.height10(context)),
          TabBar(
            isScrollable: false,
            labelColor: AppColors.primarySwatchColor,
            unselectedLabelColor: AppColors.grey46,
            indicatorColor: AppColors.primarySwatchColor,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: Styles.font14BoldBlack(context),
            unselectedLabelStyle: Styles.font14MediumBlack(context),
            labelPadding: EdgeInsets.zero,
            tabs: [
              Tab(text: "van_tab_stock".tr()),
              Tab(text: "van_tab_sell".tr()),
              Tab(text: "van_tab_deliver".tr()),
              Tab(text: "van_tab_sales".tr()),
            ],
          ),
          const Divider(height: 1, color: Color(0xffEDEFF2)),
          const Expanded(child: TabBarView(children: [VanStockTab(), VanSellTab(), VanDeliverTab(), VanSalesTab()])),
        ],
      ),
    );
  }
}

/// Gradient card on top of the trip screen.
class VanTripHeader extends StatelessWidget {
  const VanTripHeader({super.key, required this.trip});

  final VanTripModel trip;

  @override
  Widget build(BuildContext context) {
    final light = Styles.font12MediumBlack(context).copyWith(color: Colors.white.withValues(alpha: .85));
    final details = [
      if (trip.supplierName.isNotEmpty) trip.supplierName,
      if (trip.warehouseName.isNotEmpty) trip.warehouseName,
      if (trip.plateNumber != null) "${"plate".tr()}: ${trip.plateNumber}",
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppConstants.sp15(context)),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.code,
                  textDirection: TextDirection.ltr,
                  style: VanFormat.tabular(Styles.font18SemiBoldBlack(context).copyWith(color: Colors.white)),
                ),
                for (final line in details) ...[
                  SizedBox(height: AppConstants.height5(context) * .6),
                  Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: light),
                ],
                SizedBox(height: AppConstants.height10(context)),
                VanStatusChip(status: trip.status, onDark: true),
              ],
            ),
          ),
          SizedBox(width: AppConstants.width10(context)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("van_cash_total".tr(), style: light),
              SizedBox(height: AppConstants.height5(context) * .6),
              Text(
                VanFormat.money(context, trip.cashSalesTotal),
                style: VanFormat.tabular(Styles.font18SemiBoldBlack(context).copyWith(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
