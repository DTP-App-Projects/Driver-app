import 'dart:math';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/endpoints.dart';
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

class _DeliveryMapState extends State<DeliveryMap> with SingleTickerProviderStateMixin {
  final mapController = MapController();
  late final cameraAnimation = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
    ..addListener(_stepCamera);
  late final cameraCurve = CurvedAnimation(parent: cameraAnimation, curve: Curves.easeInOutCubic);
  bool isMapReady = false;
  int handledCameraToken = 0;

  /// Start and end of the camera glide in flight.
  Tween<double> latitudeTween = Tween(), longitudeTween = Tween(), zoomTween = Tween();

  @override
  void dispose() {
    cameraCurve.dispose();
    cameraAnimation.dispose();
    mapController.dispose();
    super.dispose();
  }

  /// Glides the camera from where it is to [target] at [zoom]. A new move
  /// takes over from one still running.
  void _animateTo(LatLng target, double zoom) {
    final camera = mapController.camera;
    latitudeTween = Tween(begin: camera.center.latitude, end: target.latitude);
    longitudeTween = Tween(begin: camera.center.longitude, end: target.longitude);
    zoomTween = Tween(begin: camera.zoom, end: zoom);
    cameraAnimation.forward(from: 0);
  }

  void _stepCamera() => mapController.move(
    LatLng(latitudeTween.evaluate(cameraCurve), longitudeTween.evaluate(cameraCurve)),
    zoomTween.evaluate(cameraCurve),
  );

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeliveryTrackingCubit>();

    return BlocConsumer<DeliveryTrackingCubit, DeliveryTrackingState>(
      listenWhen: (previous, current) => current.camera != null && current.camera!.token != handledCameraToken,
      listener: (context, state) => _runCameraCommand(state),
      builder: (context, state) {
        // Full screen puts the controls below the status bar and back button.
        final topInset = state.isMapExpanded
            ? MediaQuery.of(context).padding.top + AppConstants.height10(context)
            : AppConstants.height10(context);

        return Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: _initialTarget(state),
                initialZoom: 12,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                // A drag or pinch wins over a glide still running.
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture) cameraAnimation.stop();
                },
                onMapReady: () {
                  isMapReady = true;
                  if (state.driverPosition == null) _fitRoute(state);
                },
              ),
              children: [
                TileLayer(urlTemplate: EndPoints.osmTileUrl, userAgentPackageName: EndPoints.osmUserAgent),
                PolylineLayer(polylines: _buildPolylines(state)),
                MarkerLayer(markers: [..._buildMarkers(state), ?_buildDriverMarker(state)]),
                // The hint sits on the start side, so the attribution takes the end.
                RichAttributionWidget(
                  alignment: Directionality.of(context) == TextDirection.rtl
                      ? AttributionAlignment.bottomLeft
                      : AttributionAlignment.bottomRight,
                  attributions: [
                    TextSourceAttribution(
                      "OpenStreetMap contributors",
                      onTap: () => launchUrl(Uri.parse("https://openstreetmap.org/copyright")),
                    ),
                  ],
                ),
              ],
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

  /// Where the map opens: the stop being worked on, else the first stop with
  /// coordinates, else the driver, else a neutral default.
  LatLng _initialTarget(DeliveryTrackingState state) {
    final current = state.currentStop;
    if (current != null && current.hasLocation) return LatLng(current.latitude!, current.longitude!);
    for (final stop in state.stops) {
      if (stop.hasLocation) return LatLng(stop.latitude!, stop.longitude!);
    }
    final position = state.driverPosition;
    if (position != null) return LatLng(position.latitude, position.longitude);
    return const LatLng(24.7136, 46.6753);
  }

  /// The driver blue dot, hidden without a fix or location access.
  Marker? _buildDriverMarker(DeliveryTrackingState state) {
    final position = state.driverPosition;
    if (position == null || state.locationFailure != null) return null;

    return Marker(
      point: LatLng(position.latitude, position.longitude),
      width: 22,
      height: 22,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
      ),
    );
  }

  /// Stops without coordinates cannot be placed, so they get no marker.
  List<Marker> _buildMarkers(DeliveryTrackingState state) {
    final current = state.currentStopIndex;
    final size = MediaQuery.of(context).size.height * .05;

    return [
      for (int i = 0; i < state.stops.length; i++)
        if (state.stops[i].hasLocation && i != current) _buildStopMarker(state, i, size),
      // Painted last so the stop being worked on stays on top of the ones around it.
      if (current != null && state.stops[current].hasLocation) _buildStopMarker(state, current, size),
    ];
  }

  Marker _buildStopMarker(DeliveryTrackingState state, int index, double size) {
    final stop = state.stops[index];

    return Marker(
      point: LatLng(stop.latitude!, stop.longitude!),
      width: size,
      height: size,
      // The pin tip, not its centre, sits on the stop.
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => widget.onStopTap(index),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Icon(Icons.location_on, size: size, color: _markerColor(stop.status)),
            Padding(
              padding: EdgeInsets.only(top: size * .14),
              child: Text(
                "${index + 1}",
                style: TextStyle(color: Colors.white, fontSize: size * .26, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _markerColor(StopStatus status) => switch (status) {
    StopStatus.pending => Colors.lightBlue,
    StopStatus.enRoute => Colors.blue.shade700,
    StopStatus.arrived => Colors.orange,
    StopStatus.completed => Colors.green,
    StopStatus.skipped => Colors.red,
    StopStatus.canceled => Colors.pink,
  };

  /// One line per hop, drawn on the roads: the leg the driver is on now is
  /// solid, the hops after it are dashed so the order stays readable.
  List<Polyline> _buildPolylines(DeliveryTrackingState state) {
    final legs = state.directions?.legs;

    if (legs != null && legs.isNotEmpty) {
      return [
        // Reversed so the active leg is painted over the dashed ones.
        for (int i = legs.length - 1; i >= 0; i--)
          Polyline(
            points: legs[i].points,
            color: i == 0 ? AppColors.red : AppColors.red.withValues(alpha: .45),
            strokeWidth: i == 0 ? 5 : 4,
            pattern: i == 0 ? const StrokePattern.solid() : StrokePattern.dashed(segments: const [20, 12]),
          ),
      ];
    }

    // No road path yet (no fix, or the routing request failed): fall back to
    // straight hops so the order of the stops is still visible.
    final position = state.driverPosition;
    final points = [
      if (position != null) LatLng(position.latitude, position.longitude),
      for (final stop in state.remainingStops) LatLng(stop.latitude!, stop.longitude!),
    ];

    if (points.length < 2) return const [];

    return [
      Polyline(
        points: points,
        color: AppColors.red.withValues(alpha: .55),
        strokeWidth: 4,
        pattern: StrokePattern.dashed(segments: const [20, 12]),
      ),
    ];
  }

  void _runCameraCommand(DeliveryTrackingState state) {
    final command = state.camera!;
    handledCameraToken = command.token;

    if (command.fitRoute) {
      _fitRoute(state);
      return;
    }

    final target = command.target;
    if (target != null && isMapReady) _animateTo(target, command.zoom);
  }

  /// Zooms out until the whole route, and the driver with it, fits on screen.
  void _fitRoute(DeliveryTrackingState state) {
    if (!isMapReady) return;

    final position = state.driverPosition;
    final latitudes = <double>[
      for (final stop in state.stops)
        if (stop.hasLocation) stop.latitude!,
      if (position != null) position.latitude,
    ];
    final longitudes = <double>[
      for (final stop in state.stops)
        if (stop.hasLocation) stop.longitude!,
      if (position != null) position.longitude,
    ];

    if (latitudes.isEmpty) return;
    if (latitudes.length == 1) {
      _animateTo(LatLng(latitudes.first, longitudes.first), 14);
      return;
    }

    // Work out where the camera has to end up, then glide there.
    final fitted = CameraFit.bounds(
      bounds: LatLngBounds(
        LatLng(latitudes.reduce(min), longitudes.reduce(min)),
        LatLng(latitudes.reduce(max), longitudes.reduce(max)),
      ),
      padding: const EdgeInsets.all(50),
    ).fit(mapController.camera);
    _animateTo(fitted.center, fitted.zoom);
  }
}
