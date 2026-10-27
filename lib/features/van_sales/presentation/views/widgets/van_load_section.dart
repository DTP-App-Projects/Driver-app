import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/default_text_form_field.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/core/utils/validations/convert_to_english_numbers.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';
import 'package:digital_trade_portal_driver/features/van_sales/data/models/van_trip_model.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/view_models/van_trip/van_trip_cubit.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/signature_pad.dart';
import 'package:digital_trade_portal_driver/features/van_sales/presentation/views/widgets/van_widgets.dart';

/// Status `draft`: the driver checks the loaded items and enters the 6-digit
/// load code from the warehouse keeper, optionally with a signature.
class VanLoadSection extends StatefulWidget {
  const VanLoadSection({super.key, required this.trip, required this.header});

  final VanTripModel trip;
  final Widget header;

  @override
  State<VanLoadSection> createState() => _VanLoadSectionState();
}

class _VanLoadSectionState extends State<VanLoadSection> {
  final TextEditingController code = TextEditingController();
  final TextEditingController signerName = TextEditingController();
  final SignatureController signature = SignatureController();
  String? error;

  @override
  void dispose() {
    code.dispose();
    signerName.dispose();
    signature.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final value = ArabicToEnglishNumberFormatter().convertArabicToEnglishNumbers(code.text.trim());
    if (!RegExp(r"^\d{6}$").hasMatch(value)) {
      setState(() => error = "van_load_code_required".tr());
      return;
    }
    setState(() => error = null);
    FocusScope.of(context).unfocus();

    final file = await signature.toPngFile();
    if (!mounted) return;
    final result = await context.read<VanTripCubit>().confirmLoad(
      loadCode: value,
      signature: file,
      signerName: signerName.text,
    );
    if (!mounted) return;
    result.fold((failure) => setState(() => error = failure.errMessage), (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final bool isBusy = context.select<VanTripCubit, bool>((cubit) => cubit.state.isBusy(VanTripAction.load));

    return RefreshIndicator(
      color: AppColors.primarySwatchColor,
      onRefresh: () => context.read<VanTripCubit>().loadTrip(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: AppConstants.height30(context)),
        children: [
          widget.header,
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppConstants.width20(context),
              AppConstants.height20(context),
              AppConstants.width20(context),
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("van_load_hint".tr(), style: Styles.font12MediumGrey46(context).copyWith(height: 1.6)),
                SizedBox(height: AppConstants.height15(context)),
                SheetSectionLabel(title: "van_loaded_items".tr()),
                SheetCard(
                  child: Column(
                    children: [
                      for (int i = 0; i < widget.trip.lines.length; i++) ...[
                        if (i != 0) const Divider(color: Color(0xffF0F2F5)),
                        _buildLine(context, widget.trip.lines[i]),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: AppConstants.height20(context)),
                SheetSectionLabel(title: "van_load_code".tr()),
                _buildCodeField(context),
                SizedBox(height: AppConstants.height15(context)),
                SheetSectionLabel(
                  title: "van_signature_optional".tr(),
                  trailing: TextButton(
                    onPressed: signature.clear,
                    child: Text(
                      "van_clear".tr(),
                      style: Styles.font12BoldBlack(context).copyWith(color: AppColors.primarySwatchColor),
                    ),
                  ),
                ),
                SheetCard(
                  padding: EdgeInsets.all(AppConstants.sp10(context)),
                  child: SignaturePad(controller: signature, height: MediaQuery.of(context).size.height * .18),
                ),
                SizedBox(height: AppConstants.height10(context)),
                DefaultTextFormField(
                  controller: signerName,
                  textInputType: TextInputType.name,
                  required: false,
                  hintText: "van_signer_name".tr(),
                  borderRadius: AppConstants.sp15(context),
                  borderSideEnabledColor: const Color(0xffEDEFF2),
                  fillColor: Colors.white,
                  isFilled: true,
                ),
                if (error != null) ...[
                  SizedBox(height: AppConstants.height15(context)),
                  SheetErrorBox(message: error!),
                ],
                SizedBox(height: AppConstants.height20(context)),
                DefaultButton(
                  text: "van_confirm_load".tr(),
                  gradient: AppColors.brandGradient,
                  borderRadius: AppConstants.sp15(context),
                  isEnabled: !isBusy,
                  icon: isBusy ? const VanButtonBusy() : null,
                  onPress: submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLine(BuildContext context, VanTripLine line) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppConstants.height5(context)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: Styles.font14MediumBlack(context)),
                SizedBox(height: AppConstants.height5(context) * .6),
                Text(
                  "${"van_unit_price".tr()}: ${VanFormat.money(context, line.unitPrice)}",
                  style: VanFormat.tabular(Styles.font11MediumGrey46(context)),
                ),
              ],
            ),
          ),
          Text(VanFormat.qty(context, line.loaded), style: VanFormat.tabular(Styles.font16BoldBlack(context))),
        ],
      ),
    );
  }

  Widget _buildCodeField(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: PinCodeTextField(
        appContext: context,
        length: 6,
        controller: code,
        keyboardType: TextInputType.number,
        animationType: AnimationType.fade,
        cursorColor: AppColors.primarySwatchColor,
        textStyle: VanFormat.tabular(Styles.font16SemiBoldBlack(context)),
        pinTheme: PinTheme(
          shape: PinCodeFieldShape.box,
          borderRadius: BorderRadius.circular(AppConstants.sp10(context)),
          fieldHeight: MediaQuery.of(context).size.height * .055,
          fieldWidth: MediaQuery.of(context).size.width * .11,
          activeFillColor: Colors.white,
          inactiveFillColor: Colors.white,
          selectedFillColor: Colors.white,
          activeColor: AppColors.primarySwatchColor,
          inactiveColor: const Color(0xffEDEFF2),
          selectedColor: AppColors.primarySwatchColor,
        ),
        enableActiveFill: true,
        onChanged: (_) {},
      ),
    );
  }
}
