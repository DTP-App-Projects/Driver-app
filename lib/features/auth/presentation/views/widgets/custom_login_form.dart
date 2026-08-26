import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/features/main_layout/presentation/views/main_layout_view.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/default_text_form_field.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/loading_dialog.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/auth/presentation/view_models/login/login_cubit.dart';

class CustomLoginForm extends StatefulWidget {
  const CustomLoginForm({super.key});

  @override
  State<CustomLoginForm> createState() => _CustomLoginFormState();
}

class _CustomLoginFormState extends State<CustomLoginForm> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late TextEditingController email;
  late TextEditingController password;

  @override
  void initState() {
    email = TextEditingController();
    password = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void onSubmit() {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;
    NavigationUtils.navigateTo(context: context, destinationScreen: MainLayoutView());

    // context.read<LoginCubit>().login(phone: phoneController.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCard(context),
              SizedBox(height: AppConstants.height30(context)),
              _buildSubmitButton(context),
            ],
          ),
        );
      },
    );
  }

  /// The two inputs grouped in one raised card so the form reads as a block.
  Widget _buildCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.width20(context),
        vertical: AppConstants.height20(context),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: const Color(0xffEDEFF2)),
        boxShadow: [
          BoxShadow(color: AppColors.neutralColor.withValues(alpha: .05), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: "email".tr()),
          SizedBox(height: AppConstants.height5(context)),
          DefaultTextFormField(
            textInputType: TextInputType.emailAddress,
            controller: email,
            hintText: "emailHint".tr(),
            borderRadius: AppConstants.sp15(context),
            contentPaddingVertical: AppConstants.height15(context),
            contentPaddingHorizontal: AppConstants.width15(context),
            fillColor: const Color(0xffFBFBFC),
            prefixIcon: const _FieldIcon(icon: Icons.mail_outline_rounded),
            validation: (String? value) {
              if (value == null || value.trim().isEmpty) return "emailRequired".tr();
              if (!EmailValidator.validate(value.trim())) return "emailInvalid".tr();
              return null;
            },
          ),
          SizedBox(height: AppConstants.height15(context)),
          _FieldLabel(label: "password".tr()),
          SizedBox(height: AppConstants.height5(context)),
          DefaultTextFormField(
            textInputType: TextInputType.visiblePassword,
            controller: password,
            isPassword: true,
            maxLines: 1,
            hintText: "passwordHint".tr(),
            borderRadius: AppConstants.sp15(context),
            contentPaddingVertical: AppConstants.height15(context),
            contentPaddingHorizontal: AppConstants.width15(context),
            fillColor: const Color(0xffFBFBFC),
            prefixIcon: const _FieldIcon(icon: Icons.lock_outline_rounded),
            validationMsg: "passwordRequired".tr(),
            onFilledSubmit: (_) => onSubmit(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return BlocConsumer<LoginCubit, LoginState>(
      listener: (context, state) {
        if (state is LoginLoadingState) {
          LoadingDialog().show(context);
        } else if (state is LoginSuccessState) {
          LoadingDialog().hide();
          toast(text: state.model.message ?? "", context: context);
          // NavigationUtils.navigateTo(context: context, destinationScreen: VerificationView(phone: phoneController.text,requestId:state.model.requestId!));
          email.clear();
          password.clear();
        } else if (state is LoginErrorState) {
          LoadingDialog().hide();
          toast(text: state.errMessage, context: context, isSuccess: false);
        }
      },
      builder: (context, state) {
        return SizedBox(
          width: double.infinity,
          child: DefaultButton(
            onPress: onSubmit,
            text: "continue".tr(),
            borderRadius: AppConstants.sp15(context),
            gradient: AppColors.brandGradient,
            isEnabled: state is! LoginLoadingState,
            elevation: 0,
          ),
        );
      },
    );
  }
}

/// Field caption with the required marker.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Styles.font12MediumBlack(context).copyWith(color: AppColors.grey46)),
        Text("*", style: Styles.font12MediumBlack(context).copyWith(color: const Color(0xffC11102))),
      ],
    );
  }
}

class _FieldIcon extends StatelessWidget {
  const _FieldIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: MediaQuery.of(context).size.height * .026, color: const Color(0xff9C9B9A));
  }
}
