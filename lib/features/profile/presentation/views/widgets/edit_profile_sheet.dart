import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/default_text_form_field.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/auth/data/models/user_model.dart';
import 'package:digital_trade_portal_driver/features/auth/data/repos/auth_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/driver_model.dart';
import 'package:digital_trade_portal_driver/features/profile/data/repos/profile_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/driver_profile/driver_profile_cubit.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/update_profile/update_profile_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';

/// Edits the account: name, e-mail, phone and avatar (`POST /auth/profile`)
/// plus the driver documents (`PATCH /driver/profile`).
class EditProfileSheet extends StatelessWidget {
  const EditProfileSheet({super.key, required this.driver});

  final DriverModel driver;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UpdateProfileCubit(
        authRepo: getIt.get<AuthRepoImpl>(),
        profileRepo: getIt.get<ProfileRepoImpl>(),
        routesRepo: getIt.get<RoutesRepoImpl>(),
      ),
      child: _EditProfileBody(driver: driver),
    );
  }
}

class _EditProfileBody extends StatefulWidget {
  const _EditProfileBody({required this.driver});

  final DriverModel driver;

  @override
  State<_EditProfileBody> createState() => _EditProfileBodyState();
}

class _EditProfileBodyState extends State<_EditProfileBody> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late final TextEditingController firstName;
  late final TextEditingController lastName;
  late final TextEditingController email;
  late final TextEditingController phone;
  late final TextEditingController nationalId;
  late final TextEditingController licenseNo;
  late final TextEditingController licenseExpiry;
  File? avatar;

  @override
  void initState() {
    super.initState();
    final user = widget.driver.user;
    final parts = (user?.name ?? "").trim().split(" ");
    firstName = TextEditingController(text: user?.firstName ?? (parts.isNotEmpty ? parts.first : ""));
    lastName = TextEditingController(text: user?.lastName ?? (parts.length > 1 ? parts.sublist(1).join(" ") : ""));
    email = TextEditingController(text: user?.email ?? "");
    phone = TextEditingController(text: user?.phone ?? "");
    nationalId = TextEditingController(text: widget.driver.nationalId ?? "");
    licenseNo = TextEditingController(text: widget.driver.driverLicenseNo ?? "");
    licenseExpiry = TextEditingController(text: widget.driver.driverLicenseExpiry ?? "");
  }

  @override
  void dispose() {
    for (final controller in [firstName, lastName, email, phone, nationalId, licenseNo, licenseExpiry]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null && mounted) setState(() => avatar = File(picked.path));
  }

  Future<void> pickExpiry() async {
    final initial = JsonUtils.asDate(licenseExpiry.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 15),
    );
    if (picked != null && mounted) setState(() => licenseExpiry.text = JsonUtils.formatServerDate(picked));
  }

  void submit() {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;
    context.read<UpdateProfileCubit>().updateProfile(
      firstName: firstName.text,
      lastName: lastName.text,
      email: email.text,
      phone: phone.text,
      avatar: avatar,
      nationalId: nationalId.text.trim().isEmpty ? null : nationalId.text.trim(),
      driverLicenseNo: licenseNo.text.trim().isEmpty ? null : licenseNo.text.trim(),
      driverLicenseExpiry: licenseExpiry.text.trim().isEmpty ? null : licenseExpiry.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UpdateProfileCubit, UpdateProfileState>(
      listener: (context, state) {
        if (state is UpdateProfileSuccessState) {
          final profile = context.read<DriverProfileCubit>();
          final current = widget.driver.user;
          profile.applyUser(
            state.user ??
                UserModel(
                  id: current?.id ?? 0,
                  firstName: firstName.text.trim(),
                  lastName: lastName.text.trim(),
                  email: email.text.trim(),
                  phone: phone.text.trim(),
                  image: current?.image,
                  language: current?.language,
                  status: current?.status,
                ),
          );
          profile.applyDriverFields(
            nationalId: state.nationalId,
            driverLicenseNo: state.driverLicenseNo,
            driverLicenseExpiry: state.driverLicenseExpiry,
            photo: state.photo,
          );
          // The avatar URL comes back with the next profile load.
          profile.loadProfile(silent: true);
          Navigator.pop(context);
          toast(text: "profile_updated".tr(), context: context);
        } else if (state is UpdateProfileErrorState) {
          toast(text: state.errMessage, context: context, isSuccess: false);
        }
      },
      builder: (context, state) {
        final isLoading = state is UpdateProfileLoadingState;

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: .85,
            maxChildSize: .95,
            minChildSize: .5,
            builder: (context, scrollController) {
              return Form(
                key: formKey,
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    AppConstants.width20(context),
                    AppConstants.height15(context),
                    AppConstants.width20(context),
                    AppConstants.height30(context),
                  ),
                  children: [
                    const SheetHandle(),
                    SizedBox(height: AppConstants.height20(context)),
                    Text("edit_profile".tr(), style: Styles.font18SemiBoldBlack(context)),
                    SizedBox(height: AppConstants.height20(context)),
                    _buildAvatarPicker(context),
                    SizedBox(height: AppConstants.height20(context)),
                    SheetSectionLabel(title: "account".tr()),
                    _field(context, firstName, "first_name", TextInputType.name, Icons.person_outline_rounded),
                    SizedBox(height: AppConstants.height10(context)),
                    _field(context, lastName, "last_name", TextInputType.name, Icons.person_outline_rounded),
                    SizedBox(height: AppConstants.height10(context)),
                    _field(
                      context,
                      email,
                      "email",
                      TextInputType.emailAddress,
                      Icons.mail_outline_rounded,
                      validation: (String? value) {
                        if (value == null || value.trim().isEmpty) return "emailRequired".tr();
                        if (!EmailValidator.validate(value.trim())) return "emailInvalid".tr();
                        return null;
                      },
                    ),
                    SizedBox(height: AppConstants.height10(context)),
                    _field(context, phone, "phone_number", TextInputType.number, Icons.phone_outlined),
                    SizedBox(height: AppConstants.height20(context)),
                    SheetSectionLabel(title: "driver_documents".tr()),
                    _field(
                      context,
                      nationalId,
                      "national_id",
                      TextInputType.text,
                      Icons.badge_outlined,
                      required: false,
                    ),
                    SizedBox(height: AppConstants.height10(context)),
                    _field(
                      context,
                      licenseNo,
                      "driver_license_no",
                      TextInputType.text,
                      Icons.credit_card_outlined,
                      required: false,
                    ),
                    SizedBox(height: AppConstants.height10(context)),
                    _field(
                      context,
                      licenseExpiry,
                      "driver_license_expiry",
                      TextInputType.datetime,
                      Icons.event_outlined,
                      required: false,
                      readOnly: true,
                      onTap: pickExpiry,
                    ),
                    SizedBox(height: AppConstants.height24(context)),
                    DefaultButton(
                      onPress: submit,
                      text: "save".tr(),
                      borderRadius: AppConstants.sp15(context),
                      gradient: AppColors.brandGradient,
                      isEnabled: !isLoading,
                      elevation: 0,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAvatarPicker(BuildContext context) {
    final size = MediaQuery.of(context).size.height * .11;

    return Center(
      child: InkWell(
        onTap: pickAvatar,
        customBorder: const CircleBorder(),
        child: Stack(
          children: [
            Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
              child: avatar != null
                  ? Image.file(avatar!, width: size, height: size, fit: BoxFit.cover)
                  : Icon(Icons.person_rounded, size: size * .5, color: Colors.white),
            ),
            PositionedDirectional(
              bottom: 0,
              end: 0,
              child: Container(
                padding: EdgeInsets.all(AppConstants.sp5(context)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xffEDEFF2)),
                ),
                child: Icon(Icons.camera_alt_outlined, size: size * .2, color: AppColors.primarySwatchColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    BuildContext context,
    TextEditingController controller,
    String labelKey,
    TextInputType type,
    IconData icon, {
    bool required = true,
    bool readOnly = false,
    Function? onTap,
    Function? validation,
  }) {
    return DefaultTextFormField(
      controller: controller,
      textInputType: type,
      required: required,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: 1,
      hintText: labelKey.tr(),
      validationMsg: "field_required".tr(),
      validation: validation,
      borderRadius: AppConstants.sp15(context),
      contentPaddingVertical: AppConstants.height15(context),
      contentPaddingHorizontal: AppConstants.width15(context),
      fillColor: const Color(0xffFBFBFC),
      borderSideEnabledColor: const Color(0xffEDEFF2),
      prefixIcon: Icon(icon, size: MediaQuery.of(context).size.height * .026, color: const Color(0xff9C9B9A)),
    );
  }
}
