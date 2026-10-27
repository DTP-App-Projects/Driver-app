import 'dart:io';

// intl (re-exported by easy_localization) ships its own TextDirection enum.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/code_scanner_view.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/default_text_form_field.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/stop_execution_models.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/delivery_tracking/delivery_tracking_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/handoff_bypass_sheet.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/partial_reject_dialog.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';

/// Confirms a delivery: the receiver handoff (trader's QR scan, typed code,
/// or an audited bypass with a delivery photo), the delivered-returned-damaged
/// split per line that must reconcile with the quantity loaded at pickup,
/// partial rejections, seal verification, signer identity and proof photos,
/// then `POST /driver/stops/{id}/deliver`.
class DeliverySheet extends StatefulWidget {
  const DeliverySheet({super.key, required this.stopId});

  final int stopId;

  @override
  State<DeliverySheet> createState() => _DeliverySheetState();
}

class _DeliverySheetState extends State<DeliverySheet> {
  final Map<int, TextEditingController> delivered = {};
  final Map<int, TextEditingController> returned = {};
  final Map<int, TextEditingController> damaged = {};
  final Map<int, TextEditingController> notes = {};
  final TextEditingController otp = TextEditingController();
  final TextEditingController signerName = TextEditingController();
  final TextEditingController signerRole = TextEditingController();
  List<String> seals = [];

  /// Set once the "no code possible" sheet returned a reason (a delivery
  /// photo was attached there).
  String? bypassReason;

  /// The code field is shown on demand; scanning the QR is the main path.
  bool showCodeEntry = false;
  SealResult? sealResult;
  Failure? error;
  bool isScanning = false;
  bool isVerifyingOtp = false;
  bool isResendingOtp = false;
  bool isVerifyingSeals = false;
  bool isUploading = false;
  bool isSubmitting = false;

  DeliveryTrackingCubit get cubit => context.read<DeliveryTrackingCubit>();

  RouteStop get stop => cubit.state.stopById(widget.stopId)!;

  @override
  void initState() {
    super.initState();
    _syncControllers(stop);
  }

  /// Creates the controllers for new lines and refreshes quantities changed
  /// server side (a partial reject rewrites returned / delivered). The split
  /// starts from what was loaded at pickup, not from what was ordered.
  void _syncControllers(RouteStop current) {
    for (final item in current.items) {
      final returnedQty = item.returnedQty ?? 0;
      final damagedQty = item.damagedQty ?? 0;
      final deliveredQty = item.deliveredQty ?? (item.deliverableQty - returnedQty - damagedQty);
      delivered.putIfAbsent(item.id, () => TextEditingController());
      returned.putIfAbsent(item.id, () => TextEditingController());
      damaged.putIfAbsent(item.id, () => TextEditingController());
      notes.putIfAbsent(item.id, () => TextEditingController(text: item.conditionNotes ?? ""));
      delivered[item.id]!.text = _format(deliveredQty);
      returned[item.id]!.text = _format(returnedQty);
      damaged[item.id]!.text = _format(damagedQty);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      ...delivered.values,
      ...returned.values,
      ...damaged.values,
      ...notes.values,
      otp,
      signerName,
      signerRole,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _format(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  double _qty(TextEditingController controller) => double.tryParse(controller.text.trim().replaceAll(",", ".")) ?? 0;

  DeliveryItemRequest _line(StopItemModel item) => DeliveryItemRequest(
    itemId: item.id,
    loadedQty: item.deliverableQty,
    deliveredQty: _qty(delivered[item.id]!),
    returnedQty: _qty(returned[item.id]!),
    damagedQty: _qty(damaged[item.id]!),
    barcodeValue: item.barcodeValue?.trim(),
    conditionNotes: notes[item.id]!.text.trim(),
  );

  /// Whether the receiver has to prove the handoff. The arrival response
  /// says so; without it (app restarted at the door) every trader delivery
  /// needs it, internal transfers between own branches do not.
  bool _handoffRequired(DeliveryTrackingState state, RouteStop current) =>
      state.arrivals[current.id]?.otpRequired ?? current.type != StopType.internalTransferDelivery;

  /// Verified live, captured offline for the server to check at sync, or an
  /// audited bypass: any of them lets the delivery be confirmed.
  bool _handoffDone(DeliveryTrackingState state, RouteStop current) =>
      !_handoffRequired(state, current) ||
      state.isOtpVerified(current.id) ||
      state.handoffCaptures.containsKey(current.id) ||
      bypassReason != null;

  // ------------------------------------------------------------ handoff

  /// Primary path: scan the QR on the trader's phone (`TJD1:<stop>:<code>`).
  Future<void> scanHandoff() async {
    if (isScanning) return;
    final text = await scanCode(context, title: "scan_trader_qr".tr(), hint: "scan_trader_qr_hint".tr());
    if (text == null || !mounted) return;
    await _verifyHandoff(handoffQr: text);
  }

  /// Secondary path: the 6-digit code typed by the driver.
  Future<void> verifyCode() async {
    final code = otp.text.trim();
    if (code.length != 6 || isVerifyingOtp) return;
    FocusScope.of(context).unfocus();
    await _verifyHandoff(otpCode: code);
  }

  Future<void> _verifyHandoff({String? handoffQr, String? otpCode}) async {
    setState(() => handoffQr != null ? isScanning = true : isVerifyingOtp = true);
    cubit.clearHandoffCapture(stop);
    final result = await cubit.verifyHandoff(stop, handoffQr: handoffQr, otpCode: otpCode);
    if (!mounted) return;
    setState(() {
      isScanning = false;
      isVerifyingOtp = false;
    });

    result.fold(
      (failure) => toast(
        text: failure.isNetwork ? "handoff_saved_offline".tr() : failure.errMessage,
        context: context,
        isSuccess: failure.isNetwork,
      ),
      (outcome) {
        if (outcome.success) {
          setState(() {
            error = null;
            bypassReason = null;
          });
          toast(text: "handoff_verified".tr(), context: context);
        } else {
          toast(text: handoffFailureText(outcome), context: context, isSuccess: false);
        }
      },
    );
  }

  Future<void> resendOtp() async {
    if (isResendingOtp) return;
    setState(() => isResendingOtp = true);

    final result = await cubit.resendOtp(stop);
    if (!mounted) return;
    setState(() => isResendingOtp = false);
    otp.clear();

    result.fold(
      (failure) => toast(text: failure.errMessage, context: context, isSuccess: false),
      (outcome) => toast(
        text: outcome.success ? "api_otp_resent".tr() : handoffFailureText(outcome),
        context: context,
        isSuccess: outcome.success,
      ),
    );
  }

  Future<void> openBypass() async {
    final reason = await showHandoffBypassSheet(context, stopId: widget.stopId, selected: bypassReason);
    if (reason == null || !mounted) return;
    setState(() {
      bypassReason = reason;
      error = null;
    });
  }

  // -------------------------------------------------------------- seals

  Future<void> verifySeals() async {
    if (seals.isEmpty || isVerifyingSeals) return;
    setState(() => isVerifyingSeals = true);

    final result = await cubit.submitSeals(stop, seals, isDelivery: true);
    if (!mounted) return;
    setState(() => isVerifyingSeals = false);

    result.fold((failure) => toast(text: failure.errMessage, context: context, isSuccess: false), (outcome) {
      setState(() => sealResult = outcome);
      toast(
        text: (outcome.success ? "seals_matched" : "seals_mismatch").tr(),
        context: context,
        isSuccess: outcome.success,
      );
    });
  }

  // ------------------------------------------------------------- others

  Future<void> partialReject(StopItemModel item) async {
    final result = await showPartialRejectDialog(context, item: item);
    if (result == null || !mounted) return;

    final outcome = await cubit.partialReject(
      stop,
      item: item,
      rejectedQty: result.quantity,
      reason: result.reason,
      notes: result.notes,
    );
    if (!mounted) return;

    outcome.fold((failure) => toast(text: failure.errMessage, context: context, isSuccess: false), (_) {
      _syncControllers(stop);
      setState(() {});
      toast(text: "partial_reject_recorded".tr(), context: context);
    });
  }

  Future<void> addPhoto() async {
    if (isUploading) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked == null || !mounted) return;

    setState(() => isUploading = true);
    final result = await cubit.uploadProof(
      stop,
      file: File(picked.path),
      proofType: ProofType.deliveryPhoto,
      proofCategory: ProofCategory.delivery,
      signerName: signerName.text.trim(),
      signerRole: signerRole.text.trim(),
    );
    if (!mounted) return;
    setState(() => isUploading = false);
    result.fold(
      (failure) => toast(text: failure.errMessage, context: context, isSuccess: false),
      (_) => toast(text: "api_proof_uploaded".tr(), context: context),
    );
  }

  Future<void> submit() async {
    if (isSubmitting) return;
    FocusScope.of(context).unfocus();
    final current = stop;
    final state = cubit.state;

    // Local checks the server would refuse anyway.
    final lines = [for (final item in current.items) _line(item)];
    final unbalanced = lines.where((line) => !line.isBalanced).toList();
    if (unbalanced.isNotEmpty) {
      setState(() {
        error = CustomError(
          "quantity_balance_hint".tr(),
          kind: FailureKind.validation,
          code: "quantity_balance_failed",
        );
      });
      return;
    }

    final unscanned = current.items.where((item) => item.needsBarcodeScan).toList();
    if (unscanned.isNotEmpty) {
      setState(() {
        error = CustomError(
          "barcode_required_hint".tr(namedArgs: {"item": unscanned.first.productName}),
          kind: FailureKind.validation,
          code: "barcode_validation_failed",
        );
      });
      return;
    }

    if (!_handoffDone(state, current)) {
      setState(() {
        error = CustomError(
          "api_handoff_verification_required".tr(),
          kind: FailureKind.validation,
          code: "handoff_verification_required",
        );
      });
      return;
    }

    // Verified live: nothing to send again. Captured offline: the server
    // checks it now (or at sync). Otherwise the audited bypass.
    final bool verified = state.isOtpVerified(current.id);
    final HandoffCapture? capture = verified ? null : state.handoffCaptures[current.id];
    final String? bypass = verified || capture != null ? null : bypassReason;

    setState(() {
      isSubmitting = true;
      error = null;
    });

    // Every line goes out: a missing one is refused as item_missing_from_delivery.
    final request = DeliveryRequest(
      handoffQr: capture?.handoffQr,
      otpCode: capture?.otpCode,
      bypassReason: bypass,
      items: lines,
      sealNumbers: seals,
      signerName: signerName.text.trim(),
      signerRole: signerRole.text.trim(),
    );

    final result = await cubit.confirmDelivery(current, request);
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        isSubmitting = false;
        error = failure;
      }),
      (_) => Navigator.pop(context, true),
    );
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeliveryTrackingCubit, DeliveryTrackingState>(
      builder: (context, state) {
        final current = state.stopById(widget.stopId);
        if (current == null) return const SizedBox.shrink();
        _syncControllersForNewLines(current);
        final failedIds = error?.failedItemIds ?? const <int>{};
        final arrival = state.arrivals[current.id];
        final unverified = current.items.where((item) => item.needsBarcodeScan).toList();
        final handoffDone = _handoffDone(state, current);
        final rejection = cubit.offlineQueue.rejectionForStop(current.id);

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: .9,
            maxChildSize: .95,
            minChildSize: .5,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  AppConstants.width20(context),
                  AppConstants.height15(context),
                  AppConstants.width20(context),
                  AppConstants.height30(context),
                ),
                children: [
                  const SheetHandle(),
                  SizedBox(height: AppConstants.height20(context)),
                  Text("confirm_delivery".tr(), style: Styles.font18SemiBoldBlack(context)),
                  SizedBox(height: AppConstants.height5(context)),
                  Text(current.name, style: Styles.font12MediumGrey46(context)),
                  SizedBox(height: AppConstants.height20(context)),
                  if (rejection != null && error == null) ...[
                    SheetErrorBox(
                      message: "sync_stop_rejected_short".tr(namedArgs: {"reason": syncResultText(rejection.result)}),
                    ),
                    SizedBox(height: AppConstants.height20(context)),
                  ],
                  if (_handoffRequired(state, current)) ...[
                    SheetSectionLabel(title: "handoff_section".tr()),
                    _buildHandoffSection(context, state, current, arrival),
                    SizedBox(height: AppConstants.height20(context)),
                  ],
                  if (current.items.any((item) => item.barcodeRequired || item.barcode != null)) ...[
                    SheetSectionLabel(title: "barcode".tr()),
                    BarcodeVerifyField(stop: current),
                    SizedBox(height: AppConstants.height20(context)),
                  ],
                  if (current.items.isNotEmpty) ...[
                    SheetSectionLabel(title: "items".tr()),
                    Text("quantity_balance_hint".tr(), style: Styles.font10MediumGrey46(context)),
                    SizedBox(height: AppConstants.height10(context)),
                    for (final item in current.items) ...[
                      _buildItem(context, item, highlight: failedIds.contains(item.id)),
                      SizedBox(height: AppConstants.height10(context)),
                    ],
                    SizedBox(height: AppConstants.height10(context)),
                  ],
                  SheetSectionLabel(title: "seal_numbers".tr()),
                  _buildSealsSection(context, arrival),
                  SizedBox(height: AppConstants.height20(context)),
                  SheetSectionLabel(title: "receiver".tr()),
                  _buildSignerSection(context),
                  SizedBox(height: AppConstants.height20(context)),
                  SheetSectionLabel(
                    title: "proof_photos".tr(),
                    trailing: Text(
                      "proofs_count".tr(namedArgs: {"count": current.proofs.length.toString()}),
                      style: Styles.font11MediumGrey46(context),
                    ),
                  ),
                  ProofThumbnails(proofs: current.proofs),
                  _buildPhotoButton(context),
                  if (error != null) ...[
                    SizedBox(height: AppConstants.height20(context)),
                    SheetErrorBox(message: error!.errMessage, lines: itemErrorLines(error, current)),
                  ],
                  if (!handoffDone || unverified.isNotEmpty) ...[
                    SizedBox(height: AppConstants.height15(context)),
                    Text(
                      !handoffDone
                          ? "api_handoff_verification_required".tr()
                          : "barcode_required_hint".tr(namedArgs: {"item": unverified.first.productName}),
                      style: Styles.font11MediumGrey46(context).copyWith(color: AppColors.red),
                    ),
                  ],
                  SizedBox(height: AppConstants.height24(context)),
                  DefaultButton(
                    text: "confirm_delivery".tr(),
                    gradient: AppColors.brandGradient,
                    borderRadius: AppConstants.sp15(context),
                    isEnabled: !isSubmitting && !state.isBusy(current.id) && handoffDone && unverified.isEmpty,
                    icon: Icon(
                      Icons.check_circle_outline_rounded,
                      size: MediaQuery.of(context).size.height * .022,
                      color: Colors.white,
                    ),
                    onPress: submit,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _syncControllersForNewLines(RouteStop current) {
    for (final item in current.items) {
      if (!delivered.containsKey(item.id)) _syncControllers(current);
    }
  }

  Widget _buildHandoffSection(
    BuildContext context,
    DeliveryTrackingState state,
    RouteStop current,
    ArrivalResult? arrival,
  ) {
    final OtpResult? last = state.otpResults[current.id];
    final HandoffCapture? capture = state.handoffCaptures[current.id];
    final bool needsResend = last != null && !last.success && last.needsNewCode;

    if (state.isOtpVerified(current.id)) {
      return _buildHandoffStatus(
        context,
        icon: Icons.verified_rounded,
        color: AppColors.secondaryColor,
        text: "handoff_verified".tr(),
      );
    }

    if (capture != null) {
      return _buildHandoffStatus(
        context,
        icon: Icons.cloud_off_rounded,
        color: const Color(0xffE8A317),
        text: "handoff_saved_offline".tr(),
        action: TextButton(onPressed: scanHandoff, child: Text("scan_again".tr())),
      );
    }

    if (bypassReason != null) {
      return _buildHandoffStatus(
        context,
        icon: Icons.report_outlined,
        color: const Color(0xffE8A317),
        text: "handoff_bypass_selected".tr(namedArgs: {"reason": "handoff_bypass_$bypassReason".tr()}),
        subtitle: "handoff_no_code_notice".tr(),
        action: TextButton(onPressed: () => setState(() => bypassReason = null), child: Text("cancel".tr())),
      );
    }

    return SheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            arrival?.otpError != null
                ? "otp_sms_failed".tr()
                : arrival?.otpSentTo != null
                ? "handoff_code_sent_to".tr(namedArgs: {"phone": arrival!.otpSentTo!})
                : "handoff_hint".tr(),
            style: Styles.font11MediumGrey46(context).copyWith(height: 1.5),
          ),
          SizedBox(height: AppConstants.height15(context)),
          DefaultButton(
            text: (isScanning ? "verifying" : "scan_trader_qr").tr(),
            gradient: AppColors.brandGradient,
            borderRadius: AppConstants.sp15(context),
            isEnabled: !isScanning && !needsResend,
            icon: Icon(
              Icons.qr_code_scanner_rounded,
              size: MediaQuery.of(context).size.height * .026,
              color: Colors.white,
            ),
            onPress: scanHandoff,
          ),
          SizedBox(height: AppConstants.height10(context)),
          DefaultButton(
            text: "enter_code".tr(),
            backgroundColor: Colors.white,
            textColor: AppColors.primarySwatchColor,
            hasBorder: true,
            borderColor: AppColors.primarySwatchColor,
            borderRadius: AppConstants.sp15(context),
            isEnabled: !needsResend,
            onPress: () => setState(() => showCodeEntry = !showCodeEntry),
          ),
          if (showCodeEntry && !needsResend) ...[
            SizedBox(height: AppConstants.height15(context)),
            Directionality(
              textDirection: TextDirection.ltr,
              child: PinCodeTextField(
                appContext: context,
                length: 6,
                controller: otp,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                cursorColor: AppColors.primarySwatchColor,
                textStyle: Styles.font16SemiBoldBlack(context),
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(AppConstants.sp10(context)),
                  fieldHeight: MediaQuery.of(context).size.height * .055,
                  fieldWidth: MediaQuery.of(context).size.width * .11,
                  activeFillColor: Colors.white,
                  inactiveFillColor: const Color(0xffFBFBFC),
                  selectedFillColor: Colors.white,
                  activeColor: AppColors.primarySwatchColor,
                  inactiveColor: const Color(0xffEDEFF2),
                  selectedColor: AppColors.primarySwatchColor,
                  disabledColor: const Color(0xffEDEFF2),
                ),
                enableActiveFill: true,
                onChanged: (_) {},
                onCompleted: (_) => verifyCode(),
              ),
            ),
            DefaultButton(
              text: "verify_code".tr(),
              borderRadius: AppConstants.sp15(context),
              isEnabled: !isVerifyingOtp,
              onPress: verifyCode,
            ),
          ],
          if (last != null && !last.success) ...[
            SizedBox(height: AppConstants.height10(context)),
            Text(
              handoffFailureText(last),
              style: Styles.font11MediumGrey46(context).copyWith(color: AppColors.red, fontWeight: FontWeight.w700),
            ),
          ],
          if (needsResend || arrival?.otpError != null) ...[
            SizedBox(height: AppConstants.height10(context)),
            DefaultButton(
              text: "resend_code".tr(),
              backgroundColor: Colors.white,
              textColor: AppColors.primarySwatchColor,
              hasBorder: true,
              borderColor: AppColors.primarySwatchColor,
              borderRadius: AppConstants.sp15(context),
              isEnabled: !isResendingOtp,
              icon: Icon(
                Icons.refresh_rounded,
                size: MediaQuery.of(context).size.height * .02,
                color: AppColors.primarySwatchColor,
              ),
              onPress: resendOtp,
            ),
          ],
          SizedBox(height: AppConstants.height5(context)),
          Center(
            child: TextButton(
              onPressed: openBypass,
              child: Text(
                "handoff_no_code_link".tr(),
                style: Styles.font11MediumGrey46(context).copyWith(decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandoffStatus(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
    String? subtitle,
    Widget? action,
  }) {
    return SheetCard(
      child: Row(
        children: [
          Icon(icon, color: color, size: MediaQuery.of(context).size.height * .024),
          SizedBox(width: AppConstants.width10(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: Styles.font14MediumBlack(context).copyWith(color: color, fontWeight: FontWeight.w700),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: AppConstants.height5(context) * .6),
                  Text(subtitle, style: Styles.font10MediumGrey46(context)),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, StopItemModel item, {required bool highlight}) {
    final number = NumberFormat.decimalPattern(context.locale.languageCode);
    final line = _line(item);

    return SheetCard(
      highlight: highlight || !line.isBalanced,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Styles.font14MediumBlack(context).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(width: AppConstants.width5(context)),
              StatusPill(
                text: "loaded_qty_pill".tr(namedArgs: {"qty": number.format(item.deliverableQty)}),
                color: line.isBalanced ? AppColors.neutralColor[500]! : AppColors.red,
              ),
            ],
          ),
          if (item.deliverableQty != item.expectedQty)
            Padding(
              padding: EdgeInsets.only(top: AppConstants.height5(context) * .6),
              child: Text(
                "short_loaded_of".tr(
                  namedArgs: {
                    "loaded": number.format(item.deliverableQty),
                    "expected": number.format(item.expectedQty),
                  },
                ),
                style: Styles.font10MediumGrey46(context).copyWith(color: const Color(0xffE8A317)),
              ),
            ),
          ItemCodesLine(item: item),
          SizedBox(height: AppConstants.height5(context)),
          StatusPill(
            text:
                (item.barcodeMatch
                        ? "barcode_matched"
                        : item.barcodeRequired
                        ? "barcode_required"
                        : "barcode_optional")
                    .tr(),
            color: item.barcodeMatch
                ? AppColors.secondaryColor
                : item.barcodeRequired
                ? AppColors.red
                : AppColors.neutralColor[400]!,
            icon: Icons.qr_code_rounded,
          ),
          SizedBox(height: AppConstants.height10(context)),
          Row(
            children: [
              Expanded(
                child: QuantityField(
                  label: "delivered_qty".tr(),
                  controller: delivered[item.id]!,
                  color: AppColors.secondaryColor,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(width: AppConstants.width10(context)),
              Expanded(
                child: QuantityField(
                  label: "returned_qty".tr(),
                  controller: returned[item.id]!,
                  color: const Color(0xffE8A317),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(width: AppConstants.width10(context)),
              Expanded(
                child: QuantityField(
                  label: "damaged_qty".tr(),
                  controller: damaged[item.id]!,
                  color: AppColors.red,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          SizedBox(height: AppConstants.height10(context)),
          DefaultTextFormField(
            controller: notes[item.id]!,
            textInputType: TextInputType.text,
            required: false,
            maxLines: 1,
            hintText: "condition_notes_hint".tr(),
            borderRadius: AppConstants.sp10(context),
            contentPaddingVertical: AppConstants.height10(context),
            contentPaddingHorizontal: AppConstants.width10(context),
            borderSideEnabledColor: const Color(0xffEDEFF2),
          ),
          SizedBox(height: AppConstants.height5(context)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => partialReject(item),
              icon: Icon(Icons.remove_circle_outline_rounded, size: MediaQuery.of(context).size.height * .018),
              label: Text("partial_reject".tr(), style: Styles.font11BoldBlack(context).copyWith(color: AppColors.red)),
              style: TextButton.styleFrom(foregroundColor: AppColors.red, visualDensity: VisualDensity.compact),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSealsSection(BuildContext context, ArrivalResult? arrival) {
    final result = sealResult;

    return SheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SealsInput(
            seals: seals,
            expected: arrival?.expectedSealNumbers ?? const [],
            onChanged: (value) => setState(() {
              seals = value;
              sealResult = null;
            }),
          ),
          if (seals.isNotEmpty) ...[
            SizedBox(height: AppConstants.height10(context)),
            DefaultButton(
              text: "verify_seals".tr(),
              backgroundColor: Colors.white,
              textColor: AppColors.primarySwatchColor,
              hasBorder: true,
              borderColor: AppColors.primarySwatchColor,
              borderRadius: AppConstants.sp15(context),
              isEnabled: !isVerifyingSeals,
              onPress: verifySeals,
            ),
          ],
          if (result != null) ...[
            SizedBox(height: AppConstants.height10(context)),
            Wrap(
              spacing: AppConstants.width5(context),
              runSpacing: AppConstants.height5(context),
              children: [
                StatusPill(
                  text: (result.success ? "seals_matched" : "seals_mismatch").tr(),
                  color: result.success ? AppColors.secondaryColor : AppColors.red,
                  icon: result.success ? Icons.lock_rounded : Icons.lock_open_rounded,
                ),
                if (result.mismatched.isNotEmpty)
                  StatusPill(text: "${"seals_mismatched".tr()}: ${result.mismatched.join(", ")}", color: AppColors.red),
                if (result.missing.isNotEmpty)
                  StatusPill(text: "${"seals_missing".tr()}: ${result.missing.join(", ")}", color: AppColors.red),
                if (result.extra.isNotEmpty)
                  StatusPill(text: "${"seals_extra".tr()}: ${result.extra.join(", ")}", color: const Color(0xffE8A317)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignerSection(BuildContext context) {
    return SheetCard(
      child: Column(
        children: [
          DefaultTextFormField(
            controller: signerName,
            textInputType: TextInputType.name,
            required: false,
            maxLines: 1,
            hintText: "signer_name".tr(),
            borderRadius: AppConstants.sp10(context),
            contentPaddingVertical: AppConstants.height10(context),
            contentPaddingHorizontal: AppConstants.width10(context),
            borderSideEnabledColor: const Color(0xffEDEFF2),
            prefixIcon: Icon(Icons.person_outline_rounded, color: const Color(0xff9C9B9A)),
          ),
          SizedBox(height: AppConstants.height10(context)),
          DefaultTextFormField(
            controller: signerRole,
            textInputType: TextInputType.text,
            required: false,
            maxLines: 1,
            hintText: "signer_role".tr(),
            borderRadius: AppConstants.sp10(context),
            contentPaddingVertical: AppConstants.height10(context),
            contentPaddingHorizontal: AppConstants.width10(context),
            borderSideEnabledColor: const Color(0xffEDEFF2),
            prefixIcon: Icon(Icons.badge_outlined, color: const Color(0xff9C9B9A)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoButton(BuildContext context) {
    return SheetCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: addPhoto,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppConstants.height15(context)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isUploading)
                SizedBox(
                  width: MediaQuery.of(context).size.height * .02,
                  height: MediaQuery.of(context).size.height * .02,
                  child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primarySwatchColor),
                )
              else
                Icon(
                  Icons.add_a_photo_outlined,
                  size: MediaQuery.of(context).size.height * .024,
                  color: AppColors.primarySwatchColor,
                ),
              SizedBox(width: AppConstants.width5(context)),
              Text(
                (isUploading ? "uploading" : "add_proof_photo").tr(),
                style: Styles.font14MediumBlack(
                  context,
                ).copyWith(color: AppColors.primarySwatchColor, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
