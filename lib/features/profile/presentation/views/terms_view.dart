import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_loading_item.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/profile/data/repos/profile_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/content/content_cubit.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/driver_profile/driver_profile_cubit.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/content_page_body.dart';

/// Terms and conditions from `GET /api/terms`. With [mustAccept] the screen
/// is the first-run gate: it cannot be dismissed and ends with the accept
/// button that calls `POST /driver/terms/accept`.
class TermsView extends StatelessWidget {
  const TermsView({super.key, this.mustAccept = false});

  final bool mustAccept;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ContentCubit(getIt.get<ProfileRepoImpl>())..loadTerms(),
      child: BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
        builder: (context, langState) {
          return PopScope(
            canPop: !mustAccept,
            child: Scaffold(
              backgroundColor: const Color(0xffF5F7FA),
              body: SafeArea(
                child: Column(
                  children: [
                    CustomAppBar(title: "terms_of_service".tr(), withBack: !mustAccept),
                    Expanded(child: _buildBody(context)),
                    if (mustAccept) _buildAcceptBar(context),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<ContentCubit, ContentState>(
      builder: (context, state) {
        if (state is ContentLoadingState || state is ContentInitial) return const CustomLoadingItem();
        if (state is ContentErrorState) {
          return ContentErrorBody(message: state.errMessage, onRetry: context.read<ContentCubit>().loadTerms);
        }
        final page = (state as ContentPageSuccessState).page;
        return ContentPageBody(page: page, fallbackTitle: "terms_of_service".tr());
      },
    );
  }

  Widget _buildAcceptBar(BuildContext context) {
    return BlocConsumer<DriverProfileCubit, DriverProfileState>(
      listenWhen: (previous, current) => current.message != null && current.message != previous.message,
      listener: (context, state) =>
          toast(context: context, text: state.message!.text, isSuccess: !state.message!.isError),
      builder: (context, state) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: AppConstants.width20(context),
            vertical: AppConstants.height15(context),
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xffEDEFF2))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "terms_accept_hint".tr(),
                textAlign: TextAlign.center,
                style: Styles.font11MediumGrey46(context).copyWith(height: 1.5),
              ),
              SizedBox(height: AppConstants.height10(context)),
              DefaultButton(
                text: "accept_terms".tr(),
                gradient: AppColors.brandGradient,
                borderRadius: AppConstants.sp15(context),
                isEnabled: !state.isAcceptingTerms,
                icon: Icon(
                  Icons.check_circle_outline_rounded,
                  size: MediaQuery.of(context).size.height * .022,
                  color: Colors.white,
                ),
                onPress: () async {
                  final accepted = await context.read<DriverProfileCubit>().acceptTerms();
                  if (accepted && context.mounted) NavigationUtils.navigateBack(context: context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
