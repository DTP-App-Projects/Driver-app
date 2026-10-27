import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/content_models.dart';

/// A server content page (about / terms) in the same card the about screen
/// already used for its static text.
class ContentPageBody extends StatelessWidget {
  const ContentPageBody({super.key, required this.page, required this.fallbackTitle, this.header});

  final ContentPageModel page;
  final String fallbackTitle;

  /// Optional widget above the card (the about screen's logo block).
  final Widget? header;

  /// The CMS stores HTML; without an HTML renderer in the project the tags
  /// are stripped and paragraph breaks kept.
  static String plainText(String html) {
    return html
        .replaceAll(RegExp(r"<br\s*/?>", caseSensitive: false), "\n")
        .replaceAll(RegExp(r"</(p|div|li|h[1-6]|tr)>", caseSensitive: false), "\n\n")
        .replaceAll(RegExp(r"<li[^>]*>", caseSensitive: false), "• ")
        .replaceAll(RegExp(r"<[^>]+>"), "")
        .replaceAll("&nbsp;", " ")
        .replaceAll("&amp;", "&")
        .replaceAll("&quot;", '"')
        .replaceAll("&#39;", "'")
        .replaceAll("&lt;", "<")
        .replaceAll("&gt;", ">")
        .replaceAll(RegExp(r"\n{3,}"), "\n\n")
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppConstants.width20(context),
        AppConstants.height20(context),
        AppConstants.width20(context),
        AppConstants.height30(context),
      ),
      children: [
        if (header != null) ...[header!, SizedBox(height: AppConstants.height30(context))],
        Container(
          padding: EdgeInsets.all(AppConstants.sp20(context)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
            border: Border.all(color: const Color(0xffEDEFF2)),
            boxShadow: [
              BoxShadow(
                color: AppColors.neutralColor.withValues(alpha: .04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                page.title?.isNotEmpty == true ? page.title! : fallbackTitle,
                style: Styles.font18SemiBoldBlack(context),
              ),
              SizedBox(height: AppConstants.height15(context)),
              Text(
                page.isEmpty ? "content_unavailable".tr() : plainText(page.body!),
                textAlign: TextAlign.justify,
                style: Styles.font12MediumGrey46(context).copyWith(height: 1.9),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Error state of a content screen with a retry, in the empty-state style.
class ContentErrorBody extends StatelessWidget {
  const ContentErrorBody({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final iconSize = MediaQuery.of(context).size.height * .11;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppConstants.width30(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.red.withValues(alpha: .08)),
              child: Icon(Icons.wifi_off_rounded, size: iconSize * .45, color: AppColors.red),
            ),
            SizedBox(height: AppConstants.height20(context)),
            Text(message, textAlign: TextAlign.center, style: Styles.font14MediumGrey46(context)),
            SizedBox(height: AppConstants.height20(context)),
            DefaultButton(
              onPress: onRetry,
              text: "retry".tr(),
              width: AppConstants.width30(context),
              borderRadius: AppConstants.sp15(context),
              gradient: AppColors.brandGradient,
            ),
          ],
        ),
      ),
    );
  }
}
