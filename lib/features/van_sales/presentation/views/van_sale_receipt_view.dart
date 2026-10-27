import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_sale_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_widgets.dart';

/// Receipt of a walk-in sale: invoice number, the server's totals, the ZATCA
/// QR and the share link (opens without logging in).
class VanSaleReceiptView extends StatelessWidget {
  const VanSaleReceiptView({super.key, required this.sale});

  final VanSaleModel sale;

  /// Saudi mobiles typed as `05…` / `5…` become `9665…` for wa.me.
  static String? _internationalPhone(String? phone) {
    if (phone == null) return null;
    var digits = phone.replaceAll(RegExp(r"\D"), "");
    if (digits.isEmpty) return null;
    if (digits.startsWith("00")) digits = digits.substring(2);
    if (digits.startsWith("05") && digits.length == 10) return "966${digits.substring(1)}";
    if (digits.startsWith("5") && digits.length == 9) return "966$digits";
    return digits;
  }

  String _shareText(String url) =>
      "van_share_text".tr(namedArgs: {"invoice": sale.invoice?.invoiceNo ?? "", "url": url});

  Future<void> _open(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!opened && context.mounted) toast(context: context, text: "van_share_failed".tr(), isSuccess: false);
  }

  Future<void> _shareWhatsApp(BuildContext context, String url) {
    final phone = _internationalPhone(sale.buyerPhone);
    return _open(context, Uri.https("wa.me", phone == null ? "/" : "/$phone", {"text": _shareText(url)}));
  }

  Future<void> _shareSms(BuildContext context, String url) {
    return _open(context, Uri(scheme: "sms", path: sale.buyerPhone ?? "", queryParameters: {"body": _shareText(url)}));
  }

  @override
  Widget build(BuildContext context) {
    final invoice = sale.invoice;
    final shareUrl = invoice?.shareUrl;
    final qrSize = MediaQuery.of(context).size.width * .5;

    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(title: "van_receipt".tr()),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppConstants.width20(context),
                  AppConstants.height10(context),
                  AppConstants.width20(context),
                  AppConstants.height30(context),
                ),
                children: [
                  SheetCard(
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primarySwatchColor,
                          size: MediaQuery.of(context).size.height * .06,
                        ),
                        SizedBox(height: AppConstants.height10(context)),
                        Text(
                          invoice?.title ?? "van_simplified_invoice".tr(),
                          textAlign: TextAlign.center,
                          style: Styles.font16SemiBoldBlack(context),
                        ),
                        if (invoice != null) ...[
                          SizedBox(height: AppConstants.height5(context)),
                          Text(
                            invoice.invoiceNo,
                            textDirection: TextDirection.ltr,
                            style: VanFormat.tabular(Styles.font14BoldBlack(context)),
                          ),
                        ],
                        SizedBox(height: AppConstants.height15(context)),
                        Text(
                          VanFormat.money(context, sale.grandTotal),
                          style: VanFormat.tabular(
                            Styles.font24BoldBlack(context).copyWith(color: AppColors.primarySwatchColor),
                          ),
                        ),
                        SizedBox(height: AppConstants.height5(context)),
                        Text(
                          "${sale.buyerName} · ${sale.paymentMethod.titleKey.tr()}",
                          textAlign: TextAlign.center,
                          style: Styles.font12MediumGrey46(context),
                        ),
                        if (invoice?.zatcaQr != null && invoice!.zatcaQr!.isNotEmpty) ...[
                          SizedBox(height: AppConstants.height20(context)),
                          QrImageView(
                            data: invoice.zatcaQr!,
                            size: qrSize,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: AppConstants.height15(context)),
                  SheetSectionLabel(title: "van_items".tr()),
                  SheetCard(
                    child: Column(
                      children: [
                        for (final line in sale.lines)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: AppConstants.height5(context)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(line.name, style: Styles.font14MediumBlack(context)),
                                      Text(
                                        "${VanFormat.qty(context, line.qty)} × ${VanFormat.money(context, line.unitPrice)}",
                                        style: VanFormat.tabular(Styles.font11MediumGrey46(context)),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  VanFormat.money(context, line.lineTotal),
                                  style: VanFormat.tabular(Styles.font14MediumBlack(context)),
                                ),
                              ],
                            ),
                          ),
                        const Divider(color: Color(0xffF0F2F5)),
                        VanTotalRow(label: "van_subtotal".tr(), value: VanFormat.money(context, sale.subtotal)),
                        VanTotalRow(label: "van_vat".tr(), value: VanFormat.money(context, sale.taxTotal)),
                        VanTotalRow(
                          label: "van_grand_total".tr(),
                          value: VanFormat.money(context, sale.grandTotal),
                          emphasize: true,
                        ),
                      ],
                    ),
                  ),
                  if (shareUrl != null && shareUrl.isNotEmpty) ...[
                    SizedBox(height: AppConstants.height20(context)),
                    DefaultButton(
                      text: "van_share_whatsapp".tr(),
                      backgroundColor: const Color(0xff25D366),
                      borderRadius: AppConstants.sp15(context),
                      icon: Icon(
                        Icons.chat_rounded,
                        color: Colors.white,
                        size: MediaQuery.of(context).size.height * .022,
                      ),
                      onPress: () => _shareWhatsApp(context, shareUrl),
                    ),
                    SizedBox(height: AppConstants.height10(context)),
                    Row(
                      children: [
                        Expanded(
                          child: DefaultButton(
                            text: "van_share_sms".tr(),
                            backgroundColor: Colors.white,
                            textColor: AppColors.primarySwatchColor,
                            hasBorder: true,
                            borderColor: AppColors.primarySwatchColor,
                            borderRadius: AppConstants.sp15(context),
                            onPress: () => _shareSms(context, shareUrl),
                          ),
                        ),
                        SizedBox(width: AppConstants.width10(context)),
                        Expanded(
                          child: DefaultButton(
                            text: "van_copy_link".tr(),
                            backgroundColor: Colors.white,
                            textColor: AppColors.primarySwatchColor,
                            hasBorder: true,
                            borderColor: AppColors.primarySwatchColor,
                            borderRadius: AppConstants.sp15(context),
                            onPress: () async {
                              await Clipboard.setData(ClipboardData(text: shareUrl));
                              if (context.mounted) toast(context: context, text: "van_link_copied".tr());
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
