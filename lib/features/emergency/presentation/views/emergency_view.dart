import 'dart:io';

import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_dropdown_formfield.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/default_text_form_field.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/emergency/data/models/issue_type.dart';
import 'package:digital_trade_portal_driver/features/emergency/presentation/views/widgets/attachments_picker.dart';
import 'package:digital_trade_portal_driver/features/emergency/presentation/views/widgets/issue_type_grid.dart';

class EmergencyView extends StatefulWidget {
  const EmergencyView({super.key});

  @override
  State<EmergencyView> createState() => _EmergencyViewState();
}

class _EmergencyViewState extends State<EmergencyView> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController description = TextEditingController();
  final List<File> images = [];

  IssueType? selectedType;
  IssueSeverity severity = IssueSeverity.medium;

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 70);
    if (picked.isEmpty) return;

    setState(() => images.addAll(picked.map((file) => File(file.path))));
  }

  void submit() {
    FocusScope.of(context).unfocus();

    if (selectedType == null) {
      toast(text: "select_issue_type".tr(), context: context, isSuccess: false);
      return;
    }
    if (!formKey.currentState!.validate()) return;

    // TODO: post the report once the endpoint exists.
    toast(text: "report_sent".tr(), context: context);
    NavigationUtils.navigateBack(context: context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F7FA),
          body: SafeArea(
            child: Column(
              children: [
                CustomAppBar(title: "report_issue".tr()),
                Expanded(child: _buildForm(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppConstants.width20(context),
          AppConstants.height5(context),
          AppConstants.width20(context),
          AppConstants.height30(context),
        ),
        children: [
          _SectionLabel(title: "issue_type".tr()),
          IssueTypeGrid(
            selected: selectedType,
            onSelect: (type) => setState(() => selectedType = type),
          ),
          SizedBox(height: AppConstants.height24(context)),
          _SectionLabel(title: "severity".tr()),
          _buildSeverityField(context),
          SizedBox(height: AppConstants.height24(context)),
          _SectionLabel(title: "description".tr()),
          DefaultTextFormField(
            controller: description,
            textInputType: TextInputType.multiline,
            maxLines: 5,
            hintText: "description_hint".tr(),
            validationMsg: "description_required".tr(),
            borderRadius: AppConstants.sp20(context),
            contentPaddingVertical: AppConstants.height15(context),
            contentPaddingHorizontal: AppConstants.width15(context),
            borderSideEnabledColor: const Color(0xffEDEFF2),
          ),
          SizedBox(height: AppConstants.height24(context)),
          _SectionLabel(title: "photos_optional".tr()),
          AttachmentsPicker(
            images: images,
            onAdd: pickImages,
            onRemove: (index) => setState(() => images.removeAt(index)),
          ),
          SizedBox(height: AppConstants.height30(context)),
          SizedBox(
            width: double.infinity,
            child: DefaultButton(
              onPress: submit,
              text: "send_report".tr(),
              borderRadius: AppConstants.sp15(context),
              gradient: AppColors.brandGradient,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityField(BuildContext context) {
    return CustomDropDownButton(
      hintText: "severity".tr(),
      value: severity.titleKey.tr(),
      items: IssueSeverity.values.map((item) => item.titleKey.tr()).toList(),
      borderRadius: AppConstants.sp20(context),
      borderSideEnabledColor: const Color(0xffEDEFF2),
      height: MediaQuery.of(context).size.height * .07,
      validator: (value) => value == null ? "severity".tr() : null,
      onChanged: (value) {
        final picked = IssueSeverity.values.firstWhere((item) => item.titleKey.tr() == value, orElse: () => severity);
        setState(() => severity = picked);
      },
    );
  }
}

/// Caption above each field of the report form.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: AppConstants.width5(context),
        bottom: AppConstants.height10(context),
      ),
      child: Text(title, style: Styles.font12BoldBlack(context).copyWith(color: AppColors.grey46)),
    );
  }
}
