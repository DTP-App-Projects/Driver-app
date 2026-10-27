import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/tr_or.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_loading_item.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/content_page_body.dart';
import 'package:digital_trade_portal_driver/features/training/data/models/training_models.dart';
import 'package:digital_trade_portal_driver/features/training/data/repos/training_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/training/presentation/view_models/training/training_cubit.dart';
import 'package:digital_trade_portal_driver/features/training/presentation/views/training_module_view.dart';

/// Onboarding / compliance modules with the driver's progress and
/// certification state (`GET /driver/training/curriculum`).
class TrainingView extends StatelessWidget {
  const TrainingView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TrainingCubit(getIt.get<TrainingRepoImpl>())..loadCurriculum(),
      child: BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
        builder: (context, langState) {
          return Scaffold(
            backgroundColor: const Color(0xffF5F7FA),
            body: SafeArea(
              child: Column(
                children: [
                  CustomAppBar(title: "training".tr()),
                  Expanded(
                    child: BlocBuilder<TrainingCubit, TrainingState>(
                      builder: (context, state) {
                        if (state.isLoading && !state.hasLoaded) return const CustomLoadingItem();
                        if (state.failure != null && !state.hasLoaded) {
                          return ContentErrorBody(
                            message: state.failure!.errMessage,
                            onRetry: context.read<TrainingCubit>().loadCurriculum,
                          );
                        }
                        final curriculum = state.curriculum;
                        if (curriculum == null) return const SizedBox.shrink();
                        return RefreshIndicator(
                          color: AppColors.primarySwatchColor,
                          onRefresh: context.read<TrainingCubit>().loadCurriculum,
                          child: _buildList(context, curriculum),
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

  Widget _buildList(BuildContext context, CurriculumModel curriculum) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppConstants.width20(context),
        AppConstants.height10(context),
        AppConstants.width20(context),
        AppConstants.height30(context),
      ),
      children: [
        _buildCertificateCard(context, curriculum.status, curriculum.modules),
        SizedBox(height: AppConstants.height24(context)),
        Text("training_modules".tr(), style: Styles.font16SemiBoldBlack(context)),
        SizedBox(height: AppConstants.height15(context)),
        if (curriculum.modules.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppConstants.height30(context)),
            child: Text(
              "no_training_modules".tr(),
              textAlign: TextAlign.center,
              style: Styles.font12MediumGrey46(context).copyWith(height: 1.6),
            ),
          ),
        for (int i = 0; i < curriculum.modules.length; i++) ...[
          if (i != 0) SizedBox(height: AppConstants.height10(context)),
          _buildModuleItem(context, curriculum.modules[i], i + 1),
        ],
      ],
    );
  }

  Widget _buildCertificateCard(
    BuildContext context,
    CertificationStatusModel status,
    List<TrainingModuleModel> modules,
  ) {
    final locale = context.locale.languageCode;
    final number = NumberFormat.decimalPattern(locale);
    final passed = modules.where((module) => module.isPassed).length;
    final completed = status.completedModules > 0 ? status.completedModules : passed;
    final total = status.totalModules > 0 ? status.totalModules : modules.length;
    final statusText = trOrHumanized(
      "certification_${status.status ?? (status.isCertified ? "certified" : "in_progress")}",
      status.status ?? "training".tr(),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppConstants.sp20(context)),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status.isCertified ? Icons.workspace_premium_rounded : Icons.school_rounded,
                color: Colors.white,
                size: MediaQuery.of(context).size.height * .04,
              ),
              SizedBox(width: AppConstants.width15(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusText, style: Styles.font16SemiBoldBlack(context).copyWith(color: Colors.white)),
                    SizedBox(height: AppConstants.height5(context) * .6),
                    Text(
                      "modules_progress".tr(
                        namedArgs: {"done": number.format(completed), "total": number.format(total)},
                      ),
                      style: Styles.font12MediumBlack(context).copyWith(color: Colors.white.withValues(alpha: .80)),
                    ),
                    if (status.expiresAt != null)
                      Text(
                        "certificate_expires".tr(
                          namedArgs: {"date": DateFormat("d MMMM y", locale).format(status.expiresAt!)},
                        ),
                        style: Styles.font11MediumBlack(context).copyWith(color: Colors.white.withValues(alpha: .75)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            SizedBox(height: AppConstants.height15(context)),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.sp30(context)),
              child: LinearProgressIndicator(
                value: (completed / total).clamp(0, 1),
                minHeight: MediaQuery.of(context).size.height * .010,
                backgroundColor: Colors.white.withValues(alpha: .25),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModuleItem(BuildContext context, TrainingModuleModel module, int order) {
    final radius = BorderRadius.circular(AppConstants.sp20(context));
    final circleSize = MediaQuery.of(context).size.height * .046;
    final color = module.isPassed
        ? AppColors.secondaryColor
        : module.isStarted
        ? const Color(0xffE8A317)
        : AppColors.primarySwatchColor;

    return Material(
      color: Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: () => NavigationUtils.navigateTo(
          context: context,
          destinationScreen: TrainingModuleView(moduleId: module.id, title: module.title),
        ),
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: const Color(0xffEDEFF2)),
          ),
          child: Padding(
            padding: EdgeInsets.all(AppConstants.sp15(context)),
            child: Row(
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .10)),
                  child: module.isPassed
                      ? Icon(Icons.check_rounded, size: circleSize * .5, color: color)
                      : Text(
                          NumberFormat.decimalPattern(context.locale.languageCode).format(order),
                          style: Styles.font14BoldBlack(context).copyWith(color: color),
                        ),
                ),
                SizedBox(width: AppConstants.width15(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Styles.font14MediumBlack(context).copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (module.description != null) ...[
                        SizedBox(height: AppConstants.height5(context) * .6),
                        Text(
                          module.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Styles.font11MediumGrey46(context),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: AppConstants.width10(context)),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: MediaQuery.of(context).size.height * .016,
                  color: AppColors.neutralColor[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
