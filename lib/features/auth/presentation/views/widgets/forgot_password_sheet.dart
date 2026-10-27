// intl (re-exported by easy_localization) ships its own TextDirection enum.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/default_text_form_field.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/auth/data/repos/auth_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/auth/presentation/view_models/forgot_password/forgot_password_cubit.dart';

/// Password reset in one sheet, three steps: e-mail → emailed code → new
/// password. Built from the login form's own fields and button so it reads
/// as part of the same screen.
class ForgotPasswordSheet extends StatelessWidget {
  const ForgotPasswordSheet({super.key, this.initialEmail = ""});

  final String initialEmail;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ForgotPasswordCubit(getIt.get<AuthRepoImpl>()),
      child: _ForgotPasswordBody(initialEmail: initialEmail),
    );
  }
}

class _ForgotPasswordBody extends StatefulWidget {
  const _ForgotPasswordBody({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordBody> createState() => _ForgotPasswordBodyState();
}

class _ForgotPasswordBodyState extends State<_ForgotPasswordBody> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late final TextEditingController email = TextEditingController(text: widget.initialEmail);
  final TextEditingController code = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController confirm = TextEditingController();

  /// 0 e-mail, 1 code, 2 new password.
  int step = 0;

  @override
  void dispose() {
    email.dispose();
    code.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  void submit() {
    FocusScope.of(context).unfocus();
    final cubit = context.read<ForgotPasswordCubit>();

    switch (step) {
      case 0:
        if (!formKey.currentState!.validate()) return;
        cubit.sendCode(email: email.text);
      case 1:
        if (code.text.trim().length != 6) {
          toast(text: "reset_code_invalid".tr(), context: context, isSuccess: false);
          return;
        }
        cubit.verifyCode(code: code.text);
      default:
        if (!formKey.currentState!.validate()) return;
        cubit.resetPassword(password: password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ForgotPasswordCubit, ForgotPasswordState>(
      listener: (context, state) {
        if (state is ForgotPasswordCodeSentState) {
          toast(text: "reset_code_sent".tr(), context: context);
          setState(() => step = 1);
        } else if (state is ForgotPasswordCodeVerifiedState) {
          setState(() => step = 2);
        } else if (state is ForgotPasswordResetSuccessState) {
          Navigator.pop(context);
          toast(text: "password_reset_done".tr(), context: context);
        } else if (state is ForgotPasswordErrorState) {
          toast(text: state.errMessage, context: context, isSuccess: false);
        }
      },
      builder: (context, state) {
        final isLoading = state is ForgotPasswordLoadingState;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppConstants.width20(context),
            AppConstants.height15(context),
            AppConstants.width20(context),
            MediaQuery.of(context).viewInsets.bottom + AppConstants.height30(context),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHandle(context),
                SizedBox(height: AppConstants.height20(context)),
                Text("forgot_password".tr(), style: Styles.font18SemiBoldBlack(context)),
                SizedBox(height: AppConstants.height5(context)),
                Text(_hintKey.tr(), style: Styles.font12MediumGrey46(context).copyWith(height: 1.6)),
                SizedBox(height: AppConstants.height20(context)),
                _buildStep(context),
                SizedBox(height: AppConstants.height24(context)),
                DefaultButton(
                  onPress: submit,
                  text: _buttonKey.tr(),
                  borderRadius: AppConstants.sp15(context),
                  gradient: AppColors.brandGradient,
                  isEnabled: !isLoading,
                  elevation: 0,
                ),
                if (step == 1) ...[
                  SizedBox(height: AppConstants.height10(context)),
                  Center(
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () => context.read<ForgotPasswordCubit>().sendCode(email: email.text),
                      child: Text(
                        "resend_code".tr(),
                        style: Styles.font12MediumBlack(
                          context,
                        ).copyWith(color: AppColors.primarySwatchColor, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String get _hintKey => switch (step) {
    0 => "forgot_password_hint",
    1 => "reset_code_hint",
    _ => "new_password_hint",
  };

  String get _buttonKey => switch (step) {
    0 => "send_code",
    1 => "verify_code",
    _ => "save_password",
  };

  Widget _buildStep(BuildContext context) {
    switch (step) {
      case 0:
        return DefaultTextFormField(
          textInputType: TextInputType.emailAddress,
          controller: email,
          hintText: "emailHint".tr(),
          borderRadius: AppConstants.sp15(context),
          contentPaddingVertical: AppConstants.height15(context),
          contentPaddingHorizontal: AppConstants.width15(context),
          fillColor: const Color(0xffFBFBFC),
          prefixIcon: Icon(Icons.mail_outline_rounded, color: const Color(0xff9C9B9A), size: _iconSize(context)),
          validation: (String? value) {
            if (value == null || value.trim().isEmpty) return "emailRequired".tr();
            if (!EmailValidator.validate(value.trim())) return "emailInvalid".tr();
            return null;
          },
        );
      case 1:
        return Directionality(
          textDirection: TextDirection.ltr,
          child: PinCodeTextField(
            appContext: context,
            length: 6,
            controller: code,
            keyboardType: TextInputType.number,
            animationType: AnimationType.fade,
            cursorColor: AppColors.primarySwatchColor,
            textStyle: Styles.font18SemiBoldBlack(context),
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(AppConstants.sp10(context)),
              fieldHeight: MediaQuery.of(context).size.height * .06,
              fieldWidth: MediaQuery.of(context).size.width * .12,
              activeFillColor: Colors.white,
              inactiveFillColor: const Color(0xffFBFBFC),
              selectedFillColor: Colors.white,
              activeColor: AppColors.primarySwatchColor,
              inactiveColor: const Color(0xffEDEFF2),
              selectedColor: AppColors.primarySwatchColor,
            ),
            enableActiveFill: true,
            onChanged: (_) {},
            onCompleted: (_) => submit(),
          ),
        );
      default:
        return Column(
          children: [
            DefaultTextFormField(
              textInputType: TextInputType.visiblePassword,
              controller: password,
              isPassword: true,
              maxLines: 1,
              hintText: "new_password".tr(),
              borderRadius: AppConstants.sp15(context),
              contentPaddingVertical: AppConstants.height15(context),
              contentPaddingHorizontal: AppConstants.width15(context),
              fillColor: const Color(0xffFBFBFC),
              prefixIcon: Icon(Icons.lock_outline_rounded, color: const Color(0xff9C9B9A), size: _iconSize(context)),
              validation: (String? value) {
                if (value == null || value.isEmpty) return "passwordRequired".tr();
                if (value.length < 6) return "password_min_length".tr();
                return null;
              },
            ),
            SizedBox(height: AppConstants.height15(context)),
            DefaultTextFormField(
              textInputType: TextInputType.visiblePassword,
              controller: confirm,
              isPassword: true,
              maxLines: 1,
              hintText: "confirm_password".tr(),
              borderRadius: AppConstants.sp15(context),
              contentPaddingVertical: AppConstants.height15(context),
              contentPaddingHorizontal: AppConstants.width15(context),
              fillColor: const Color(0xffFBFBFC),
              prefixIcon: Icon(Icons.lock_outline_rounded, color: const Color(0xff9C9B9A), size: _iconSize(context)),
              validation: (String? value) => value != password.text ? "passwords_mismatch".tr() : null,
              onFilledSubmit: (_) => submit(),
            ),
          ],
        );
    }
  }

  double _iconSize(BuildContext context) => MediaQuery.of(context).size.height * .026;

  Widget _buildHandle(BuildContext context) {
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
