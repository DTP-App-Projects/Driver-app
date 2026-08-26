import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/delivery_tracking/delivery_tracking_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/delivery_format.dart';

/// The delivery map: the stops, the road path through them and the driver blue
/// dot, with the controls that frame them. Tapping a marker hands the stop
/// back to the caller, which opens its actions.
class DeliveryMap extends StatefulWidget {
  const DeliveryMap({super.key, required this.onStopTap, required this.onUnavailableText});

  final ValueChanged<int> onStopTap;

  /// Already translated toast for a centre request without a fix yet.
  final String onUnavailableText;

  @override
  State<DeliveryMap> createState() => _DeliveryMapState();
}

class _DeliveryMapState extends State<DeliveryMap> {
  GoogleMapController? mapController;
  int handledCameraToken = 0;

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeliveryTrackingCubit>();

    return BlocConsumer<DeliveryTrackingCubit, DeliveryTrackingState>(
      listenWhen: (previous, current) => current.camera != null && current.camera!.token != handledCameraToken,
      listener: (context, state) => _runCameraCommand(state),
      builder: (context, state) {
        final focus = state.stops[state.currentStopIndex ?? 0];
        // Full screen puts the controls below the status bar and back button.
        final topInset = state.isMapExpanded
            ? MediaQuery.of(context).padding.top + AppConstants.height10(context)
            : AppConstants.height10(context);

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: LatLng(focus.latitude, focus.longitude), zoom: 12),
              markers: _buildMarkers(state),
              polylines: _buildPolylines(state),
              myLocationEnabled: state.locationFailure == null,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              onMapCreated: (controller) {
                mapController = controller;
                if (state.driverPosition == null) _fitRoute(state);
              },
            ),
            PositionedDirectional(
              top: topInset,
              end: AppConstants.width10(context),
              child: Column(
                children: [
                  _buildButton(
                    context,
                    icon: state.isMapExpanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    onTap: () => cubit.setMapExpanded(!state.isMapExpanded),
                  ),
                  SizedBox(height: AppConstants.height5(context)),
                  _buildButton(context, icon: Icons.zoom_out_map_rounded, onTap: cubit.fitRoute),
                  SizedBox(height: AppConstants.height5(context)),
                  _buildButton(
                    context,
                    icon: state.followDriver ? Icons.my_location_rounded : Icons.location_searching_rounded,
                    isActive: state.followDriver,
                    onTap: () => cubit.centerOnDriver(unavailableText: widget.onUnavailableText),
                  ),
                ],
              ),
            ),
            // In full screen the stop card owns the bottom, so the hint moves up.
            PositionedDirectional(
              top: state.isMapExpanded ? topInset : null,
              bottom: state.isMapExpanded ? null : AppConstants.height10(context),
              start: state.isMapExpanded ? AppConstants.width50(context) * 1.4 : AppConstants.width10(context),
              child: _buildHint(context, state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final size = MediaQuery.of(context).size.height * .045;

    return Material(
      color: isActive ? AppColors.primarySwatchColor : Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * .5, color: isActive ? Colors.white : AppColors.primarySwatchColor),
        ),
      ),
    );
  }

  /// Live drive time to the stop being worked on, or a nudge that the markers
  /// are actionable while there is no road path yet.
  Widget _buildHint(BuildContext context, DeliveryTrackingState state) {
    final stop = state.currentStop;
    final distance = stop == null ? null : state.distanceTo(stop);
    final leg = DeliveryFormat.leg(context, state.activeLeg);
    final text =
        leg ??
        (state.directionsFailed
            ? "road_route_unavailable".tr()
            : distance == null
            ? "tap_stop_hint".tr()
            : DeliveryFormat.distanceAway(context, distance));

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.width10(context),
        vertical: AppConstants.height5(context) * .8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(AppConstants.sp30(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            leg != null
                ? Icons.directions_car_rounded
                : state.directionsFailed
                ? Icons.info_outline_rounded
                : distance == null
                ? Icons.touch_app_outlined
                : Icons.near_me_rounded,
            size: MediaQuery.of(context).size.height * .016,
            color: AppColors.primarySwatchColor,
          ),
          SizedBox(width: AppConstants.width5(context) * .6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .55),
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: Styles.font10MediumBlack(context)),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers(DeliveryTrackingState state) {
    final current = state.currentStopIndex;

    return {
      for (int i = 0; i < state.stops.length; i++)
        Marker(
          markerId: MarkerId("stop_$i"),
          position: LatLng(state.stops[i].latitude, state.stops[i].longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(_markerHue(state.stops[i].status)),
          infoWindow: InfoWindow(
            title: "${i + 1}. ${state.stops[i].name}",
            snippet: "${state.stops[i].type.titleKey.tr()} • ${state.stops[i].status.titleKey.tr()}",
            onTap: () => widget.onStopTap(i),
          ),
          onTap: () => widget.onStopTap(i),
          // The stop being worked on stays on top of the ones around it.
          zIndexInt: i == current ? 1 : 0,
        ),
    };
  }

  double _markerHue(StopStatus status) => switch (status) {
    StopStatus.pending => BitmapDescriptor.hueAzure,
    StopStatus.arrived => BitmapDescriptor.hueOrange,
    StopStatus.completed => BitmapDescriptor.hueGreen,
  };

  /// One line per hop, drawn on the roads: the leg the driver is on now is
  /// solid, the hops after it are dashed so the order stays readable.
  Set<Polyline> _buildPolylines(DeliveryTrackingState state) {
    final legs = state.directions?.legs;

    if (legs != null && legs.isNotEmpty) {
      return {
        for (int i = 0; i < legs.length; i++)
          Polyline(
            polylineId: PolylineId("leg_$i"),
            points: legs[i].points,
            color: i == 0 ? AppColors.red : AppColors.red.withValues(alpha: .45),
            width: i == 0 ? 6 : 4,
            patterns: i == 0 ? const [] : [PatternItem.dash(20), PatternItem.gap(12)],
          ),
      };
    }

    // No road path yet (no fix, or the Routes request failed): fall back to
    // straight hops so the order of the stops is still visible.
    final position = state.driverPosition;
    final points = [
      if (position != null) LatLng(position.latitude, position.longitude),
      for (final stop in state.remainingStops) LatLng(stop.latitude, stop.longitude),
    ];

    if (points.length < 2) return const {};

    return {
      Polyline(
        polylineId: const PolylineId("route_fallback"),
        points: points,
        color: AppColors.red.withValues(alpha: .55),
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(12)],
      ),
    };
  }

  void _runCameraCommand(DeliveryTrackingState state) {
    final command = state.camera!;
    handledCameraToken = command.token;

    if (command.fitRoute) {
      _fitRoute(state);
      return;
    }

    final target = command.target;
    if (target != null) mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, command.zoom));
  }

  /// Zooms out until the whole route, and the driver with it, fits on screen.
  void _fitRoute(DeliveryTrackingState state) {
    final controller = mapController;
    if (controller == null || state.stops.isEmpty) return;

    final position = state.driverPosition;
    final latitudes = [
      for (final stop in state.stops) stop.latitude,
      if (position != null) position.latitude,
    ];
    final longitudes = [
      for (final stop in state.stops) stop.longitude,
      if (position != null) position.longitude,
    ];

    if (latitudes.length == 1) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(latitudes.first, longitudes.first), 14));
      return;
    }

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(latitudes.reduce(min), longitudes.reduce(min)),
          northeast: LatLng(latitudes.reduce(max), longitudes.reduce(max)),
        ),
        50,
      ),
    );
  }
}
