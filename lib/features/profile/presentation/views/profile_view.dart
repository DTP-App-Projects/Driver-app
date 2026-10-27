import 'package:digital_trade_portal_driver/features/emergency/presentation/views/emergency_view.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/language_bottom_sheet.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/my_cars/presentation/views/my_cars_view.dart';
import 'package:digital_trade_portal_driver/features/notification/presentation/views/notification_view.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/driver_profile/driver_profile_cubit.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/about_us_view.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/earnings_view.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/my_account_view.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/support_view.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/terms_view.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/account_deletion_sheet.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/routes_view.dart';
import 'package:digital_trade_portal_driver/features/training/presentation/views/training_view.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/profile_header.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/profile_menu_section.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/profile_menu_tile.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/profile_stats.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return BlocBuilder<DriverProfileCubit, DriverProfileState>(
          builder: (context, profileState) {
            final driver = profileState.driver;

            return Scaffold(
              backgroundColor: const Color(0xffF5F7FA),
              body: RefreshIndicator(
                color: AppColors.primarySwatchColor,
                onRefresh: () => context.read<DriverProfileCubit>().loadProfile(silent: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    ProfileHeader(
                      name: driver?.displayName ?? "",
                      phone: driver?.phone ?? "",
                      isOnline: driver?.isActive ?? true,
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppConstants.width20(context),
                        AppConstants.height24(context),
                        AppConstants.width20(context),
                        AppConstants.height30(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProfileStats(
                            deliveries: driver?.totalDeliveries ?? 0,
                            pickups: driver?.totalPickups ?? 0,
                            rating: driver?.rating ?? 0,
                          ),
                          SizedBox(height: AppConstants.height24(context)),
                          _buildAccountSection(context),
                          SizedBox(height: AppConstants.height24(context)),
                          _buildAppSection(context),
                          SizedBox(height: AppConstants.height24(context)),
                          _buildSupportSection(context),
                          SizedBox(height: AppConstants.height24(context)),
                          _buildDangerSection(context),
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

  Widget _buildAccountSection(BuildContext context) {
    return ProfileMenuSection(
      title: "account".tr(),
      items: [
        ProfileMenuTile(
          icon: Icons.person_outline_rounded,
          title: "my_account".tr(),
          onTap: () => NavigationUtils.navigateTo(context: context, destinationScreen: const MyAccountView()),
        ),
        ProfileMenuTile(
          icon: Icons.directions_car_filled_outlined,
          title: "my_vehicle".tr(),
          onTap: () => NavigationUtils.navigateTo(context: context, destinationScreen: const MyCarsView()),
        ),
        ProfileMenuTile(
          icon: Icons.route_outlined,
          title: "routes".tr(),
          onTap: () => NavigationUtils.navigateTo(context: context, destinationScreen: const RoutesView()),
        ),
        ProfileMenuTile(
          icon: Icons.payments_outlined,
          title: "earnings_performance".tr(),
          onTap: () => NavigationUtils.navigateTo(context: context, destinationScreen: const EarningsView()),
        ),
        ProfileMenuTile(
          icon: Icons.school_outlined,
          title: "training".tr(),
          onTap: () => NavigationUtils.navigateTo(context: context, destinationScreen: const TrainingView()),
        ),
      ],
    );
  }

  Widget _buildAppSection(BuildContext context) {
    return ProfileMenuSection(
      title: "app_settings".tr(),
      items: [
        ProfileMenuTile(
          icon: Icons.notifications_none_rounded,
          title: "notifications".tr(),
          onTap: () => NavigationUtils.navigateTo(context: context, destinationScreen: const NotificationView()),
        ),
        ProfileMenuTile(
          icon: Icons.report_gmailerrorred_rounded,
          title: "report_issue".tr(),
          onTap: () => NavigationUtils.navigateTo(context: context, destinationScreen: const EmergencyView()),
        ),
        ProfileMenuTile(
          icon: Icons.language_rounded,
          title: "change_language".tr(),
          trailingText: "lang".tr(),
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.white,
            builder: (context) => const LanguageBottomSheet(),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return ProfileMenuSection(
      title: "support_info".tr(),
      items: [
        ProfileMenuTile(icon: Icons.shield_outlined, title: "privacy_policy".tr(), onTap: () => comingSoon(context)),
        ProfileMenuTile(
          icon: Icons.description_outlined,
          title: "terms_of_service".tr(),
          onTap: () => NavigationUtils.navigateTo(context: context, destinationScreen: const TermsView()),
        ),
        ProfileMenuTile(
          icon: Icons.support_agent_rounded,
          title: "support".tr(),
          onTap: () => NavigationUtils.navigateTo(context: context, destinationScreen: const SupportView()),
        ),
        ProfileMenuTile(
          icon: Icons.info_outline_rounded,
          title: "about_app".tr(),
          onTap: () => NavigationUtils.navigateTo(context: context, destinationScreen: const AboutUsView()),
        ),
      ],
    );
  }

  Widget _buildDangerSection(BuildContext context) {
    return ProfileMenuSection(
      items: [
        ProfileMenuTile(
          icon: Icons.logout_rounded,
          title: "logout".tr(),
          isDestructive: true,
          onTap: () => confirmLogout(context),
        ),
        ProfileMenuTile(
          icon: Icons.delete_outline_rounded,
          title: "delete_account".tr(),
          isDestructive: true,
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sp20(context))),
            ),
            builder: (sheetContext) => const AccountDeletionSheet(),
          ),
        ),
      ],
    );
  }

  void comingSoon(BuildContext context) => toast(text: "coming_soon".tr(), context: context);

  void confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: AppConstants.width30(context)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.sp20(context))),
        child: Padding(
          padding: EdgeInsets.all(AppConstants.sp20(context)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("logout".tr(), style: Styles.font18SemiBoldBlack(context).copyWith(color: AppColors.red)),
              SizedBox(height: AppConstants.height15(context)),
              Text("logout_hint".tr(), textAlign: TextAlign.center, style: Styles.font14MediumGrey46(context)),
              SizedBox(height: AppConstants.height20(context)),
              Row(
                children: [
                  Expanded(
                    child: DefaultButton(
                      onPress: () => NavigationUtils.navigateBack(context: dialogContext),
                      text: "cancel".tr(),
                    ),
                  ),
                  SizedBox(width: AppConstants.width10(context)),
                  Expanded(
                    child: DefaultButton(
                      onPress: () => logout(dialogContext),
                      text: "yes".tr(),
                      backgroundColor: Colors.white,
                      hasBorder: true,
                      borderColor: AppColors.red,
                      textColor: AppColors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Unregisters the push token and forgets the session through the profile
  /// cubit, then goes back to the login flow.
  Future<void> logout(BuildContext context) async {
    final router = GoRouter.of(context);
    final profileCubit = context.read<DriverProfileCubit>();
    NavigationUtils.navigateBack(context: context);
    await profileCubit.logout();
    router.go("/loginView");
  }
}
