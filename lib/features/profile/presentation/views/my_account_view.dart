import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/account_info_tile.dart';

/// The signed in driver account: name, email and phone number.
class MyAccountView extends StatelessWidget {
  const MyAccountView({super.key, required this.name, required this.email, required this.phone});

  final String name;
  final String email;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F7FA),
          body: SafeArea(
            child: Column(
              children: [
                CustomAppBar(title: "my_account".tr()),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppConstants.width20(context),
                      AppConstants.height20(context),
                      AppConstants.width20(context),
                      AppConstants.height30(context),
                    ),
                    children: [
                      _buildIdentity(context),
                      SizedBox(height: AppConstants.height30(context)),
                      _buildDetailsCard(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIdentity(BuildContext context) {
    final avatarSize = MediaQuery.of(context).size.height * .11;

    return Column(
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
          child: Text(
            name.trim().isEmpty ? "?" : name.trim().characters.first,
            style: Styles.font24BoldBlack(context).copyWith(color: Colors.white),
          ),
        ),
        SizedBox(height: AppConstants.height15(context)),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Styles.font18SemiBoldBlack(context),
        ),
      ],
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: const Color(0xffEDEFF2)),
      ),
      child: Column(
        children: [
          AccountInfoTile(icon: Icons.person_outline_rounded, label: "full_name".tr(), value: name),
          const Divider(height: 1, color: Color(0xffF0F2F5)),
          AccountInfoTile(icon: Icons.mail_outline_rounded, label: "email".tr(), value: email, isLtr: true),
          const Divider(height: 1, color: Color(0xffF0F2F5)),
          AccountInfoTile(icon: Icons.phone_outlined, label: "phone_number".tr(), value: phone, isLtr: true),
        ],
      ),
    );
  }
}
