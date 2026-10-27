import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/default_cached_network_image.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/driver_model.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/driver_profile/driver_profile_cubit.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/account_info_tile.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/change_password_sheet.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/edit_profile_sheet.dart';

/// The signed in driver account: identity, contact details and the driver
/// documents, with the edit and change-password entry points.
class MyAccountView extends StatelessWidget {
  const MyAccountView({super.key});

  void _openSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sp20(context))),
      ),
      builder: (sheetContext) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return BlocBuilder<DriverProfileCubit, DriverProfileState>(
          builder: (context, state) {
            final driver = state.driver;

            return Scaffold(
              backgroundColor: const Color(0xffF5F7FA),
              body: SafeArea(
                child: Column(
                  children: [
                    CustomAppBar(
                      title: "my_account".tr(),
                      trailing: driver == null
                          ? null
                          : IconButton(
                              onPressed: () => _openSheet(context, EditProfileSheet(driver: driver)),
                              icon: Icon(
                                Icons.edit_outlined,
                                color: AppColors.primarySwatchColor,
                                size: MediaQuery.of(context).size.height * .026,
                              ),
                            ),
                    ),
                    Expanded(
                      child: driver == null
                          ? Center(child: Text("content_unavailable".tr(), style: Styles.font12MediumGrey46(context)))
                          : ListView(
                              padding: EdgeInsets.fromLTRB(
                                AppConstants.width20(context),
                                AppConstants.height20(context),
                                AppConstants.width20(context),
                                AppConstants.height30(context),
                              ),
                              children: [
                                _buildIdentity(context, driver),
                                SizedBox(height: AppConstants.height30(context)),
                                _buildDetailsCard(context, driver),
                                SizedBox(height: AppConstants.height20(context)),
                                Text("driver_documents".tr(), style: Styles.font16SemiBoldBlack(context)),
                                SizedBox(height: AppConstants.height15(context)),
                                _buildDocumentsCard(context, driver),
                                SizedBox(height: AppConstants.height24(context)),
                                DefaultButton(
                                  text: "change_password".tr(),
                                  backgroundColor: Colors.white,
                                  textColor: AppColors.primarySwatchColor,
                                  hasBorder: true,
                                  borderColor: AppColors.primarySwatchColor,
                                  borderRadius: AppConstants.sp15(context),
                                  icon: Icon(
                                    Icons.lock_outline_rounded,
                                    size: MediaQuery.of(context).size.height * .022,
                                    color: AppColors.primarySwatchColor,
                                  ),
                                  onPress: () => _openSheet(context, const ChangePasswordSheet()),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildIdentity(BuildContext context, DriverModel driver) {
    final avatarSize = MediaQuery.of(context).size.height * .11;
    final name = driver.displayName;
    final image = driver.user?.image;

    return Column(
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
          child: image != null && image.startsWith("http")
              ? DefaultCachedNetworkImage(
                  imageUrl: image,
                  imageWidth: avatarSize,
                  imageHeight: avatarSize,
                  fit: BoxFit.cover,
                )
              : Text(
                  name.trim().isEmpty ? "?" : name.trim().characters.first,
                  style: Styles.font24BoldBlack(context).copyWith(color: Colors.white),
                ),
        ),
        SizedBox(height: AppConstants.height15(context)),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Styles.font18SemiBoldBlack(context)),
        if (driver.organization?.name != null) ...[
          SizedBox(height: AppConstants.height5(context) * .6),
          Text(driver.organization!.name!, style: Styles.font12MediumGrey46(context)),
        ],
      ],
    );
  }

  Widget _buildDetailsCard(BuildContext context, DriverModel driver) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: const Color(0xffEDEFF2)),
      ),
      child: Column(
        children: [
          AccountInfoTile(icon: Icons.person_outline_rounded, label: "full_name".tr(), value: driver.displayName),
          const Divider(height: 1, color: Color(0xffF0F2F5)),
          AccountInfoTile(icon: Icons.mail_outline_rounded, label: "email".tr(), value: driver.email, isLtr: true),
          const Divider(height: 1, color: Color(0xffF0F2F5)),
          AccountInfoTile(icon: Icons.phone_outlined, label: "phone_number".tr(), value: driver.phone, isLtr: true),
        ],
      ),
    );
  }

  Widget _buildDocumentsCard(BuildContext context, DriverModel driver) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: const Color(0xffEDEFF2)),
      ),
      child: Column(
        children: [
          AccountInfoTile(
            icon: Icons.badge_outlined,
            label: "national_id".tr(),
            value: driver.nationalId ?? "—",
            isLtr: true,
          ),
          const Divider(height: 1, color: Color(0xffF0F2F5)),
          AccountInfoTile(
            icon: Icons.credit_card_outlined,
            label: "driver_license_no".tr(),
            value: driver.driverLicenseNo ?? "—",
            isLtr: true,
          ),
          const Divider(height: 1, color: Color(0xffF0F2F5)),
          AccountInfoTile(
            icon: Icons.event_outlined,
            label: "driver_license_expiry".tr(),
            value: driver.driverLicenseExpiry ?? "—",
            isLtr: true,
          ),
          if (driver.defaultVehicle != null) ...[
            const Divider(height: 1, color: Color(0xffF0F2F5)),
            AccountInfoTile(
              icon: Icons.local_shipping_outlined,
              label: "assigned_vehicle".tr(),
              value: driver.defaultVehicle!.plate,
            ),
          ],
        ],
      ),
    );
  }
}
