import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/brand_background.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/translation_item.dart';
import 'package:digital_trade_portal_driver/core/utils/assets/assets.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/auth/data/repos/auth_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/auth/presentation/view_models/login/login_cubit.dart';
import 'package:digital_trade_portal_driver/features/auth/presentation/views/widgets/custom_login_form.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        // Transparent so the brand background paints under the navigation bar.
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: BlocProvider(
        create: (context) => LoginCubit(getIt.get<AuthRepoImpl>()),
        child: BlocBuilder<LoginCubit, LoginState>(
          builder: (context, loginState) => _buildScaffold(context, isLoading: loginState is LoginLoadingState),
        ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, {required bool isLoading}) {
    return PopScope(
      // Block the back gesture while a sign in request is in flight.
      canPop: !isLoading,
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
          builder: (context, langState) {
            return Stack(
              fit: StackFit.expand,
              children: [
                const BrandBackground(opacity: .14),
                SafeArea(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.opaque,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: AppConstants.width20(context),
                        vertical: AppConstants.height20(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Align(alignment: AlignmentDirectional.centerEnd, child: TranslationItem()),
                          SizedBox(height: AppConstants.height30(context)),
                          _buildHeader(context),
                          SizedBox(height: AppConstants.height20(context)),
                          const CustomLoginForm(),
                          SizedBox(height: AppConstants.height24(context)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(AssetData.logo, width: MediaQuery.of(context).size.width * .22),
        SizedBox(height: AppConstants.height15(context)),
        Text("login".tr(), style: Styles.font24BoldBlack(context)),
        SizedBox(height: AppConstants.height5(context)),
        Text("loginSubtitle".tr(), style: Styles.font14MediumGrey46(context)),
      ],
    );
  }
}
