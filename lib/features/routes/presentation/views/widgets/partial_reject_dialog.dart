import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/default_text_form_field.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';

/// Reason codes for `POST /driver/stops/{id}/partial_reject`.
const Map<String, String> partialRejectReasons = {
  "damaged_packaging": "reject_damaged_packaging",
  "expired": "reject_expired",
  "wrong_item": "reject_wrong_item",
  "quantity_mismatch": "reject_quantity_mismatch",
  "quality_issue": "reject_quality_issue",
  "other": "reject_other",
};

class PartialRejectResult {
  const PartialRejectResult({required this.quantity, required this.reason, this.notes});

  final double quantity;
  final String reason;
  final String? notes;
}

/// Asks how much of [item] the receiver refused and why. Returns null when
/// dismissed.
Future<PartialRejectResult?> showPartialRejectDialog(BuildContext context, {required StopItemModel item}) {
  return showDialog<PartialRejectResult>(
    context: context,
    builder: (dialogContext) => _PartialRejectDialog(item: item),
  );
}

class _PartialRejectDialog extends StatefulWidget {
  const _PartialRejectDialog({required this.item});

  final StopItemModel item;

  @override
  State<_PartialRejectDialog> createState() => _PartialRejectDialogState();
}

class _PartialRejectDialogState extends State<_PartialRejectDialog> {
  final TextEditingController quantity = TextEditingController();
  final TextEditingController notes = TextEditingController();
  String? reason;
  String? errorText;

  @override
  void dispose() {
    quantity.dispose();
    notes.dispose();
    super.dispose();
  }

  void submit() {
    final value = double.tryParse(quantity.text.trim().replaceAll(",", "."));
    if (value == null || value <= 0) {
      setState(() => errorText = "rejected_qty_invalid".tr());
      return;
    }
    // Counted against what was loaded at pickup, not what was ordered.
    if (value > widget.item.deliverableQty) {
      setState(() => errorText = "api_rejected_qty_exceeds_expected".tr());
      return;
    }
    if (reason == null) {
      setState(() => errorText = "reason_required".tr());
      return;
    }
    Navigator.pop(
      context,
      PartialRejectResult(
        quantity: value,
        reason: reason!,
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: AppConstants.width20(context)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.sp20(context))),
      child: Padding(
        padding: EdgeInsets.all(AppConstants.sp20(context)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("partial_reject".tr(), style: Styles.font18SemiBoldBlack(context)),
              SizedBox(height: AppConstants.height5(context)),
              Text(widget.item.productName, style: Styles.font12MediumGrey46(context)),
              SizedBox(height: AppConstants.height15(context)),
              QuantityField(label: "rejected_qty".tr(), controller: quantity, color: AppColors.red),
              SizedBox(height: AppConstants.height15(context)),
              SheetSectionLabel(title: "reason".tr()),
              ReasonPicker(
                reasons: partialRejectReasons,
                selected: reason,
                onSelect: (value) => setState(() => reason = value),
              ),
              SizedBox(height: AppConstants.height10(context)),
              DefaultTextFormField(
                controller: notes,
                textInputType: TextInputType.multiline,
                required: false,
                maxLines: 2,
                hintText: "notes_optional".tr(),
                borderRadius: AppConstants.sp10(context),
                contentPaddingVertical: AppConstants.height10(context),
                contentPaddingHorizontal: AppConstants.width10(context),
                borderSideEnabledColor: const Color(0xffEDEFF2),
              ),
              if (errorText != null) ...[
                SizedBox(height: AppConstants.height10(context)),
                Text(errorText!, style: Styles.font11MediumGrey46(context).copyWith(color: AppColors.red)),
              ],
              SizedBox(height: AppConstants.height20(context)),
              Row(
                children: [
                  Expanded(
                    child: DefaultButton(
                      onPress: () => Navigator.pop(context),
                      text: "cancel".tr(),
                      backgroundColor: Colors.white,
                      hasBorder: true,
                      borderColor: AppColors.neutralColor[300],
                      textColor: AppColors.neutralColor[700],
                    ),
                  ),
                  SizedBox(width: AppConstants.width10(context)),
                  Expanded(
                    child: DefaultButton(onPress: submit, text: "confirm".tr(), backgroundColor: AppColors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
