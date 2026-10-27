import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/default_text_form_field.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/auth/data/repos/auth_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/profile/data/repos/profile_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/update_profile/update_profile_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';

/// `PATCH /api/auth/password`: current password, new one and its confirmation.
class ChangePasswordSheet extends StatelessWidget {
  const ChangePasswordSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UpdateProfileCubit(
        authRepo: getIt.get<AuthRepoImpl>(),
        profileRepo: getIt.get<ProfileRepoImpl>(),
        routesRepo: getIt.get<RoutesRepoImpl>(),
      ),
      child: const _ChangePasswordBody(),
    );
  }
}

class _ChangePasswordBody extends StatefulWidget {
  const _ChangePasswordBody();

  @override
  State<_ChangePasswordBody> createState() => _ChangePasswordBodyState();
}

class _ChangePasswordBodyState extends State<_ChangePasswordBody> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController oldPassword = TextEditingController();
  final TextEditingController newPassword = TextEditingController();
  final TextEditingController confirm = TextEditingController();

  @override
  void dispose() {
    oldPassword.dispose();
    newPassword.dispose();
    confirm.dispose();
    super.dispose();
  }

  void submit() {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;
    context.read<UpdateProfileCubit>().changePassword(oldPassword: oldPassword.text, newPassword: newPassword.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UpdateProfileCubit, UpdateProfileState>(
      listener: (context, state) {
        if (state is ChangePasswordSuccessState) {
          Navigator.pop(context);
          toast(text: "password_changed".tr(), context: context);
        } else if (state is UpdateProfileErrorState) {
          toast(text: state.errMessage, context: context, isSuccess: false);
        }
      },
      builder: (context, state) {
        final isLoading = state is UpdateProfileLoadingState;

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
                const SheetHandle(),
                SizedBox(height: AppConstants.height20(context)),
                Text("change_password".tr(), style: Styles.font18SemiBoldBlack(context)),
                SizedBox(height: AppConstants.height20(context)),
                _passwordField(
                  context,
                  oldPassword,
                  "current_password",
                  validation: (String? value) {
                    if (value == null || value.isEmpty) return "passwordRequired".tr();
                    return null;
                  },
                ),
                SizedBox(height: AppConstants.height10(context)),
                _passwordField(
                  context,
                  newPassword,
                  "new_password",
                  validation: (String? value) {
                    if (value == null || value.isEmpty) return "passwordRequired".tr();
                    if (value.length < 6) return "password_min_length".tr();
                    return null;
                  },
                ),
                SizedBox(height: AppConstants.height10(context)),
                _passwordField(
                  context,
                  confirm,
                  "confirm_password",
                  validation: (String? value) => value != newPassword.text ? "passwords_mismatch".tr() : null,
                  onSubmit: submit,
                ),
                SizedBox(height: AppConstants.height24(context)),
                DefaultButton(
                  onPress: submit,
                  text: "save_password".tr(),
                  borderRadius: AppConstants.sp15(context),
                  gradient: AppColors.brandGradient,
                  isEnabled: !isLoading,
                  elevation: 0,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _passwordField(
    BuildContext context,
    TextEditingController controller,
    String hintKey, {
    required Function validation,
    VoidCallback? onSubmit,
  }) {
    return DefaultTextFormField(
      controller: controller,
      textInputType: TextInputType.visiblePassword,
      isPassword: true,
      maxLines: 1,
      hintText: hintKey.tr(),
      validation: validation,
      borderRadius: AppConstants.sp15(context),
      contentPaddingVertical: AppConstants.height15(context),
      contentPaddingHorizontal: AppConstants.width15(context),
      fillColor: const Color(0xffFBFBFC),
      borderSideEnabledColor: const Color(0xffEDEFF2),
      prefixIcon: Icon(
        Icons.lock_outline_rounded,
        size: MediaQuery.of(context).size.height * .026,
        color: const Color(0xff9C9B9A),
      ),
      onFilledSubmit: onSubmit == null ? null : (_) => onSubmit(),
    );
  }
}
