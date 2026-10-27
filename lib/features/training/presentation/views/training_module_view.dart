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
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/content_page_body.dart';
import 'package:digital_trade_portal_driver/features/training/data/models/training_models.dart';
import 'package:digital_trade_portal_driver/features/training/data/repos/training_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/training/presentation/view_models/training/training_cubit.dart';

/// One module: its content, then the quiz submitted through
/// `POST /driver/training/modules/{id}/submit`.
class TrainingModuleView extends StatelessWidget {
  const TrainingModuleView({super.key, required this.moduleId, required this.title});

  final int moduleId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TrainingCubit(getIt.get<TrainingRepoImpl>())..openModule(moduleId),
      child: _TrainingModuleBody(title: title),
    );
  }
}

class _TrainingModuleBody extends StatefulWidget {
  const _TrainingModuleBody({required this.title});

  final String title;

  @override
  State<_TrainingModuleBody> createState() => _TrainingModuleBodyState();
}

class _TrainingModuleBodyState extends State<_TrainingModuleBody> {
  final Map<int, String> answers = {};

  void submit(TrainingModuleModel module) {
    if (answers.length < module.questions.length) {
      toast(text: "answer_all_questions".tr(), context: context, isSuccess: false);
      return;
    }
    context.read<TrainingCubit>().submitQuiz(answers);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return BlocConsumer<TrainingCubit, TrainingState>(
          listenWhen: (previous, current) => current.submitError != null || current.quizResult != previous.quizResult,
          listener: (context, state) {
            if (state.submitError != null) {
              toast(text: state.submitError!, context: context, isSuccess: false);
            } else if (state.quizResult != null) {
              toast(
                text: (state.quizResult!.passed ? "quiz_passed" : "quiz_failed").tr(),
                context: context,
                isSuccess: state.quizResult!.passed,
              );
            }
          },
          builder: (context, state) {
            return Scaffold(
              backgroundColor: const Color(0xffF5F7FA),
              body: SafeArea(
                child: Column(
                  children: [
                    CustomAppBar(title: state.module?.title ?? widget.title),
                    Expanded(child: _buildBody(context, state)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, TrainingState state) {
    if (state.isLoadingModule) return const CustomLoadingItem();
    final module = state.module;
    if (module == null) {
      return ContentErrorBody(
        message: state.failure?.errMessage ?? "content_unavailable".tr(),
        onRetry: () => context.read<TrainingCubit>().openModule(module?.id ?? 0),
      );
    }

    final result = state.quizResult;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppConstants.width20(context),
        AppConstants.height10(context),
        AppConstants.width20(context),
        AppConstants.height30(context),
      ),
      children: [
        if (module.description != null || module.content != null)
          Container(
            padding: EdgeInsets.all(AppConstants.sp20(context)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
              border: Border.all(color: const Color(0xffEDEFF2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (module.description != null) ...[
                  Text(module.description!, style: Styles.font14MediumBlack(context).copyWith(height: 1.6)),
                  if (module.content != null) SizedBox(height: AppConstants.height15(context)),
                ],
                if (module.content != null)
                  Text(
                    ContentPageBody.plainText(module.content!),
                    style: Styles.font12MediumGrey46(context).copyWith(height: 1.9),
                  ),
              ],
            ),
          ),
        if (result != null) ...[
          SizedBox(height: AppConstants.height20(context)),
          _buildResult(context, module, result),
        ],
        if (module.questions.isNotEmpty && result == null) ...[
          SizedBox(height: AppConstants.height24(context)),
          Text("quiz".tr(), style: Styles.font16SemiBoldBlack(context)),
          SizedBox(height: AppConstants.height15(context)),
          for (int i = 0; i < module.questions.length; i++) ...[
            if (i != 0) SizedBox(height: AppConstants.height10(context)),
            _buildQuestion(context, module.questions[i], i + 1),
          ],
          SizedBox(height: AppConstants.height24(context)),
          DefaultButton(
            text: "submit_quiz".tr(),
            gradient: AppColors.brandGradient,
            borderRadius: AppConstants.sp15(context),
            isEnabled: !state.isSubmitting,
            onPress: () => submit(module),
          ),
        ],
      ],
    );
  }

  Widget _buildResult(BuildContext context, TrainingModuleModel module, QuizResultModel result) {
    final color = result.passed ? AppColors.secondaryColor : AppColors.red;
    final score = result.score == null ? null : NumberFormat("#0.#", context.locale.languageCode).format(result.score);

    return Container(
      padding: EdgeInsets.all(AppConstants.sp20(context)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          Icon(
            result.passed ? Icons.verified_rounded : Icons.replay_rounded,
            color: color,
            size: MediaQuery.of(context).size.height * .05,
          ),
          SizedBox(height: AppConstants.height10(context)),
          Text(
            (result.passed ? "quiz_passed" : "quiz_failed").tr(),
            style: Styles.font16SemiBoldBlack(context).copyWith(color: color),
          ),
          if (score != null) ...[
            SizedBox(height: AppConstants.height5(context)),
            Text("quiz_score".tr(namedArgs: {"score": score}), style: Styles.font12MediumGrey46(context)),
          ],
          if (result.certificateIssued) ...[
            SizedBox(height: AppConstants.height5(context)),
            Text("certificate_issued".tr(), style: Styles.font12MediumBlack(context).copyWith(color: color)),
          ],
          if (!result.passed) ...[
            SizedBox(height: AppConstants.height15(context)),
            DefaultButton(
              text: "try_again".tr(),
              backgroundColor: Colors.white,
              textColor: AppColors.primarySwatchColor,
              hasBorder: true,
              borderColor: AppColors.primarySwatchColor,
              borderRadius: AppConstants.sp15(context),
              onPress: () {
                answers.clear();
                context.read<TrainingCubit>().openModule(module.id);
              },
            ),
          ],
        ],
      ),
    );
  }

  /// One answer choice, in the same radio row style as the reason pickers.
  Widget _buildOption(BuildContext context, QuizQuestionModel question, QuizOptionModel option) {
    final bool selected = answers[question.id] == option.value;

    return InkWell(
      onTap: () => setState(() => answers[question.id] = option.value),
      borderRadius: BorderRadius.circular(AppConstants.sp10(context)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppConstants.height5(context)),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: MediaQuery.of(context).size.height * .022,
              color: selected ? AppColors.primarySwatchColor : AppColors.neutralColor[300],
            ),
            SizedBox(width: AppConstants.width10(context)),
            Expanded(child: Text(option.label, style: Styles.font12MediumBlack(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(BuildContext context, QuizQuestionModel question, int order) {
    return Container(
      padding: EdgeInsets.all(AppConstants.sp15(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: const Color(0xffEDEFF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$order. ${question.text}",
            style: Styles.font14MediumBlack(context).copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: AppConstants.height10(context)),
          if (question.options.isEmpty)
            TextField(
              onChanged: (value) => answers[question.id] = value,
              decoration: InputDecoration(
                hintText: "your_answer".tr(),
                hintStyle: Styles.hintText(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.sp10(context))),
              ),
            )
          else
            for (final option in question.options) _buildOption(context, question, option),
        ],
      ),
    );
  }
}
