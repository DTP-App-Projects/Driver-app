import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/location_service.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/offline_queue.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/driver_profile/driver_profile_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/delivery_tracking/delivery_tracking_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/today_route/today_route_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/delivery_cards.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/delivery_format.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/delivery_map.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/delivery_progress_card.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/delivery_sheet.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/pickup_sheet.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/return_sheet.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/route_alert_banner.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/route_stop_item.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/skip_stop_sheet.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_actions_sheet.dart';

/// Live view of a delivery in progress: the driver position on the route map,
/// how far the route got, and the stop actions, which can be taken straight
/// from a marker so orders are delivered without leaving the map.
class DeliveryTrackingView extends StatelessWidget {
  const DeliveryTrackingView({super.key, required this.route});

  final RouteModel route;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DeliveryTrackingCubit(
        route: route,
        routesRepo: getIt.get<RoutesRepoImpl>(),
        todayRouteCubit: context.read<TodayRouteCubit>(),
        offlineQueue: getIt.get<OfflineQueue>(),
        driverName: context.read<DriverProfileCubit>().driver?.displayName,
      )..startTracking(),
      child: _DeliveryTrackingBody(route: route),
    );
  }
}

class _DeliveryTrackingBody extends StatefulWidget {
  const _DeliveryTrackingBody({required this.route});

  final RouteModel route;

  @override
  State<_DeliveryTrackingBody> createState() => _DeliveryTrackingBodyState();
}

class _DeliveryTrackingBodyState extends State<_DeliveryTrackingBody> {
  /// Keeps the one platform map alive when it moves between the card and the
  /// full screen layout, so expanding does not reload the tiles.
  final GlobalKey mapKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeliveryTrackingCubit>()..languageCode = context.locale.languageCode;

    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return BlocConsumer<DeliveryTrackingCubit, DeliveryTrackingState>(
          listenWhen: (previous, current) => current.message != null && current.message != previous.message,
          listener: (context, state) =>
              toast(context: context, text: state.message!.text, isSuccess: !state.message!.isError),
          builder: (context, state) {
            // Back closes the full screen map first, the screen second.
            return PopScope(
              canPop: !state.isMapExpanded,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop && state.isMapExpanded) cubit.setMapExpanded(false);
              },
              child: state.isMapExpanded ? _buildFullScreenMap(context, state) : _buildTrackingLayout(context, state),
            );
          },
        );
      },
    );
  }

  Widget _buildTrackingLayout(BuildContext context, DeliveryTrackingState state) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(title: "delivery_tracking".tr()),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppConstants.width20(context),
                  AppConstants.height10(context),
                  AppConstants.width20(context),
                  AppConstants.height30(context),
                ),
                children: [
                  _buildAlert(context, state),
                  DeliveryProgressCard(
                    routeCode: state.route.code,
                    stopsDone: state.stopsDone,
                    stopsTotal: state.stops.length,
                    progress: state.progress,
                  ),
                  if (state.pendingSyncStopIds.isNotEmpty) ...[
                    SizedBox(height: AppConstants.height10(context)),
                    _buildPendingSyncBanner(context, state),
                  ],
                  SizedBox(height: AppConstants.height20(context)),
                  _buildMapCard(context),
                  if (state.locationFailure != null) ...[
                    SizedBox(height: AppConstants.height10(context)),
                    LocationPermissionBanner(
                      hintKey: _locationHintKey(state.locationFailure!),
                      onEnable: context.read<DeliveryTrackingCubit>().resolveLocationFailure,
                    ),
                  ],
                  SizedBox(height: AppConstants.height20(context)),
                  if (state.isRouteCanceled)
                    const RouteCanceledCard()
                  else if (state.isFinished)
                    DeliveryFinishedCard(isRouteCompleted: state.isRouteCompleted, summary: state.summary)
                  else
                    _buildCurrentStopCard(context, state),
                  SizedBox(height: AppConstants.height24(context)),
                  Text("stops".tr(), style: Styles.font16SemiBoldBlack(context)),
                  SizedBox(height: AppConstants.height15(context)),
                  ..._buildStops(context, state),
                ],
              ),
            ),
            if (state.isFinished || state.isRouteCanceled) _buildFinishBar(context, state),
          ],
        ),
      ),
    );
  }

  /// The map on its own, with the stop actions kept within thumb reach.
  Widget _buildFullScreenMap(BuildContext context, DeliveryTrackingState state) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap(context)),
          PositionedDirectional(
            top: MediaQuery.of(context).padding.top + AppConstants.height10(context),
            start: AppConstants.width10(context),
            child: _buildBackButton(context),
          ),
          PositionedDirectional(
            bottom: MediaQuery.of(context).padding.bottom + AppConstants.height15(context),
            start: AppConstants.width20(context),
            end: AppConstants.width20(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAlert(context, state),
                if (state.isFinished || state.isRouteCanceled)
                  _buildFinishButton(context, state)
                else
                  _buildCurrentStopCard(context, state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Supplier cancellation pushed for this route, until the driver dismisses
  /// it. Lives in the shared cubit so the details screen shows it too.
  Widget _buildAlert(BuildContext context, DeliveryTrackingState state) {
    return BlocBuilder<TodayRouteCubit, TodayRouteState>(
      buildWhen: (previous, current) => previous.alert != current.alert,
      builder: (context, todayState) {
        final alert = todayState.alertFor(state.route.id);
        if (alert == null) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(bottom: AppConstants.height15(context)),
          child: RouteAlertBanner(alert: alert),
        );
      },
    );
  }

  Widget _buildMapCard(BuildContext context) {
    final radius = BorderRadius.circular(AppConstants.sp20(context));

    return Container(
      height: MediaQuery.of(context).size.height * .32,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: const Color(0xffEDEFF2)),
      ),
      child: ClipRRect(borderRadius: radius, child: _buildMap(context)),
    );
  }

  Widget _buildMap(BuildContext context) {
    return DeliveryMap(
      key: mapKey,
      onStopTap: (index) => _openStopSheet(context, index),
      onUnavailableText: "location_unavailable".tr(),
    );
  }

  Widget _buildCurrentStopCard(BuildContext context, DeliveryTrackingState state) {
    final index = state.currentStopIndex!;
    final stop = state.stops[index];
    final distance = state.distanceTo(stop);

    return CurrentStopCard(
      stop: stop,
      isBusy: state.isBusy(stop.id),
      isPendingSync: state.isPendingSync(stop.id),
      summary:
          DeliveryFormat.leg(context, state.activeLeg) ??
          (distance == null ? null : DeliveryFormat.distanceAway(context, distance)),
      onAction: () => _advanceStop(context, stop),
    );
  }

  List<Widget> _buildStops(BuildContext context, DeliveryTrackingState state) {
    return [
      for (int i = 0; i < state.stops.length; i++) ...[
        if (i != 0) SizedBox(height: AppConstants.height10(context)),
        RouteStopItem(
          stop: state.stops[i],
          order: i + 1,
          onTap: state.isRouteCanceled ? null : () => _openStopSheet(context, i),
        ),
      ],
    ];
  }

  /// Offline actions waiting for the network, with a manual retry.
  Widget _buildPendingSyncBanner(BuildContext context, DeliveryTrackingState state) {
    const warning = Color(0xffE8A317);

    return Container(
      padding: EdgeInsets.all(AppConstants.sp15(context)),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppConstants.sp15(context)),
        border: Border.all(color: warning.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_upload_outlined, size: MediaQuery.of(context).size.height * .022, color: warning),
          SizedBox(width: AppConstants.width10(context)),
          Expanded(
            child: Text(
              "pending_sync_count".tr(namedArgs: {"count": state.pendingSyncStopIds.length.toString()}),
              style: Styles.font11MediumGrey46(context),
            ),
          ),
          TextButton(
            onPressed: context.read<DeliveryTrackingCubit>().retrySync,
            child: Text(
              "sync_now".tr(),
              style: Styles.font11BoldBlack(context).copyWith(color: AppColors.primarySwatchColor),
            ),
          ),
        ],
      ),
    );
  }

  void _openStopSheet(BuildContext context, int index) {
    final cubit = context.read<DeliveryTrackingCubit>();
    if (cubit.state.isRouteCanceled || index >= cubit.state.stops.length) return;
    final stopId = cubit.state.stops[index].id;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sp20(context))),
      ),
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<DeliveryTrackingCubit, DeliveryTrackingState>(
          builder: (context, state) {
            final stop = state.stopById(stopId);
            // The supplier took the stop off the route while the sheet was open.
            if (stop == null || state.isRouteCanceled) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              });
              return const SizedBox.shrink();
            }
            return StopActionsSheet(
              stop: stop,
              order: index + 1,
              distanceMeters: state.distanceTo(stop),
              isBusy: state.isBusy(stop.id),
              isPendingSync: state.isPendingSync(stop.id),
              receiptStatus: state.receiptStatuses[stop.id],
              onEnRoute: () {
                Navigator.pop(sheetContext);
                cubit.markEnRoute(stop);
              },
              onArrive: () {
                Navigator.pop(sheetContext);
                _arrive(cubit, stop);
              },
              onConfirm: () {
                Navigator.pop(sheetContext);
                _openConfirmSheet(cubit, stop);
              },
              onSkip: () {
                Navigator.pop(sheetContext);
                _skip(cubit, stop);
              },
              onCheckReceipt: () => cubit.loadReceiptStatus(stop.id),
              onRetrySync: cubit.retrySync,
              onShowOnMap: () {
                Navigator.pop(sheetContext);
                cubit.focusStop(stop);
              },
            );
          },
        ),
      ),
    );
  }

  /// One tap on the current stop card does whatever the server accepts next.
  void _advanceStop(BuildContext context, RouteStop stop) {
    final cubit = context.read<DeliveryTrackingCubit>();

    switch (stop.status) {
      case StopStatus.pending:
        cubit.markEnRoute(stop);
      case StopStatus.enRoute:
        _arrive(cubit, stop);
      case StopStatus.arrived:
        _openConfirmSheet(cubit, stop);
      case _:
        break;
    }
  }

  /// Arriving at a delivery stop dispatches the receiver OTP; the sheet opens
  /// right away so the driver sees where the code went.
  Future<void> _arrive(DeliveryTrackingCubit cubit, RouteStop stop) async {
    final arrived = await cubit.arrive(stop);
    if (!arrived || !mounted) return;
    final fresh = cubit.state.stopById(stop.id);
    if (fresh != null && fresh.status == StopStatus.arrived) _openConfirmSheet(cubit, fresh);
  }

  Future<void> _openConfirmSheet(DeliveryTrackingCubit cubit, RouteStop stop) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sp20(context))),
      ),
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: stop.isReturn
            ? ReturnSheet(stopId: stop.id)
            : stop.isPickup
            ? PickupSheet(stopId: stop.id)
            : DeliverySheet(stopId: stop.id),
      ),
    );

    if (confirmed == true && mounted) {
      toast(
        context: context,
        text: "stop_completed".tr(namedArgs: {"stop": stop.name}),
      );
    }
  }

  Future<void> _skip(DeliveryTrackingCubit cubit, RouteStop stop) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sp20(context))),
      ),
      builder: (sheetContext) => SkipStopSheet(stopName: stop.name),
    );
    if (reason == null || !mounted) return;
    cubit.skip(stop, reason: reason);
  }

  Widget _buildBackButton(BuildContext context) {
    final size = MediaQuery.of(context).size.height * .045;

    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.read<DeliveryTrackingCubit>().setMapExpanded(false),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.arrow_back_rounded, size: size * .5, color: AppColors.primarySwatchColor),
        ),
      ),
    );
  }

  Widget _buildFinishBar(BuildContext context, DeliveryTrackingState state) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.width20(context),
        vertical: AppConstants.height15(context),
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xffEDEFF2))),
      ),
      child: _buildFinishButton(context, state),
    );
  }

  /// `POST /routes/{id}/complete` once every stop is closed; afterwards the
  /// button just leaves the screen.
  Widget _buildFinishButton(BuildContext context, DeliveryTrackingState state) {
    final cubit = context.read<DeliveryTrackingCubit>();

    if (state.isRouteCompleted || state.isRouteCanceled) {
      return DefaultButton(
        text: "back_to_home".tr(),
        backgroundColor: AppColors.secondaryColor,
        borderRadius: AppConstants.sp15(context),
        onPress: () => NavigationUtils.navigateBack(context: context),
      );
    }

    return DefaultButton(
      text: "finish_delivery".tr(),
      backgroundColor: AppColors.secondaryColor,
      borderRadius: AppConstants.sp15(context),
      isEnabled: !state.isCompletingRoute && state.pendingSyncStopIds.isEmpty,
      onPress: cubit.completeRoute,
    );
  }

  String _locationHintKey(LocationFailure failure) => switch (failure) {
    LocationFailure.serviceDisabled => "location_service_off_hint",
    LocationFailure.denied => "location_denied_hint",
    LocationFailure.deniedForever => "location_denied_forever_hint",
  };
}
