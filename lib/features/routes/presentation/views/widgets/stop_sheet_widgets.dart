// intl (re-exported by easy_localization) ships its own TextDirection enum.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/code_scanner_view.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/default_cached_network_image.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/default_text_form_field.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/core/utils/tr_or.dart';
import 'package:digital_trade_portal_driver/core/utils/validations/convert_to_english_numbers.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/delivery_tracking/delivery_tracking_cubit.dart';

/// Small building blocks shared by the pickup, delivery and skip sheets so
/// they read like the existing stop sheet.

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * .12,
        height: MediaQuery.of(context).size.height * .005,
        decoration: BoxDecoration(
          color: AppColors.neutralColor[200],
          borderRadius: BorderRadius.circular(AppConstants.sp30(context)),
        ),
      ),
    );
  }
}

/// Caption above a group of fields, same style as the report form labels.
class SheetSectionLabel extends StatelessWidget {
  const SheetSectionLabel({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: AppConstants.width5(context), bottom: AppConstants.height10(context)),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Styles.font12BoldBlack(context).copyWith(color: AppColors.grey46)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// White rounded card used for each block of a sheet.
class SheetCard extends StatelessWidget {
  const SheetCard({super.key, required this.child, this.highlight = false, this.padding});

  final Widget child;

  /// Danger border, for a line the server rejected.
  final bool highlight;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(AppConstants.sp15(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: highlight ? AppColors.red : const Color(0xffEDEFF2), width: highlight ? 1.4 : 1),
      ),
      child: child,
    );
  }
}

/// Compact numeric input for a quantity, with its caption on top.
class QuantityField extends StatelessWidget {
  const QuantityField({super.key, required this.label, required this.controller, this.onChanged, this.color});

  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Styles.font10MediumGrey46(context)),
        SizedBox(height: AppConstants.height5(context) * .6),
        DefaultTextFormField(
          controller: controller,
          textInputType: const TextInputType.numberWithOptions(decimal: true),
          required: false,
          maxLines: 1,
          hintText: "0",
          borderRadius: AppConstants.sp10(context),
          contentPaddingVertical: AppConstants.height10(context),
          contentPaddingHorizontal: AppConstants.width10(context),
          borderSideEnabledColor: color?.withValues(alpha: .4) ?? const Color(0xffEDEFF2),
          style: Styles.font14BoldBlack(context).copyWith(color: color),
          // Arabic keyboards type Arabic-Indic digits; the parser needs ASCII.
          formatter: [ArabicToEnglishNumberFormatter()],
          onChange: onChanged,
        ),
      ],
    );
  }
}

/// Small pill, e.g. "expected 10" or a barcode / sync status.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.width10(context),
        vertical: AppConstants.height5(context) * .6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppConstants.sp30(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: MediaQuery.of(context).size.height * .014, color: color),
            SizedBox(width: AppConstants.width5(context) * .6),
          ],
          Text(
            text,
            style: Styles.font10MediumBlack(context).copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// SKU code and the package barcode the supplier saved, under an item name.
/// The barcode is what a scan must produce; it is shown so the driver can
/// compare it by eye and type it when the camera is unavailable.
class ItemCodesLine extends StatelessWidget {
  const ItemCodesLine({super.key, required this.item});

  final StopItemModel item;

  @override
  Widget build(BuildContext context) {
    final code = item.sku?.code;
    final barcode = item.barcode;
    if (code == null && barcode == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: AppConstants.height5(context) * .6),
      child: Wrap(
        spacing: AppConstants.width10(context),
        runSpacing: AppConstants.height5(context) * .4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (code != null)
            Text("SKU $code", textDirection: TextDirection.ltr, style: Styles.font10MediumGrey46(context)),
          if (barcode != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_2_rounded, size: MediaQuery.of(context).size.height * .015, color: AppColors.grey46),
                SizedBox(width: AppConstants.width5(context) * .6),
                Text(
                  "expected_barcode".tr(namedArgs: {"barcode": barcode}),
                  textDirection: TextDirection.ltr,
                  style: Styles.font10MediumGrey46(context).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Scan-or-type input that verifies one barcode against the stop through
/// `POST /stops/{id}/barcode/verify`. The server decides: a match flags the
/// line it names (its pill turns green), a mismatch lists the codes the stop
/// expected. The last outcome stays under the field.
class BarcodeVerifyField extends StatefulWidget {
  const BarcodeVerifyField({super.key, required this.stop});

  final RouteStop stop;

  @override
  State<BarcodeVerifyField> createState() => _BarcodeVerifyFieldState();
}

class _BarcodeVerifyFieldState extends State<BarcodeVerifyField> {
  final TextEditingController controller = TextEditingController();
  bool isVerifying = false;

  /// Text and colour of the last outcome, shown under the field.
  String? resultText;
  bool resultOk = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> scan() async {
    final code = await scanCode(context, title: "scan_barcode".tr(), hint: "scan_barcode_hint".tr());
    if (code == null || !mounted) return;
    controller.text = code;
    await verify();
  }

  Future<void> verify() async {
    final code = controller.text.trim();
    if (code.isEmpty || isVerifying) return;
    FocusScope.of(context).unfocus();
    setState(() => isVerifying = true);

    final cubit = context.read<DeliveryTrackingCubit>();
    final result = await cubit.verifyBarcode(widget.stop, code);
    if (!mounted) return;
    setState(() => isVerifying = false);

    result.fold((failure) => toast(text: failure.errMessage, context: context, isSuccess: false), (outcome) {
      // HTTP 200 for both outcomes: only the flag says whether it matched.
      if (outcome.success) {
        final stop = cubit.state.stopById(widget.stop.id) ?? widget.stop;
        final item = stop.items.where((line) => line.id == outcome.itemId).firstOrNull;
        controller.clear();
        setState(() {
          resultOk = true;
          resultText = item == null
              ? "barcode_matched".tr()
              : "barcode_matched_item".tr(namedArgs: {"item": item.productName});
        });
        return;
      }
      final expected = outcome.expectedBarcodes.isNotEmpty
          ? outcome.expectedBarcodes
          : [for (final item in widget.stop.items) ?item.barcode];
      setState(() {
        resultOk = false;
        resultText = expected.isEmpty
            ? "api_barcode_mismatch".tr()
            : "barcode_mismatch_expected".tr(namedArgs: {"barcodes": expected.join(", ")});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DefaultTextFormField(
                controller: controller,
                textInputType: TextInputType.text,
                required: false,
                maxLines: 1,
                hintText: "barcode_hint".tr(),
                borderRadius: AppConstants.sp15(context),
                contentPaddingVertical: AppConstants.height15(context),
                contentPaddingHorizontal: AppConstants.width15(context),
                borderSideEnabledColor: const Color(0xffEDEFF2),
                prefixIcon: IconButton(
                  onPressed: scan,
                  tooltip: "scan_barcode".tr(),
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primarySwatchColor),
                ),
                // Arabic keyboards type Arabic-Indic digits; EAN codes are ASCII.
                formatter: [ArabicToEnglishNumberFormatter()],
                onFilledSubmit: (_) => verify(),
              ),
            ),
            SizedBox(width: AppConstants.width10(context)),
            DefaultButton(
              text: "verify".tr(),
              width: AppConstants.width15(context),
              borderRadius: AppConstants.sp15(context),
              isEnabled: !isVerifying,
              onPress: verify,
            ),
          ],
        ),
        if (resultText != null) ...[
          SizedBox(height: AppConstants.height5(context)),
          Row(
            children: [
              Icon(
                resultOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: MediaQuery.of(context).size.height * .018,
                color: resultOk ? AppColors.secondaryColor : AppColors.red,
              ),
              SizedBox(width: AppConstants.width5(context)),
              Expanded(
                child: Text(
                  resultText!,
                  style: Styles.font11MediumGrey46(
                    context,
                  ).copyWith(color: resultOk ? AppColors.secondaryColor : AppColors.red, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Seal numbers as removable chips plus an input to add the next one.
class SealsInput extends StatefulWidget {
  const SealsInput({super.key, required this.seals, required this.onChanged, this.expected = const []});

  final List<String> seals;
  final ValueChanged<List<String>> onChanged;

  /// Seals recorded at pickup, shown as a hint at the delivery point.
  final List<String> expected;

  @override
  State<SealsInput> createState() => _SealsInputState();
}

class _SealsInputState extends State<SealsInput> {
  final TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void add() {
    final value = controller.text.trim();
    if (value.isEmpty || widget.seals.contains(value)) return;
    widget.onChanged([...widget.seals, value]);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.expected.isNotEmpty) ...[
          Text(
            "expected_seals".tr(namedArgs: {"seals": widget.expected.join(", ")}),
            style: Styles.font11MediumGrey46(context),
          ),
          SizedBox(height: AppConstants.height10(context)),
        ],
        if (widget.seals.isNotEmpty) ...[
          Wrap(
            spacing: AppConstants.width5(context),
            runSpacing: AppConstants.height5(context),
            children: [
              for (final seal in widget.seals)
                Chip(
                  label: Text(seal, style: Styles.font11BoldBlack(context)),
                  backgroundColor: AppColors.primarySwatchColor.withValues(alpha: .08),
                  side: BorderSide.none,
                  deleteIcon: Icon(Icons.close_rounded, size: MediaQuery.of(context).size.height * .016),
                  onDeleted: () => widget.onChanged([...widget.seals]..remove(seal)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          SizedBox(height: AppConstants.height10(context)),
        ],
        Row(
          children: [
            Expanded(
              child: DefaultTextFormField(
                controller: controller,
                textInputType: TextInputType.text,
                required: false,
                maxLines: 1,
                hintText: "seal_number_hint".tr(),
                borderRadius: AppConstants.sp10(context),
                contentPaddingVertical: AppConstants.height10(context),
                contentPaddingHorizontal: AppConstants.width10(context),
                borderSideEnabledColor: const Color(0xffEDEFF2),
                onFilledSubmit: (_) => add(),
              ),
            ),
            SizedBox(width: AppConstants.width10(context)),
            IconButton.filled(
              onPressed: add,
              style: IconButton.styleFrom(backgroundColor: AppColors.primarySwatchColor),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}

/// Inline error block listing what the server refused.
class SheetErrorBox extends StatelessWidget {
  const SheetErrorBox({super.key, required this.message, this.lines = const []});

  final String message;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppConstants.sp15(context)),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(AppConstants.sp15(context)),
        border: Border.all(color: AppColors.red.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Styles.font12MediumBlack(context).copyWith(color: AppColors.red, fontWeight: FontWeight.w700),
          ),
          for (final line in lines.take(6)) ...[
            SizedBox(height: AppConstants.height5(context) * .6),
            Text("• $line", style: Styles.font11MediumGrey46(context)),
          ],
        ],
      ),
    );
  }
}

/// Dropdown of reason codes rendered through the app's radio style list.
class ReasonPicker extends StatelessWidget {
  const ReasonPicker({super.key, required this.reasons, required this.selected, required this.onSelect});

  /// Reason code → translation key.
  final Map<String, String> reasons;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in reasons.entries) ...[
          InkWell(
            onTap: () => onSelect(entry.key),
            borderRadius: BorderRadius.circular(AppConstants.sp15(context)),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.width15(context),
                vertical: AppConstants.height10(context),
              ),
              decoration: BoxDecoration(
                color: selected == entry.key ? AppColors.primarySwatchColor.withValues(alpha: .06) : Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.sp15(context)),
                border: Border.all(
                  color: selected == entry.key ? AppColors.primarySwatchColor : const Color(0xffEDEFF2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(entry.value.tr(), style: Styles.font12MediumBlack(context))),
                  Icon(
                    selected == entry.key ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: MediaQuery.of(context).size.height * .022,
                    color: selected == entry.key ? AppColors.primarySwatchColor : AppColors.neutralColor[300],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: AppConstants.height5(context)),
        ],
      ],
    );
  }
}

/// One line per item the server pointed at, in the driver's language:
/// "product: reason". Falls back to the generic item text when the
/// reason code has no translation, never to the raw English server text.
List<String> itemErrorLines(Failure? failure, RouteStop stop) {
  if (failure == null) return const [];
  return [
    for (final entry in failure.itemErrors.entries)
      "${stop.items.where((item) => item.id == entry.key).firstOrNull?.productName ?? "#${entry.key}"}: "
          "${entry.value == null ? tr("item_needs_attention") : trOr("api_${entry.value}", tr("item_needs_attention"))}",
  ];
}

/// Pictures already attached to the stop, shown from the `file_url` the
/// proof endpoint returned (never built from `file_path`).
class ProofThumbnails extends StatelessWidget {
  const ProofThumbnails({super.key, required this.proofs});

  final List<ProofModel> proofs;

  @override
  Widget build(BuildContext context) {
    final urls = [for (final proof in proofs) ?proof.displayUrl];
    if (urls.isEmpty) return const SizedBox.shrink();
    final side = MediaQuery.of(context).size.width * .17;

    return Padding(
      padding: EdgeInsets.only(bottom: AppConstants.height10(context)),
      child: Wrap(
        spacing: AppConstants.width10(context),
        runSpacing: AppConstants.height10(context),
        children: [
          for (final url in urls)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.sp10(context)),
              child: DefaultCachedNetworkImage(imageUrl: url, imageWidth: side, imageHeight: side, fit: BoxFit.cover),
            ),
        ],
      ),
    );
  }
}
