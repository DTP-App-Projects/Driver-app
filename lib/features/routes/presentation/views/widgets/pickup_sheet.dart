import 'dart:io';

// intl (re-exported by easy_localization) ships its own TextDirection enum.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/default_text_form_field.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/core/utils/validations/convert_to_english_numbers.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/stop_execution_models.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/delivery_tracking/delivery_tracking_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';

/// Confirms a pickup: loaded quantity per line, barcode verification, seal
/// numbers, cold chain temperature and proof photos, then
/// `POST /driver/stops/{id}/pickup`. Pops with `true` once the server (or the
/// offline queue) accepted it.
class PickupSheet extends StatefulWidget {
  const PickupSheet({super.key, required this.stopId});

  final int stopId;

  @override
  State<PickupSheet> createState() => _PickupSheetState();
}

class _PickupSheetState extends State<PickupSheet> {
  final Map<int, TextEditingController> loaded = {};
  final Map<int, TextEditingController> notes = {};
  final TextEditingController temperature = TextEditingController();
  List<String> seals = [];

  Failure? error;
  bool isUploading = false;
  bool isSubmitting = false;

  DeliveryTrackingCubit get cubit => context.read<DeliveryTrackingCubit>();

  RouteStop get stop => cubit.state.stopById(widget.stopId)!;

  @override
  void initState() {
    super.initState();
    for (final item in stop.items) {
      loaded[item.id] = TextEditingController(text: _format(item.loadedQty ?? item.expectedQty));
      notes[item.id] = TextEditingController(text: item.conditionNotes ?? "");
    }
  }

  @override
  void dispose() {
    for (final controller in [...loaded.values, ...notes.values, temperature]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _format(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  double _qty(TextEditingController controller, double fallback) =>
      double.tryParse(controller.text.trim().replaceAll(",", ".")) ?? fallback;

  Future<void> addPhoto() async {
    if (isUploading) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked == null || !mounted) return;

    setState(() => isUploading = true);
    final result = await cubit.uploadProof(
      stop,
      file: File(picked.path),
      proofType: ProofType.pickupPhoto,
      proofCategory: ProofCategory.pickup,
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

    // Short loads are fine (the trader's receipt records the gap); loading
    // more than was ordered is refused as `loaded_exceeds_expected`.
    final over = current.items.where((item) => _qty(loaded[item.id]!, item.expectedQty) > item.expectedQty).toList();
    if (over.isNotEmpty) {
      setState(() {
        error = CustomError(
          "loaded_exceeds_expected_hint".tr(namedArgs: {"item": over.first.productName}),
          kind: FailureKind.validation,
          code: "loaded_exceeds_expected",
        );
      });
      return;
    }

    // Lines flagged barcode_required must be verified before the server will
    // accept the pickup; the button is disabled meanwhile, this is the backstop.
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

    setState(() {
      isSubmitting = true;
      error = null;
    });

    // Every line goes out: a line left out would count as fully loaded.
    final request = PickupRequest(
      items: [
        for (final item in current.items)
          PickupItemRequest(
            itemId: item.id,
            loadedQty: _qty(loaded[item.id]!, item.expectedQty),
            barcodeValue: item.barcodeValue?.trim(),
            conditionNotes: notes[item.id]!.text.trim(),
          ),
      ],
      sealNumbers: seals,
      temperature: double.tryParse(temperature.text.trim().replaceAll(",", ".")),
    );

    final result = await cubit.confirmPickup(current, request);
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        isSubmitting = false;
        error = failure;
      }),
      (_) => Navigator.pop(context, true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeliveryTrackingCubit, DeliveryTrackingState>(
      builder: (context, state) {
        final current = state.stopById(widget.stopId);
        if (current == null) return const SizedBox.shrink();
        final failedIds = error?.failedItemIds ?? const <int>{};
        final unverified = current.items.where((item) => item.needsBarcodeScan).toList();

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: .85,
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
                  Text("confirm_pickup".tr(), style: Styles.font18SemiBoldBlack(context)),
                  SizedBox(height: AppConstants.height5(context)),
                  Text(current.name, style: Styles.font12MediumGrey46(context)),
                  SizedBox(height: AppConstants.height20(context)),
                  if (current.items.isNotEmpty) ...[
                    SheetSectionLabel(title: "barcode".tr()),
                    BarcodeVerifyField(stop: current),
                    SizedBox(height: AppConstants.height20(context)),
                    SheetSectionLabel(title: "items".tr()),
                    for (final item in current.items) ...[
                      _buildItem(context, item, highlight: failedIds.contains(item.id)),
                      SizedBox(height: AppConstants.height10(context)),
                    ],
                    SizedBox(height: AppConstants.height10(context)),
                  ],
                  SheetSectionLabel(title: "seal_numbers".tr()),
                  SheetCard(
                    child: SealsInput(seals: seals, onChanged: (value) => setState(() => seals = value)),
                  ),
                  SizedBox(height: AppConstants.height20(context)),
                  SheetSectionLabel(title: "temperature_optional".tr()),
                  DefaultTextFormField(
                    controller: temperature,
                    textInputType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    required: false,
                    maxLines: 1,
                    hintText: "temperature_hint".tr(),
                    borderRadius: AppConstants.sp15(context),
                    contentPaddingVertical: AppConstants.height15(context),
                    contentPaddingHorizontal: AppConstants.width15(context),
                    borderSideEnabledColor: const Color(0xffEDEFF2),
                    formatter: [ArabicToEnglishNumberFormatter()],
                    prefixIcon: Icon(Icons.thermostat_rounded, color: const Color(0xff9C9B9A)),
                  ),
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
                  if (unverified.isNotEmpty) ...[
                    SizedBox(height: AppConstants.height15(context)),
                    Text(
                      "barcode_required_hint".tr(namedArgs: {"item": unverified.first.productName}),
                      style: Styles.font11MediumGrey46(context).copyWith(color: AppColors.red),
                    ),
                  ],
                  SizedBox(height: AppConstants.height24(context)),
                  DefaultButton(
                    text: "confirm_pickup".tr(),
                    gradient: AppColors.brandGradient,
                    borderRadius: AppConstants.sp15(context),
                    isEnabled: !isSubmitting && !state.isBusy(current.id) && unverified.isEmpty,
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

  Widget _buildItem(BuildContext context, StopItemModel item, {required bool highlight}) {
    final number = NumberFormat.decimalPattern(context.locale.languageCode);
    final qty = _qty(loaded[item.id]!, item.expectedQty);

    return SheetCard(
      highlight: highlight,
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
                text: "expected_qty".tr(namedArgs: {"qty": number.format(item.expectedQty)}),
                color: AppColors.neutralColor[500]!,
              ),
            ],
          ),
          ItemCodesLine(item: item),
          SizedBox(height: AppConstants.height10(context)),
          Row(
            children: [
              Expanded(
                child: QuantityField(
                  label: "loaded_qty".tr(),
                  controller: loaded[item.id]!,
                  color: qty > item.expectedQty ? AppColors.red : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(width: AppConstants.width10(context)),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.only(top: AppConstants.height15(context)),
                  child: _buildBarcodePill(context, item),
                ),
              ),
            ],
          ),
          if (qty < item.expectedQty) ...[
            SizedBox(height: AppConstants.height5(context)),
            Text(
              "short_load_warning".tr(namedArgs: {"qty": number.format(item.expectedQty - qty)}),
              style: Styles.font10MediumGrey46(context).copyWith(color: const Color(0xffE8A317)),
            ),
          ] else if (qty > item.expectedQty) ...[
            SizedBox(height: AppConstants.height5(context)),
            Text(
              "api_loaded_exceeds_expected".tr(),
              style: Styles.font10MediumGrey46(context).copyWith(color: AppColors.red),
            ),
          ],
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
        ],
      ),
    );
  }

  Widget _buildBarcodePill(BuildContext context, StopItemModel item) {
    if (item.barcodeMatch) {
      return StatusPill(text: "barcode_matched".tr(), color: AppColors.secondaryColor, icon: Icons.qr_code_rounded);
    }
    if (item.barcodeRequired) {
      return StatusPill(text: "barcode_required".tr(), color: AppColors.red, icon: Icons.qr_code_rounded);
    }
    return StatusPill(text: "barcode_optional".tr(), color: AppColors.neutralColor[400]!, icon: Icons.qr_code_rounded);
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
