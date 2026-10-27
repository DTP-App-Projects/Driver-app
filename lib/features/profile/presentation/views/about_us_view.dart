import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/utils/assets/assets.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/content_models.dart';
import 'package:digital_trade_portal_driver/features/profile/data/repos/profile_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/content/content_cubit.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/content_page_body.dart';

/// About the company from `GET /api/abouts`; the bundled copy stays as the
/// fallback while the request runs or when it fails.
class AboutUsView extends StatefulWidget {
  const AboutUsView({super.key});

  @override
  State<AboutUsView> createState() => _AboutUsViewState();
}

class _AboutUsViewState extends State<AboutUsView> {
  String appVersion = "";

  @override
  void initState() {
    super.initState();
    loadVersion();
  }

  Future<void> loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => appVersion = info.version);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ContentCubit(getIt.get<ProfileRepoImpl>())..loadAbout(),
      child: BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
        builder: (context, langState) {
          return Scaffold(
            backgroundColor: const Color(0xffF5F7FA),
            body: SafeArea(
              child: Column(
                children: [
                  CustomAppBar(title: "about_app".tr()),
                  Expanded(
                    child: BlocBuilder<ContentCubit, ContentState>(
                      builder: (context, state) {
                        final page = state is ContentPageSuccessState && !state.page.isEmpty
                            ? state.page
                            : ContentPageModel(title: "about_company".tr(), body: "about_description".tr());
                        return ContentPageBody(
                          page: page,
                          fallbackTitle: "about_company".tr(),
                          header: _buildIdentity(context),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIdentity(BuildContext context) {
    return Column(
      children: [
        Image.asset(AssetData.logo, width: MediaQuery.of(context).size.width * .32),
        SizedBox(height: AppConstants.height15(context)),
        Text("appName".tr(), textAlign: TextAlign.center, style: Styles.font24BoldBlack(context)),
        SizedBox(height: AppConstants.height5(context)),
        Text("appSlogan".tr(), style: Styles.font14MediumGrey46(context)),
        SizedBox(height: AppConstants.height10(context)),
        if (appVersion.isNotEmpty)
          Text(
            "version".tr(namedArgs: {"version": appVersion}),
            style: Styles.font12MediumGrey46(context).copyWith(color: AppColors.neutralColor[400]),
          ),
      ],
    );
  }
}
