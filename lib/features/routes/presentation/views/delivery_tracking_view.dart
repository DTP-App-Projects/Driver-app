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
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/delivery_tracking/delivery_tracking_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/delivery_cards.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/delivery_format.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/delivery_map.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/delivery_progress_card.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/route_stop_item.dart';
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
      create: (context) => DeliveryTrackingCubit(route: route)..startTracking(),
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

  RouteModel get route => widget.route;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeliveryTrackingCubit>()..languageCode = context.locale.languageCode;

    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return BlocConsumer<DeliveryTrackingCubit, DeliveryTrackingState>(
          listenWhen: (previous, current) => current.message != null && current.message != previous.message,
          listener: (context, state) => toast(
            context: context,
            text: state.message!.text,
            isSuccess: !state.message!.isError,
          ),
          builder: (context, state) {
            // Back closes the full screen map first, the screen second.
            return PopScope(
              canPop: !state.isMapExpanded,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop && state.isMapExpanded) cubit.setMapExpanded(false);
              },
              child: state.isMapExpanded
                  ? _buildFullScreenMap(context, state)
                  : _buildTrackingLayout(context, state),
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
                  DeliveryProgressCard(
                    routeCode: route.code,
                    stopsDone: state.stopsDone,
                    stopsTotal: state.stops.length,
                    progress: state.progress,
                  ),
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
                  if (state.isFinished) const DeliveryFinishedCard() else _buildCurrentStopCard(context, state),
                  SizedBox(height: AppConstants.height24(context)),
                  Text("stops".tr(), style: Styles.font16SemiBoldBlack(context)),
                  SizedBox(height: AppConstants.height15(context)),
                  ..._buildStops(context, state),
                ],
              ),
            ),
            if (state.isFinished) _buildFinishBar(context),
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
            child: state.isFinished ? _buildFinishButton(context) : _buildCurrentStopCard(context, state),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(BuildContext context) {
    final radius = BorderRadius.circular(AppConstants.sp20(context));

    return Container(
      height: MediaQuery.of(context).size.height * .32,
      decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: const Color(0xffEDEFF2))),
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
      summary:
          DeliveryFormat.leg(context, state.activeLeg) ??
          (distance == null ? null : DeliveryFormat.distanceAway(context, distance)),
      onAction: () => _advanceStop(context, index),
    );
  }

  List<Widget> _buildStops(BuildContext context, DeliveryTrackingState state) {
    return [
      for (int i = 0; i < state.stops.length; i++) ...[
        if (i != 0) SizedBox(height: AppConstants.height10(context)),
        RouteStopItem(stop: state.stops[i], order: i + 1, onTap: () => _openStopSheet(context, i)),
      ],
    ];
  }

  void _openStopSheet(BuildContext context, int index) {
    final cubit = context.read<DeliveryTrackingCubit>();
    final stop = cubit.state.stops[index];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sp20(context))),
      ),
      builder: (sheetContext) => StopActionsSheet(
        stop: stop,
        order: index + 1,
        distanceMeters: cubit.state.distanceTo(stop),
        onAdvance: () {
          Navigator.pop(sheetContext);
          _advanceStop(context, index);
        },
        onShowOnMap: () {
          Navigator.pop(sheetContext);
          cubit.focusStop(stop);
        },
      ),
    );
  }

  void _advanceStop(BuildContext context, int index) {
    final cubit = context.read<DeliveryTrackingCubit>();
    final name = cubit.state.stops[index].name;

    cubit.advanceStop(
      index,
      arrivedText: "arrived_at_stop".tr(namedArgs: {"stop": name}),
      completedText: "stop_completed".tr(namedArgs: {"stop": name}),
    );
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

  Widget _buildFinishBar(BuildContext context) {
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
      child: _buildFinishButton(context),
    );
  }

  Widget _buildFinishButton(BuildContext context) {
    return DefaultButton(
      text: "finish_delivery".tr(),
      backgroundColor: AppColors.secondaryColor,
      borderRadius: AppConstants.sp15(context),
      onPress: () {
        toast(context: context, text: "delivery_finished".tr());
        NavigationUtils.navigateBack(context: context);
      },
    );
  }

  String _locationHintKey(LocationFailure failure) => switch (failure) {
    LocationFailure.serviceDisabled => "location_service_off_hint",
    LocationFailure.denied => "location_denied_hint",
    LocationFailure.deniedForever => "location_denied_forever_hint",
  };
}
