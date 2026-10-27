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
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/stop_execution_models.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/delivery_tracking/delivery_tracking_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';

/// Closes a `return_to_base` stop: the goods of a canceled shipment are
/// handed back at the supplier warehouse. Lists what is on the truck, takes
/// optional return photos and a note, then `POST /driver/stops/{id}/return`.
/// Pops with `true` once the server (or the offline queue) accepted it.
class ReturnSheet extends StatefulWidget {
  const ReturnSheet({super.key, required this.stopId});

  final int stopId;

  @override
  State<ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends State<ReturnSheet> {
  final TextEditingController notes = TextEditingController();

  Failure? error;
  bool isUploading = false;
  bool isSubmitting = false;

  DeliveryTrackingCubit get cubit => context.read<DeliveryTrackingCubit>();

  RouteStop get stop => cubit.state.stopById(widget.stopId)!;

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> addPhoto() async {
    if (isUploading) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked == null || !mounted) return;

    setState(() => isUploading = true);
    final result = await cubit.uploadProof(
      stop,
      file: File(picked.path),
      proofType: ProofType.returnPhoto,
      proofCategory: ProofCategory.returned,
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
    setState(() {
      isSubmitting = true;
      error = null;
    });

    final result = await cubit.confirmReturn(stop, ReturnRequest(notes: notes.text));
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

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: .7,
            maxChildSize: .95,
            minChildSize: .4,
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
                  Text("confirm_return".tr(), style: Styles.font18SemiBoldBlack(context)),
                  SizedBox(height: AppConstants.height5(context)),
                  Text(current.name, style: Styles.font12MediumGrey46(context)),
                  SizedBox(height: AppConstants.height10(context)),
                  _buildHint(context),
                  SizedBox(height: AppConstants.height20(context)),
                  if (current.items.isNotEmpty) ...[
                    SheetSectionLabel(title: "items_on_truck".tr()),
                    for (final item in current.items) ...[
                      _buildItem(context, item),
                      SizedBox(height: AppConstants.height10(context)),
                    ],
                    SizedBox(height: AppConstants.height10(context)),
                  ],
                  SheetSectionLabel(
                    title: "proof_photos".tr(),
                    trailing: Text(
                      "proofs_count".tr(namedArgs: {"count": current.proofs.length.toString()}),
                      style: Styles.font11MediumGrey46(context),
                    ),
                  ),
                  _buildPhotoButton(context),
                  SizedBox(height: AppConstants.height20(context)),
                  SheetSectionLabel(title: "return_notes_optional".tr()),
                  DefaultTextFormField(
                    controller: notes,
                    textInputType: TextInputType.multiline,
                    required: false,
                    maxLines: 3,
                    maxLength: ReturnRequest.notesMaxLength,
                    hintText: "return_notes_hint".tr(),
                    borderRadius: AppConstants.sp15(context),
                    contentPaddingVertical: AppConstants.height15(context),
                    contentPaddingHorizontal: AppConstants.width15(context),
                    borderSideEnabledColor: const Color(0xffEDEFF2),
                  ),
                  if (error != null) ...[
                    SizedBox(height: AppConstants.height20(context)),
                    SheetErrorBox(message: error!.errMessage, lines: error!.detailLines),
                  ],
                  SizedBox(height: AppConstants.height24(context)),
                  DefaultButton(
                    text: "confirm_return".tr(),
                    gradient: AppColors.brandGradient,
                    borderRadius: AppConstants.sp15(context),
                    isEnabled: !isSubmitting && !state.isBusy(current.id),
                    icon: Icon(
                      Icons.assignment_return_outlined,
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

  /// Why this stop exists: the shipment was canceled after it was loaded.
  Widget _buildHint(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppConstants.sp10(context)),
      decoration: BoxDecoration(
        color: AppColors.primarySwatchColor.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(AppConstants.sp10(context)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: MediaQuery.of(context).size.height * .02,
            color: AppColors.primarySwatchColor,
          ),
          SizedBox(width: AppConstants.width10(context)),
          Expanded(
            child: Text("return_stop_hint".tr(), style: Styles.font11MediumGrey46(context).copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, StopItemModel item) {
    final number = NumberFormat.decimalPattern(context.locale.languageCode);
    final qty = item.loadedQty ?? item.expectedQty;

    return SheetCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Styles.font14MediumBlack(context).copyWith(fontWeight: FontWeight.w700),
                ),
                ItemCodesLine(item: item),
              ],
            ),
          ),
          SizedBox(width: AppConstants.width5(context)),
          StatusPill(
            text: "qty_value".tr(namedArgs: {"qty": number.format(qty)}),
            color: AppColors.primarySwatchColor,
            icon: Icons.inventory_2_outlined,
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
                (isUploading ? "uploading" : "add_return_photo").tr(),
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
