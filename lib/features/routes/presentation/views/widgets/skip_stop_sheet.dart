import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/default_text_form_field.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';

/// Common reasons offered as shortcuts before a stop is skipped. Picking one
/// fills the text field with its localized wording; the driver can edit it or
/// type a reason of their own.
const Map<String, String> skipReasons = {
  "branch_closed": "skip_branch_closed",
  "receiver_unavailable": "skip_receiver_unavailable",
  "access_denied": "skip_access_denied",
  "wrong_address": "skip_wrong_address",
  "vehicle_issue": "skip_vehicle_issue",
  "skipped_by_driver": "skip_other",
};

/// Longest `reason` `POST /driver/stops/{id}/skip` accepts.
const int skipReasonMaxLength = 200;

/// Asks why a stop is skipped. The reason is stored as `failure_reason` and
/// forwarded to the trader and the supplier, so it is sent as readable text,
/// not a code. Pops with that text.
class SkipStopSheet extends StatefulWidget {
  const SkipStopSheet({super.key, required this.stopName});

  final String stopName;

  @override
  State<SkipStopSheet> createState() => _SkipStopSheetState();
}

class _SkipStopSheetState extends State<SkipStopSheet> {
  final TextEditingController reason = TextEditingController();
  String? selected;

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  bool get canSubmit => reason.text.trim().isNotEmpty;

  void pick(String code) {
    setState(() {
      selected = code;
      // "Other" leaves the field to the driver; the rest prefill it.
      reason.text = code == "skipped_by_driver" ? "" : skipReasons[code]!.tr();
      reason.selection = TextSelection.collapsed(offset: reason.text.length);
    });
  }

  void submit() {
    final text = reason.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text.length > skipReasonMaxLength ? text.substring(0, skipReasonMaxLength) : text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppConstants.width20(context),
        AppConstants.height15(context),
        AppConstants.width20(context),
        AppConstants.height30(context) + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            SizedBox(height: AppConstants.height20(context)),
            Text("skip_stop".tr(), style: Styles.font16SemiBoldBlack(context)),
            SizedBox(height: AppConstants.height5(context)),
            Text(widget.stopName, style: Styles.font11MediumGrey46(context)),
            SizedBox(height: AppConstants.height15(context)),
            SheetSectionLabel(title: "skip_reason".tr()),
            ReasonPicker(reasons: skipReasons, selected: selected, onSelect: pick),
            SizedBox(height: AppConstants.height10(context)),
            SheetSectionLabel(title: "skip_reason_text".tr()),
            DefaultTextFormField(
              controller: reason,
              textInputType: TextInputType.multiline,
              required: false,
              maxLines: 2,
              maxLength: skipReasonMaxLength,
              hintText: "skip_reason_hint".tr(),
              borderRadius: AppConstants.sp15(context),
              contentPaddingVertical: AppConstants.height15(context),
              contentPaddingHorizontal: AppConstants.width15(context),
              borderSideEnabledColor: const Color(0xffEDEFF2),
              onChange: (_) => setState(() {}),
            ),
            SizedBox(height: AppConstants.height5(context)),
            Text("skip_reason_forwarded".tr(), style: Styles.font10MediumGrey46(context).copyWith(height: 1.5)),
            SizedBox(height: AppConstants.height15(context)),
            DefaultButton(
              text: "skip_stop".tr(),
              backgroundColor: AppColors.red,
              borderRadius: AppConstants.sp15(context),
              isEnabled: canSubmit,
              onPress: submit,
            ),
          ],
        ),
      ),
    );
  }
}
