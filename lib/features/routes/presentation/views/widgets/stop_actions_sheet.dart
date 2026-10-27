import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/tr_or.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/stop_execution_models.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/delivery_format.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';

/// Everything needed to close a stop without leaving the map: what it is, how
/// far it is, and the actions the server allows in its current status:
///
/// * pending  → head to stop (en_route), or mark arrived straight away
/// * en_route → mark arrived
/// * arrived  → confirm pickup / delivery
/// * any open → skip
class StopActionsSheet extends StatelessWidget {
  const StopActionsSheet({
    super.key,
    required this.stop,
    required this.order,
    required this.onEnRoute,
    required this.onArrive,
    required this.onConfirm,
    required this.onSkip,
    required this.onShowOnMap,
    this.distanceMeters,
    this.isBusy = false,
    this.isPendingSync = false,
    this.receiptStatus,
    this.onCheckReceipt,
    this.onRetrySync,
  });

  final RouteStop stop;
  final int order;
  final VoidCallback onEnRoute;
  final VoidCallback onArrive;
  final VoidCallback onConfirm;
  final VoidCallback onSkip;
  final VoidCallback onShowOnMap;
  final double? distanceMeters;

  /// A request for this stop is in flight.
  final bool isBusy;

  /// The last action is waiting in the offline queue.
  final bool isPendingSync;

  /// Goods receipt outcome, for a delivered delivery-note stop.
  final ReceiptStatusModel? receiptStatus;
  final VoidCallback? onCheckReceipt;
  final VoidCallback? onRetrySync;

  @override
  Widget build(BuildContext context) {
    final status = stop.status;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppConstants.width20(context),
        AppConstants.height15(context),
        AppConstants.width20(context),
        AppConstants.height30(context),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            SizedBox(height: AppConstants.height20(context)),
            Text("$order. ${stop.name}", style: Styles.font16SemiBoldBlack(context)),
            SizedBox(height: AppConstants.height5(context)),
            _buildSubtitle(context),
            if (stop.branch?.address != null) ...[
              SizedBox(height: AppConstants.height5(context)),
              Text(stop.branch!.address!, style: Styles.font11MediumGrey46(context)),
            ],
            if (stop.isReturn && !status.isClosed) ...[
              SizedBox(height: AppConstants.height10(context)),
              _buildReturnHint(context),
            ],
            if (stop.items.isNotEmpty) ...[
              SizedBox(height: AppConstants.height10(context)),
              _buildItemsSummary(context),
            ],
            if (isPendingSync) ...[SizedBox(height: AppConstants.height10(context)), _buildPendingSync(context)],
            if (receiptStatus != null) ...[SizedBox(height: AppConstants.height10(context)), _buildReceipt(context)],
            SizedBox(height: AppConstants.height20(context)),
            if (status.isClosed) _buildClosedRow(context) else ..._buildActions(context),
            SizedBox(height: AppConstants.height10(context)),
            if (stop.status == StopStatus.completed && stop.hasDeliveryNote && onCheckReceipt != null) ...[
              DefaultButton(
                text: "check_receipt_status".tr(),
                backgroundColor: Colors.white,
                textColor: AppColors.primarySwatchColor,
                hasBorder: true,
                borderColor: AppColors.primarySwatchColor,
                borderRadius: AppConstants.sp15(context),
                onPress: onCheckReceipt,
              ),
              SizedBox(height: AppConstants.height10(context)),
            ],
            if (stop.hasLocation)
              DefaultButton(
                text: "show_on_map".tr(),
                backgroundColor: Colors.white,
                textColor: AppColors.primarySwatchColor,
                hasBorder: true,
                borderColor: AppColors.primarySwatchColor,
                borderRadius: AppConstants.sp15(context),
                onPress: onShowOnMap,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final status = stop.status;
    final iconSize = MediaQuery.of(context).size.height * .022;

    return [
      if (status.canMarkEnRoute) ...[
        DefaultButton(
          text: "head_to_stop".tr(),
          gradient: AppColors.brandGradient,
          borderRadius: AppConstants.sp15(context),
          isEnabled: !isBusy,
          icon: Icon(Icons.navigation_rounded, size: iconSize, color: Colors.white),
          onPress: onEnRoute,
        ),
        SizedBox(height: AppConstants.height10(context)),
      ],
      if (status.canArrive)
        DefaultButton(
          text: "mark_arrived".tr(),
          gradient: status.canMarkEnRoute ? null : AppColors.brandGradient,
          backgroundColor: status.canMarkEnRoute ? Colors.white : null,
          textColor: status.canMarkEnRoute ? AppColors.primarySwatchColor : null,
          hasBorder: status.canMarkEnRoute,
          borderColor: AppColors.primarySwatchColor,
          borderRadius: AppConstants.sp15(context),
          isEnabled: !isBusy,
          icon: Icon(
            Icons.location_on_outlined,
            size: iconSize,
            color: status.canMarkEnRoute ? AppColors.primarySwatchColor : Colors.white,
          ),
          onPress: onArrive,
        ),
      if (status.canConfirm)
        DefaultButton(
          text: stop.type.confirmKey.tr(),
          gradient: AppColors.brandGradient,
          borderRadius: AppConstants.sp15(context),
          isEnabled: !isBusy,
          icon: Icon(Icons.check_circle_outline_rounded, size: iconSize, color: Colors.white),
          onPress: onConfirm,
        ),
      if (status.canSkip) ...[
        SizedBox(height: AppConstants.height10(context)),
        DefaultButton(
          text: "skip_stop".tr(),
          backgroundColor: Colors.white,
          textColor: AppColors.red,
          hasBorder: true,
          borderColor: AppColors.red.withValues(alpha: .6),
          borderRadius: AppConstants.sp15(context),
          isEnabled: !isBusy,
          onPress: onSkip,
        ),
      ],
    ];
  }

  Widget _buildSubtitle(BuildContext context) {
    return Row(
      children: [
        Text("${stop.type.titleKey.tr()} • ${stop.status.titleKey.tr()}", style: Styles.font11MediumGrey46(context)),
        if (distanceMeters != null) ...[
          SizedBox(width: AppConstants.width10(context)),
          Icon(
            Icons.near_me_rounded,
            size: MediaQuery.of(context).size.height * .014,
            color: AppColors.primarySwatchColor,
          ),
          SizedBox(width: AppConstants.width5(context) * .6),
          Text(
            DeliveryFormat.distanceAway(context, distanceMeters!),
            style: Styles.font11BoldBlack(context).copyWith(color: AppColors.primarySwatchColor),
          ),
        ],
      ],
    );
  }

  /// Items count and total expected quantity, so the driver knows the load
  /// before opening the confirmation sheet.
  Widget _buildItemsSummary(BuildContext context) {
    final number = NumberFormat.decimalPattern(context.locale.languageCode);
    final total = stop.items.fold<double>(0, (sum, item) => sum + item.expectedQty);

    return Wrap(
      spacing: AppConstants.width5(context),
      runSpacing: AppConstants.height5(context),
      children: [
        StatusPill(
          text: "items_count".tr(namedArgs: {"count": number.format(stop.items.length)}),
          color: AppColors.primarySwatchColor,
          icon: Icons.inventory_2_outlined,
        ),
        StatusPill(
          text: "expected_qty_total".tr(namedArgs: {"qty": number.format(total)}),
          color: AppColors.neutralColor[500]!,
        ),
        if (stop.proofs.isNotEmpty)
          StatusPill(
            text: "proofs_count".tr(namedArgs: {"count": number.format(stop.proofs.length)}),
            color: AppColors.secondaryColor,
            icon: Icons.photo_camera_outlined,
          ),
      ],
    );
  }

  Widget _buildPendingSync(BuildContext context) {
    const warning = Color(0xffE8A317);

    return Row(
      children: [
        Icon(Icons.cloud_upload_outlined, size: MediaQuery.of(context).size.height * .018, color: warning),
        SizedBox(width: AppConstants.width5(context)),
        Expanded(child: Text("pending_sync_hint".tr(), style: Styles.font11MediumGrey46(context))),
        if (onRetrySync != null)
          TextButton(
            onPressed: onRetrySync,
            child: Text(
              "retry".tr(),
              style: Styles.font11BoldBlack(context).copyWith(color: AppColors.primarySwatchColor),
            ),
          ),
      ],
    );
  }

  Widget _buildReceipt(BuildContext context) {
    final receipt = receiptStatus!;
    final color = switch (receipt.status) {
      "accepted" => AppColors.secondaryColor,
      "rejected" || "disputed" => AppColors.red,
      "partial" => const Color(0xffE8A317),
      _ => AppColors.neutralColor[500]!,
    };
    final label = trOrHumanized("receipt_${receipt.status}", receipt.status);

    return Row(
      children: [
        StatusPill(text: label, color: color, icon: Icons.receipt_long_outlined),
        if (receipt.qtyMismatchWithDriver) ...[
          SizedBox(width: AppConstants.width5(context)),
          StatusPill(text: "receipt_qty_mismatch".tr(), color: AppColors.red),
        ],
      ],
    );
  }

  /// Goods of a canceled shipment: hand them back, never deliver them.
  Widget _buildReturnHint(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.assignment_return_outlined,
          size: MediaQuery.of(context).size.height * .018,
          color: AppColors.primarySwatchColor,
        ),
        SizedBox(width: AppConstants.width5(context)),
        Expanded(child: Text("return_stop_hint".tr(), style: Styles.font11MediumGrey46(context).copyWith(height: 1.5))),
      ],
    );
  }

  Widget _buildClosedRow(BuildContext context) {
    final bool isDropped = stop.status.isDropped;
    final color = isDropped ? stop.status.color : AppColors.secondaryColor;
    final reason = stop.failureReasonLabel;

    return Row(
      children: [
        Icon(
          switch (stop.status) {
            StopStatus.canceled => Icons.cancel_rounded,
            StopStatus.skipped => Icons.block_rounded,
            _ => Icons.check_circle_rounded,
          },
          size: MediaQuery.of(context).size.height * .022,
          color: color,
        ),
        SizedBox(width: AppConstants.width5(context)),
        Expanded(
          child: Text(
            isDropped && reason != null ? "${stop.status.titleKey.tr()} • $reason" : stop.status.titleKey.tr(),
            style: Styles.font12MediumBlack(context).copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
