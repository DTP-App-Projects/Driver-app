import 'dart:io';

// intl (re-exported by easy_localization) ships its own TextDirection enum.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/stop_execution_models.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/delivery_tracking/delivery_tracking_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';

/// Opens the "no code possible" sheet over the delivery sheet. Pops with
/// the bypass reason once one of [handoffBypassReasons] was picked and a
/// delivery photo is attached; null when the driver backs out.
Future<String?> showHandoffBypassSheet(BuildContext context, {required int stopId, String? selected}) {
  final cubit = context.read<DeliveryTrackingCubit>();
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    useSafeArea: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sp20(context))),
    ),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: HandoffBypassSheet(stopId: stopId, selected: selected),
    ),
  );
}

/// Neither the trader's QR nor the code could be had. The bypass is audited
/// and the supplier and trader are notified, so the server wants a reason
/// from a fixed list and a delivery photo (`bypass_requires_delivery_photo`).
class HandoffBypassSheet extends StatefulWidget {
  const HandoffBypassSheet({super.key, required this.stopId, this.selected});

  final int stopId;
  final String? selected;

  @override
  State<HandoffBypassSheet> createState() => _HandoffBypassSheetState();
}

class _HandoffBypassSheetState extends State<HandoffBypassSheet> {
  late String? reason = widget.selected;
  bool isUploading = false;

  DeliveryTrackingCubit get cubit => context.read<DeliveryTrackingCubit>();

  static bool _isDeliveryPhoto(ProofModel proof) => proof.proofType == ProofType.deliveryPhoto.apiValue;

  Future<void> addPhoto() async {
    if (isUploading) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked == null || !mounted) return;
    final stop = cubit.state.stopById(widget.stopId);
    if (stop == null) return;

    setState(() => isUploading = true);
    final result = await cubit.uploadProof(
      stop,
      file: File(picked.path),
      proofType: ProofType.deliveryPhoto,
      proofCategory: ProofCategory.delivery,
    );
    if (!mounted) return;
    setState(() => isUploading = false);
    result.fold(
      (failure) => toast(text: failure.errMessage, context: context, isSuccess: false),
      (_) => toast(text: "api_proof_uploaded".tr(), context: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeliveryTrackingCubit, DeliveryTrackingState>(
      builder: (context, state) {
        final stop = state.stopById(widget.stopId);
        if (stop == null) return const SizedBox.shrink();
        final photos = stop.proofs.where(_isDeliveryPhoto).toList();
        final canConfirm = reason != null && photos.isNotEmpty;

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppConstants.width20(context),
              AppConstants.height15(context),
              AppConstants.width20(context),
              AppConstants.height30(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SheetHandle(),
                SizedBox(height: AppConstants.height20(context)),
                Text("handoff_no_code_title".tr(), style: Styles.font18SemiBoldBlack(context)),
                SizedBox(height: AppConstants.height5(context)),
                Text("handoff_no_code_notice".tr(), style: Styles.font11MediumGrey46(context).copyWith(height: 1.5)),
                SizedBox(height: AppConstants.height20(context)),
                SheetSectionLabel(title: "handoff_no_code_reason".tr()),
                ReasonPicker(
                  reasons: {for (final value in handoffBypassReasons) value: "handoff_bypass_$value"},
                  selected: reason,
                  onSelect: (value) => setState(() => reason = value),
                ),
                SizedBox(height: AppConstants.height15(context)),
                SheetSectionLabel(
                  title: "handoff_no_code_photo".tr(),
                  trailing: Icon(
                    photos.isEmpty ? Icons.radio_button_off_rounded : Icons.check_circle_rounded,
                    size: MediaQuery.of(context).size.height * .02,
                    color: photos.isEmpty ? AppColors.neutralColor[300] : AppColors.secondaryColor,
                  ),
                ),
                ProofThumbnails(proofs: photos),
                DefaultButton(
                  text: (isUploading ? "uploading" : "take_delivery_photo").tr(),
                  backgroundColor: Colors.white,
                  textColor: AppColors.primarySwatchColor,
                  hasBorder: true,
                  borderColor: AppColors.primarySwatchColor,
                  borderRadius: AppConstants.sp15(context),
                  isEnabled: !isUploading,
                  icon: Icon(
                    Icons.add_a_photo_outlined,
                    size: MediaQuery.of(context).size.height * .02,
                    color: AppColors.primarySwatchColor,
                  ),
                  onPress: addPhoto,
                ),
                if (photos.isEmpty) ...[
                  SizedBox(height: AppConstants.height5(context)),
                  Text(
                    "api_bypass_requires_delivery_photo".tr(),
                    style: Styles.font10MediumGrey46(context).copyWith(color: AppColors.red),
                  ),
                ],
                SizedBox(height: AppConstants.height24(context)),
                DefaultButton(
                  text: "handoff_no_code_confirm".tr(),
                  gradient: AppColors.brandGradient,
                  borderRadius: AppConstants.sp15(context),
                  isEnabled: canConfirm,
                  onPress: () => Navigator.pop(context, reason),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
