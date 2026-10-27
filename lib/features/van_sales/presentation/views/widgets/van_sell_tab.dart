import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/default_text_form_field.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/core/utils/validations/convert_to_english_numbers.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_sale_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_trip_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/view_models/van_trip/van_trip_cubit.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/van_sale_receipt_view.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_widgets.dart';

/// Walk-in sale to a shop that is not registered. Prices are before VAT; the
/// server adds VAT and the receipt shows the server's totals.
class VanSellTab extends StatefulWidget {
  const VanSellTab({super.key});

  @override
  State<VanSellTab> createState() => _VanSellTabState();
}

class _VanSellTabState extends State<VanSellTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController buyerName = TextEditingController();
  final TextEditingController buyerPhone = TextEditingController();
  final TextEditingController buyerVat = TextEditingController();
  final TextEditingController discount = TextEditingController();

  /// sku id → quantity picked.
  final Map<int, int> quantities = {};
  VanPaymentMethod paymentMethod = VanPaymentMethod.cash;
  String? error;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    buyerName.dispose();
    buyerPhone.dispose();
    buyerVat.dispose();
    discount.dispose();
    super.dispose();
  }

  String _digits(String text) =>
      ArabicToEnglishNumberFormatter().convertArabicToEnglishNumbers(text).replaceAll(RegExp(r"\s"), "");

  double get discountPercent => double.tryParse(_digits(discount.text)) ?? 0;

  /// Picked quantities, clamped to what is on the van now (a refresh may
  /// have lowered it).
  List<(VanTripLine, int)> _picked(VanTripModel trip) => [
    for (final line in trip.sellableLines)
      if ((quantities[line.skuId] ?? 0) > 0) (line, (quantities[line.skuId]!).clamp(0, line.inVan.floor())),
  ];

  void _reset() {
    buyerName.clear();
    buyerPhone.clear();
    buyerVat.clear();
    discount.clear();
    quantities.clear();
    paymentMethod = VanPaymentMethod.cash;
    error = null;
  }

  Future<void> submit(VanTripModel trip) async {
    final name = buyerName.text.trim();
    final phone = _digits(buyerPhone.text);
    final vat = _digits(buyerVat.text);
    final picked = _picked(trip).where((entry) => entry.$2 > 0).toList();

    String? problem;
    if (name.isEmpty) {
      problem = "van_buyer_name_required".tr();
    } else if (vat.isNotEmpty && !RegExp(r"^\d{15}$").hasMatch(vat)) {
      problem = "van_vat_invalid".tr();
    } else if (discountPercent < 0 || discountPercent > trip.maxDiscountPercent) {
      problem = "van_discount_above_limit".tr(namedArgs: {"max": VanFormat.percent(context, trip.maxDiscountPercent)});
    } else if (picked.isEmpty) {
      problem = "van_pick_items".tr();
    }
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    setState(() => error = null);
    FocusScope.of(context).unfocus();

    final outcome = await context.read<VanTripCubit>().recordSale(
      buyerName: name,
      buyerPhone: phone.isEmpty ? null : phone,
      buyerVatNo: vat.isEmpty ? null : vat,
      paymentMethod: paymentMethod,
      discountPercent: discountPercent,
      lines: [
        for (final (line, qty) in picked)
          VanSaleRequestLine(skuId: line.skuId, qty: qty.toDouble(), name: line.name, unitPrice: line.unitPrice),
      ],
    );
    if (!mounted) return;

    if (outcome.failure != null) {
      setState(() => error = outcome.failure!.errMessage);
      return;
    }
    setState(_reset);
    final sale = outcome.sale;
    if (sale != null) {
      NavigationUtils.navigateTo(
        context: context,
        destinationScreen: VanSaleReceiptView(sale: sale),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<VanTripCubit, VanTripState>(
      builder: (context, state) {
        final trip = state.trip;
        if (trip == null) return const SizedBox.shrink();
        final lines = trip.sellableLines;
        final bool isBusy = state.isBusy(VanTripAction.sale);

        if (lines.isEmpty) {
          return ListView(
            padding: EdgeInsets.all(AppConstants.sp20(context)),
            children: [VanEmptyState(icon: Icons.inventory_2_outlined, title: "van_nothing_to_sell".tr())],
          );
        }

        final subtotal = _picked(trip).fold<double>(0, (sum, entry) => sum + entry.$1.unitPrice * entry.$2);
        final discountValue = subtotal * discountPercent.clamp(0, trip.maxDiscountPercent) / 100;

        return ListView(
          padding: EdgeInsets.all(AppConstants.sp20(context)),
          children: [
            SheetSectionLabel(title: "van_buyer".tr()),
            _field(context, buyerName, "van_buyer_name".tr(), TextInputType.name),
            SizedBox(height: AppConstants.height10(context)),
            _field(
              context,
              buyerPhone,
              "van_buyer_phone".tr(),
              TextInputType.phone,
              formatter: [ArabicToEnglishNumberFormatter(), FilteringTextInputFormatter.digitsOnly],
              ltr: true,
            ),
            SizedBox(height: AppConstants.height10(context)),
            _field(
              context,
              buyerVat,
              "van_buyer_vat".tr(),
              TextInputType.number,
              formatter: [
                ArabicToEnglishNumberFormatter(),
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ],
              ltr: true,
            ),
            SizedBox(height: AppConstants.height20(context)),
            SheetSectionLabel(title: "van_payment_method".tr()),
            Row(
              children: [
                for (final method in VanPaymentMethod.values) ...[
                  if (method != VanPaymentMethod.values.first) SizedBox(width: AppConstants.width10(context)),
                  ChoiceChip(
                    label: Text(method.titleKey.tr()),
                    selected: paymentMethod == method,
                    showCheckmark: false,
                    selectedColor: AppColors.primarySwatchColor.withValues(alpha: .12),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: paymentMethod == method ? AppColors.primarySwatchColor : const Color(0xffEDEFF2),
                    ),
                    labelStyle: Styles.font14MediumBlack(context).copyWith(
                      color: paymentMethod == method ? AppColors.primarySwatchColor : AppColors.grey46,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => setState(() => paymentMethod = method),
                  ),
                ],
              ],
            ),
            if (trip.maxDiscountPercent > 0) ...[
              SizedBox(height: AppConstants.height20(context)),
              SheetSectionLabel(
                title: "van_discount_percent".tr(
                  namedArgs: {"max": VanFormat.percent(context, trip.maxDiscountPercent)},
                ),
              ),
              _field(
                context,
                discount,
                "0",
                const TextInputType.numberWithOptions(decimal: true),
                formatter: [ArabicToEnglishNumberFormatter()],
                ltr: true,
                onChanged: (_) => setState(() {}),
              ),
            ],
            SizedBox(height: AppConstants.height20(context)),
            SheetSectionLabel(title: "van_items".tr()),
            for (final line in lines) ...[_buildLine(context, line), SizedBox(height: AppConstants.height10(context))],
            SizedBox(height: AppConstants.height10(context)),
            SheetCard(
              child: Column(
                children: [
                  VanTotalRow(label: "van_subtotal".tr(), value: VanFormat.money(context, subtotal)),
                  if (discountValue > 0)
                    VanTotalRow(label: "van_discount".tr(), value: "− ${VanFormat.money(context, discountValue)}"),
                  VanTotalRow(
                    label: "van_total_before_vat".tr(),
                    value: VanFormat.money(context, subtotal - discountValue),
                    emphasize: true,
                  ),
                  SizedBox(height: AppConstants.height5(context)),
                  Text("van_vat_added_note".tr(), style: Styles.font11MediumGrey46(context)),
                ],
              ),
            ),
            if (error != null) ...[SizedBox(height: AppConstants.height15(context)), SheetErrorBox(message: error!)],
            SizedBox(height: AppConstants.height20(context)),
            DefaultButton(
              text: "van_record_sale".tr(),
              gradient: AppColors.brandGradient,
              borderRadius: AppConstants.sp15(context),
              isEnabled: !isBusy,
              icon: isBusy ? const VanButtonBusy() : null,
              onPress: () => submit(trip),
            ),
          ],
        );
      },
    );
  }

  Widget _field(
    BuildContext context,
    TextEditingController controller,
    String hint,
    TextInputType type, {
    List<TextInputFormatter>? formatter,
    bool ltr = false,
    ValueChanged<String>? onChanged,
  }) {
    final field = DefaultTextFormField(
      controller: controller,
      textInputType: type,
      required: false,
      maxLines: 1,
      hintText: hint,
      borderRadius: AppConstants.sp15(context),
      borderSideEnabledColor: const Color(0xffEDEFF2),
      fillColor: Colors.white,
      isFilled: true,
      formatter: formatter,
      style: VanFormat.tabular(Styles.font14MediumBlack(context)),
      onChange: onChanged,
    );
    return ltr ? Directionality(textDirection: TextDirection.ltr, child: field) : field;
  }

  Widget _buildLine(BuildContext context, VanTripLine line) {
    final max = line.inVan.floor();
    final value = (quantities[line.skuId] ?? 0).clamp(0, max);

    return SheetCard(
      highlight: false,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: Styles.font14MediumBlack(context)),
                SizedBox(height: AppConstants.height5(context) * .6),
                Text(
                  "${VanFormat.money(context, line.unitPrice)} · ${"van_in_van".tr()} ${VanFormat.qty(context, line.inVan)}",
                  style: VanFormat.tabular(Styles.font11MediumGrey46(context)),
                ),
              ],
            ),
          ),
          VanQtyStepper(value: value, max: max, onChanged: (qty) => setState(() => quantities[line.skuId] = qty)),
        ],
      ),
    );
  }
}
