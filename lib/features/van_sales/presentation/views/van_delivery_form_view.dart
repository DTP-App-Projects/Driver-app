import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/today_route/today_route_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/delivery_tracking_view.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_delivery_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_trip_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/view_models/van_trip/van_trip_cubit.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_widgets.dart';

/// Creates a van delivery to a registered trader, either filling [order] or
/// as a spot order (cash on delivery), then hands the returned stop to the
/// existing arrive → handoff → deliver flow. There is no pickup step: the
/// goods are already on the van.
class VanDeliveryFormView extends StatefulWidget {
  const VanDeliveryFormView({super.key, required this.trader, this.order});

  final VanTrader trader;
  final VanOpenOrder? order;

  @override
  State<VanDeliveryFormView> createState() => _VanDeliveryFormViewState();
}

/// A line the driver can put quantities on.
class _FormLine {
  const _FormLine({required this.key, required this.skuId, required this.name, required this.max, this.outstanding});

  /// `purchase_order_line_id` for an order, `sku_id` for a spot order.
  final int key;
  final int skuId;
  final String name;
  final int max;
  final double? outstanding;
}

class _VanDeliveryFormViewState extends State<VanDeliveryFormView> {
  final Map<int, int> quantities = {};
  int? branchId;
  String? error;
  bool openingStop = false;

  bool get isOrder => widget.order != null;

  @override
  void initState() {
    super.initState();
    branchId = widget.order?.deliveryBranchId ?? widget.trader.defaultBranch?.id;
    // An order starts filled with what the van can cover.
    final trip = context.read<VanTripCubit>().state.trip;
    if (trip != null && isOrder) {
      for (final line in _lines(trip)) {
        quantities[line.key] = line.max;
      }
    }
  }

  List<_FormLine> _lines(VanTripModel trip) {
    final order = widget.order;
    if (order == null) {
      return [
        for (final line in trip.sellableLines)
          _FormLine(key: line.skuId, skuId: line.skuId, name: line.name, max: line.inVan.floor()),
      ];
    }
    return [
      for (final line in order.lines)
        _FormLine(
          key: line.purchaseOrderLineId,
          skuId: line.skuId,
          name: trip.lineForSku(line.skuId)?.name ?? "#${line.skuId}",
          max: [line.outstandingQty, trip.lineForSku(line.skuId)?.inVan ?? 0].reduce((a, b) => a < b ? a : b).floor(),
          outstanding: line.outstandingQty,
        ),
    ];
  }

  Future<void> submit(VanTripModel trip) async {
    final picked = [
      for (final line in _lines(trip))
        if ((quantities[line.key] ?? 0).clamp(0, line.max) > 0) (line, quantities[line.key]!.clamp(0, line.max)),
    ];
    if (branchId == null) {
      setState(() => error = "van_pick_branch".tr());
      return;
    }
    if (picked.isEmpty) {
      setState(() => error = "van_pick_items".tr());
      return;
    }
    setState(() => error = null);

    final request = VanDeliveryRequest(
      purchaseOrderId: widget.order?.id,
      traderBranchId: branchId!,
      lines: [
        for (final (line, qty) in picked)
          isOrder
              ? VanDeliveryLine.order(purchaseOrderLineId: line.key, qty: qty.toDouble())
              : VanDeliveryLine.spot(skuId: line.skuId, qty: qty.toDouble()),
      ],
    );

    final vanCubit = context.read<VanTripCubit>();
    final result = await vanCubit.createDelivery(request);
    if (!mounted) return;
    await result.fold((failure) async => setState(() => error = failure.errMessage), (created) async {
      toast(context: context, text: "van_delivery_created".tr());
      await _openStop(created, trip);
    });
  }

  /// The stop lives on the trip's delivery route in `today_route`; that route
  /// is opened in the delivery screen, started first when still assigned.
  Future<void> _openStop(VanDeliveryResult created, VanTripModel trip) async {
    final routeId = created.deliveryRouteId ?? trip.deliveryRouteId;
    final vanCubit = context.read<VanTripCubit>();
    final todayCubit = context.read<TodayRouteCubit>();
    final navigator = Navigator.of(context);

    if (routeId == null) {
      navigator.pop();
      return;
    }

    setState(() => openingStop = true);
    await todayCubit.loadTodayRoute(silent: true);
    var route = todayCubit.state.data?.routeById(routeId);
    if (route != null && route.isAssigned) {
      await todayCubit.startRoute(route);
      route = todayCubit.state.data?.routeById(routeId) ?? route;
    }
    if (!mounted) return;
    setState(() => openingStop = false);

    // Not in the payload yet (refresh failed): open the route with the stop
    // we were handed so the driver can still finish it.
    route ??= RouteModel(
      id: routeId,
      code: trip.code,
      date: DateTime.now(),
      status: RouteStatus.inProgress,
      stops: [created.stop],
    );
    if (!route.stops.any((stop) => stop.id == created.stop.id)) {
      route = route.copyWith(stops: [...route.stops, created.stop]);
    }

    navigator
        .pushReplacement(MaterialPageRoute(builder: (_) => DeliveryTrackingView(route: route!)))
        .then((_) => vanCubit.loadTrip(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VanTripCubit, VanTripState>(
      builder: (context, state) {
        final trip = state.trip;
        final bool isBusy = state.isBusy(VanTripAction.delivery) || openingStop;

        return Scaffold(
          backgroundColor: const Color(0xffF5F7FA),
          body: SafeArea(
            child: Column(
              children: [
                CustomAppBar(title: (isOrder ? "van_fill_order" : "van_spot_order").tr()),
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
                            Text(widget.trader.name, style: Styles.font16SemiBoldBlack(context)),
                            if (widget.order != null) ...[
                              SizedBox(height: AppConstants.height5(context) * .6),
                              Text(widget.order!.code, style: VanFormat.tabular(Styles.font12MediumGrey46(context))),
                            ],
                            SizedBox(height: AppConstants.height20(context)),
                            SheetSectionLabel(title: "van_branch".tr()),
                            _buildBranchPicker(context),
                            SizedBox(height: AppConstants.height20(context)),
                            SheetSectionLabel(title: "van_items".tr()),
                            for (final line in _lines(trip)) ...[
                              _buildLine(context, line),
                              SizedBox(height: AppConstants.height10(context)),
                            ],
                            if (!isOrder) ...[
                              SizedBox(height: AppConstants.height5(context)),
                              Text("van_spot_cash_note".tr(), style: Styles.font11MediumGrey46(context)),
                            ],
                            if (error != null) ...[
                              SizedBox(height: AppConstants.height15(context)),
                              SheetErrorBox(message: error!),
                            ],
                            SizedBox(height: AppConstants.height20(context)),
                            DefaultButton(
                              text: "van_create_delivery".tr(),
                              gradient: AppColors.brandGradient,
                              borderRadius: AppConstants.sp15(context),
                              isEnabled: !isBusy,
                              icon: isBusy ? const VanButtonBusy() : null,
                              onPress: () => submit(trip),
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

  Widget _buildBranchPicker(BuildContext context) {
    return SheetCard(
      padding: EdgeInsets.symmetric(horizontal: AppConstants.width10(context)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: branchId,
          isExpanded: true,
          dropdownColor: Colors.white,
          hint: Text("van_pick_branch".tr(), style: Styles.font14MediumGrey46(context)),
          items: [
            for (final branch in widget.trader.branches)
              DropdownMenuItem(
                value: branch.id,
                child: Text(branch.name, style: Styles.font14MediumBlack(context)),
              ),
          ],
          onChanged: (value) => setState(() => branchId = value),
        ),
      ),
    );
  }

  Widget _buildLine(BuildContext context, _FormLine line) {
    final value = (quantities[line.key] ?? 0).clamp(0, line.max);
    final details = [
      if (line.outstanding != null) "${"van_outstanding".tr()} ${VanFormat.qty(context, line.outstanding!)}",
      "${"van_available".tr()} ${VanFormat.qty(context, line.max)}",
    ];

    return SheetCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: Styles.font14MediumBlack(context)),
                SizedBox(height: AppConstants.height5(context) * .6),
                Text(details.join(" · "), style: VanFormat.tabular(Styles.font11MediumGrey46(context))),
              ],
            ),
          ),
          VanQtyStepper(value: value, max: line.max, onChanged: (qty) => setState(() => quantities[line.key] = qty)),
        ],
      ),
    );
  }
}
