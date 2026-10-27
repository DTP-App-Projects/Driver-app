import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_loading_text.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_trip_model.dart';

/// Numbers and money the way the van screens show them: tabular figures so
/// columns of quantities line up.
class VanFormat {
  const VanFormat._();

  static String qty(BuildContext context, num value) =>
      NumberFormat("#,##0.##", context.locale.languageCode).format(value);

  static String money(BuildContext context, num value) =>
      "${NumberFormat("#,##0.00", context.locale.languageCode).format(value)} ${"currency_sar".tr()}";

  static String percent(BuildContext context, num value) =>
      "${NumberFormat("#,##0.##", context.locale.languageCode).format(value)}%";

  static TextStyle tabular(TextStyle style) => style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

/// `draft` بانتظار التحميل · `on_road` في الطريق · `returning` عائد للمستودع.
class VanStatusChip extends StatelessWidget {
  const VanStatusChip({super.key, required this.status, this.onDark = false});

  final VanTripStatus status;

  /// White pill for the gradient header.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppConstants.width15(context), vertical: AppConstants.height5(context)),
      decoration: BoxDecoration(
        color: onDark ? Colors.white : status.color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppConstants.sp30(context)),
      ),
      child: Text(
        status.titleKey.tr(),
        style: Styles.font12MediumBlack(context).copyWith(color: status.color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// − qty + with the quantity typed in between, capped at [max].
class VanQtyStepper extends StatelessWidget {
  const VanQtyStepper({super.key, required this.value, required this.max, required this.onChanged});

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.height * .038;

    Widget button(IconData icon, VoidCallback? onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.sp10(context)),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xffF2F4F7) : AppColors.primarySwatchColor.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(AppConstants.sp10(context)),
        ),
        child: Icon(
          icon,
          size: size * .55,
          color: onTap == null ? AppColors.neutralColor[400] : AppColors.primarySwatchColor,
        ),
      ),
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, value > 0 ? () => onChanged(value - 1) : null),
          InkWell(
            onTap: () => _typeQty(context),
            child: SizedBox(
              width: size * 1.5,
              child: Text(
                VanFormat.qty(context, value),
                textAlign: TextAlign.center,
                style: VanFormat.tabular(Styles.font16SemiBoldBlack(context)),
              ),
            ),
          ),
          button(Icons.add_rounded, value < max ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }

  /// Long quantities are typed rather than tapped.
  Future<void> _typeQty(BuildContext context) async {
    final controller = TextEditingController(text: value == 0 ? "" : value.toString());
    final typed = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("van_enter_qty".tr(), style: Styles.font16SemiBoldBlack(context)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(helperText: "van_max_qty".tr(namedArgs: {"max": VanFormat.qty(context, max)})),
          onSubmitted: (text) => Navigator.pop(dialogContext, _parse(text)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text("cancel".tr())),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _parse(controller.text)),
            child: Text("van_ok".tr()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (typed != null) onChanged(typed.clamp(0, max));
  }

  static int? _parse(String text) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var normalized = text.trim();
    for (int i = 0; i < arabic.length; i++) {
      normalized = normalized.replaceAll(arabic[i], "$i");
    }
    return int.tryParse(normalized);
  }
}

/// Grey placeholder rows while a list loads.
class VanListSkeleton extends StatelessWidget {
  const VanListSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Column(
      children: [
        for (int i = 0; i < count; i++) ...[
          if (i != 0) SizedBox(height: AppConstants.height10(context)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppConstants.sp15(context)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
              border: Border.all(color: const Color(0xffEDEFF2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomLoadingText(width: width * .45),
                      SizedBox(height: AppConstants.height10(context)),
                      CustomLoadingText(width: width * .25),
                    ],
                  ),
                ),
                CustomLoadingText(width: width * .12, height: MediaQuery.of(context).size.height * .03),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Empty / failure block of a tab, with a retry.
class VanEmptyState extends StatelessWidget {
  const VanEmptyState({super.key, required this.icon, required this.title, this.message, this.onRetry});

  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final iconSize = MediaQuery.of(context).size.height * .08;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppConstants.height30(context)),
      child: Column(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primarySwatchColor.withValues(alpha: .08),
            ),
            child: Icon(icon, size: iconSize * .45, color: AppColors.primarySwatchColor),
          ),
          SizedBox(height: AppConstants.height15(context)),
          Text(title, textAlign: TextAlign.center, style: Styles.font16SemiBoldBlack(context)),
          if (message != null) ...[
            SizedBox(height: AppConstants.height10(context)),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Styles.font12MediumGrey46(context).copyWith(height: 1.6),
            ),
          ],
          if (onRetry != null) ...[
            SizedBox(height: AppConstants.height15(context)),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primarySwatchColor),
              label: Text(
                "refresh".tr(),
                style: Styles.font14MediumBlack(
                  context,
                ).copyWith(color: AppColors.primarySwatchColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Label · value row of a totals block.
class VanTotalRow extends StatelessWidget {
  const VanTotalRow({super.key, required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize ? Styles.font16BoldBlack(context) : Styles.font14MediumBlack(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppConstants.height5(context) * .6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: emphasize ? style : Styles.font14MediumGrey46(context))),
          Text(value, style: VanFormat.tabular(style)),
        ],
      ),
    );
  }
}

/// Button content while its request runs: a small spinner and the label.
class VanButtonBusy extends StatelessWidget {
  const VanButtonBusy({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.height * .02;
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xff707070)),
    );
  }
}
