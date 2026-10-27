// intl (re-exported by easy_localization) ships its own TextDirection enum.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/tr_or.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_loading_item.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/info_row.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/stat_card.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/profile/data/models/earnings_model.dart';
import 'package:digital_trade_portal_driver/features/profile/data/repos/profile_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/earnings/earnings_cubit.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/content_page_body.dart';

/// Current month earnings, closed periods and the driver's KPIs, in the same
/// stat cards and fact rows the profile already uses.
class EarningsView extends StatelessWidget {
  const EarningsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EarningsCubit(getIt.get<ProfileRepoImpl>())..load(),
      child: BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
        builder: (context, langState) {
          return Scaffold(
            backgroundColor: const Color(0xffF5F7FA),
            body: SafeArea(
              child: Column(
                children: [
                  CustomAppBar(title: "earnings_performance".tr()),
                  Expanded(
                    child: BlocBuilder<EarningsCubit, EarningsState>(
                      builder: (context, state) {
                        if (state.isLoading && !state.hasLoaded) return const CustomLoadingItem();
                        if (state.failure != null && !state.hasLoaded) {
                          return ContentErrorBody(
                            message: state.failure!.errMessage,
                            onRetry: context.read<EarningsCubit>().load,
                          );
                        }
                        return RefreshIndicator(
                          color: AppColors.primarySwatchColor,
                          onRefresh: context.read<EarningsCubit>().load,
                          child: _buildContent(context, state),
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

  Widget _buildContent(BuildContext context, EarningsState state) {
    final earnings = state.earnings;
    final performance = state.performance;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppConstants.width20(context),
        AppConstants.height10(context),
        AppConstants.width20(context),
        AppConstants.height30(context),
      ),
      children: [
        if (earnings?.current != null) ...[
          _buildCurrentPeriod(context, earnings!.current!, earnings.currency),
          SizedBox(height: AppConstants.height24(context)),
        ],
        if (earnings != null && earnings.history.isNotEmpty) ...[
          Text("earnings_history".tr(), style: Styles.font16SemiBoldBlack(context)),
          SizedBox(height: AppConstants.height15(context)),
          for (final period in earnings.history) ...[
            _buildHistoryRow(context, period, earnings.currency),
            SizedBox(height: AppConstants.height10(context)),
          ],
          SizedBox(height: AppConstants.height15(context)),
        ],
        if (performance != null && performance.scalarMetrics.isNotEmpty) ...[
          Text("performance".tr(), style: Styles.font16SemiBoldBlack(context)),
          SizedBox(height: AppConstants.height15(context)),
          _buildPerformance(context, performance),
        ],
        if (earnings?.current == null && (performance == null || performance.scalarMetrics.isEmpty))
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppConstants.height30(context)),
            child: Text(
              "no_earnings_yet".tr(),
              textAlign: TextAlign.center,
              style: Styles.font12MediumGrey46(context).copyWith(height: 1.6),
            ),
          ),
      ],
    );
  }

  String _money(BuildContext context, double? value, String? currency) {
    final text = NumberFormat("#,##0.00", context.locale.languageCode).format(value ?? 0);
    return currency == null ? text : "$text $currency";
  }

  Widget _buildCurrentPeriod(BuildContext context, EarningsPeriod period, String? currency) {
    final locale = context.locale.languageCode;
    final number = NumberFormat.decimalPattern(locale);
    final currencyCode = period.currency ?? currency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppConstants.sp20(context)),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "current_period".tr(namedArgs: {"period": period.period}),
                style: Styles.font12MediumBlack(context).copyWith(color: Colors.white.withValues(alpha: .80)),
              ),
              SizedBox(height: AppConstants.height5(context)),
              Text(
                _money(context, period.netTotal, currencyCode),
                textDirection: TextDirection.ltr,
                style: Styles.font24BoldBlack(context).copyWith(color: Colors.white),
              ),
              SizedBox(height: AppConstants.height5(context) * .6),
              Text(
                "net_total".tr(),
                style: Styles.font11MediumBlack(context).copyWith(color: Colors.white.withValues(alpha: .75)),
              ),
            ],
          ),
        ),
        SizedBox(height: AppConstants.height15(context)),
        StatCardsRow(
          cards: [
            StatCard(
              label: "deliveries".tr(),
              value: number.format(period.deliveriesCount),
              color: AppColors.primarySwatchColor,
            ),
            StatCard(
              label: "bonuses".tr(),
              value: _money(context, period.bonusesTotal, null),
              color: AppColors.secondaryColor,
            ),
            StatCard(
              label: "deductions".tr(),
              value: _money(context, period.deductionsTotal, null),
              color: AppColors.red,
            ),
          ],
        ),
        SizedBox(height: AppConstants.height15(context)),
        Container(
          padding: EdgeInsets.all(AppConstants.sp20(context)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
            border: Border.all(color: const Color(0xffEDEFF2)),
          ),
          child: Column(
            children: [
              InfoRow(label: "base_salary".tr(), value: _money(context, period.baseSalary, currencyCode)),
              SizedBox(height: AppConstants.height15(context)),
              const Divider(height: 1, color: Color(0xffF0F2F5)),
              SizedBox(height: AppConstants.height15(context)),
              InfoRow(label: "rate_per_delivery".tr(), value: _money(context, period.ratePerDelivery, currencyCode)),
              SizedBox(height: AppConstants.height15(context)),
              const Divider(height: 1, color: Color(0xffF0F2F5)),
              SizedBox(height: AppConstants.height15(context)),
              InfoRow(label: "deliveries_pay".tr(), value: _money(context, period.deliveriesPay, currencyCode)),
              for (final bonus in period.bonuses) ...[
                SizedBox(height: AppConstants.height15(context)),
                const Divider(height: 1, color: Color(0xffF0F2F5)),
                SizedBox(height: AppConstants.height15(context)),
                InfoRow(
                  label: bonus.description ?? bonus.type ?? "bonuses".tr(),
                  value: _money(context, bonus.amount, currencyCode),
                  valueColor: AppColors.secondaryColor,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryRow(BuildContext context, EarningsPeriod period, String? currency) {
    final statusText = trOrHumanized("payout_${period.status ?? "pending"}", period.status ?? "");

    return Container(
      padding: EdgeInsets.all(AppConstants.sp15(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: const Color(0xffEDEFF2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(period.period, style: Styles.font14BoldBlack(context)),
                SizedBox(height: AppConstants.height5(context) * .6),
                Text(
                  "${"deliveries".tr()}: ${NumberFormat.decimalPattern(context.locale.languageCode).format(period.deliveriesCount)}"
                  "${period.status != null ? " • $statusText" : ""}",
                  style: Styles.font11MediumGrey46(context),
                ),
              ],
            ),
          ),
          Text(
            _money(context, period.netTotal, period.currency ?? currency),
            textDirection: TextDirection.ltr,
            style: Styles.font14BoldBlack(context).copyWith(color: AppColors.secondaryColor),
          ),
        ],
      ),
    );
  }

  /// The KPI set depends on the backend build, so every scalar metric is
  /// listed as a fact row with a humanised label (translated when known).
  Widget _buildPerformance(BuildContext context, PerformanceModel performance) {
    final locale = context.locale.languageCode;

    String label(String key) => trOrHumanized("kpi_$key", key);

    String value(dynamic raw) {
      if (raw is num) {
        return raw == raw.roundToDouble()
            ? NumberFormat.decimalPattern(locale).format(raw)
            : NumberFormat("#,##0.##", locale).format(raw);
      }
      if (raw is bool) return (raw ? "yes" : "no").tr();
      return raw.toString();
    }

    final metrics = performance.scalarMetrics;

    return Container(
      padding: EdgeInsets.all(AppConstants.sp20(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: const Color(0xffEDEFF2)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < metrics.length; i++) ...[
            if (i != 0) ...[
              SizedBox(height: AppConstants.height15(context)),
              const Divider(height: 1, color: Color(0xffF0F2F5)),
              SizedBox(height: AppConstants.height15(context)),
            ],
            InfoRow(label: label(metrics[i].key), value: value(metrics[i].value)),
          ],
        ],
      ),
    );
  }
}
