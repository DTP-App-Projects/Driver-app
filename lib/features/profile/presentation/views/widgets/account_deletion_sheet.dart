import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/tr_or.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_button.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_loading_item.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/default_text_form_field.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/profile/data/repos/profile_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/account_deletion/account_deletion_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/stop_sheet_widgets.dart';

/// Account deletion in one sheet: shows the existing request (status and,
/// for a rejection, the reason), lets the driver cancel an active one or
/// file a new one with an optional reason.
class AccountDeletionSheet extends StatelessWidget {
  const AccountDeletionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AccountDeletionCubit(getIt.get<ProfileRepoImpl>())..loadRequest(),
      child: const _AccountDeletionBody(),
    );
  }
}

class _AccountDeletionBody extends StatefulWidget {
  const _AccountDeletionBody();

  @override
  State<_AccountDeletionBody> createState() => _AccountDeletionBodyState();
}

class _AccountDeletionBodyState extends State<_AccountDeletionBody> {
  final TextEditingController reason = TextEditingController();

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountDeletionCubit, AccountDeletionState>(
      listener: (context, state) {
        if (state.submitted) toast(text: "deletion_request_sent".tr(), context: context);
        if (state.cancelled) toast(text: "deletion_request_cancelled".tr(), context: context);
        if (state.errMessage != null) toast(text: state.errMessage!, context: context, isSuccess: false);
      },
      builder: (context, state) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppConstants.width20(context),
            AppConstants.height15(context),
            AppConstants.width20(context),
            MediaQuery.of(context).viewInsets.bottom + AppConstants.height30(context),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                SizedBox(height: AppConstants.height20(context)),
                Text("delete_account".tr(), style: Styles.font18SemiBoldBlack(context).copyWith(color: AppColors.red)),
                SizedBox(height: AppConstants.height5(context)),
                Text("delete_account_hint".tr(), style: Styles.font12MediumGrey46(context).copyWith(height: 1.6)),
                SizedBox(height: AppConstants.height20(context)),
                if (state.isLoading && !state.hasLoaded)
                  const CustomLoadingItem()
                else if (state.hasActiveRequest)
                  _buildActiveRequest(context, state)
                else
                  _buildForm(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveRequest(BuildContext context, AccountDeletionState state) {
    final request = state.request!;
    final statusText = trOrHumanized("deletion_status_${request.status ?? "pending"}", request.status ?? "");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    color: const Color(0xffE8A317),
                    size: MediaQuery.of(context).size.height * .024,
                  ),
                  SizedBox(width: AppConstants.width10(context)),
                  Expanded(
                    child: Text(
                      "deletion_request_active".tr(),
                      style: Styles.font14MediumBlack(context).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppConstants.height10(context)),
              Text("${"status".tr()}: $statusText", style: Styles.font12MediumGrey46(context)),
              if (request.createdAt != null)
                Text(
                  DateFormat("d MMMM y", context.locale.languageCode).format(request.createdAt!),
                  style: Styles.font11MediumGrey46(context),
                ),
            ],
          ),
        ),
        SizedBox(height: AppConstants.height20(context)),
        DefaultButton(
          text: "cancel_deletion_request".tr(),
          backgroundColor: Colors.white,
          textColor: AppColors.primarySwatchColor,
          hasBorder: true,
          borderColor: AppColors.primarySwatchColor,
          borderRadius: AppConstants.sp15(context),
          isEnabled: !state.isSubmitting,
          onPress: context.read<AccountDeletionCubit>().cancel,
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, AccountDeletionState state) {
    final previous = state.request;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (previous != null && previous.rejectionReason != null) ...[
          SheetErrorBox(message: "deletion_request_rejected".tr(), lines: [previous.rejectionReason!]),
          SizedBox(height: AppConstants.height15(context)),
        ],
        DefaultTextFormField(
          controller: reason,
          textInputType: TextInputType.multiline,
          required: false,
          maxLines: 3,
          hintText: "deletion_reason_hint".tr(),
          borderRadius: AppConstants.sp15(context),
          contentPaddingVertical: AppConstants.height15(context),
          contentPaddingHorizontal: AppConstants.width15(context),
          borderSideEnabledColor: const Color(0xffEDEFF2),
        ),
        SizedBox(height: AppConstants.height20(context)),
        DefaultButton(
          text: "request_deletion".tr(),
          backgroundColor: AppColors.red,
          borderRadius: AppConstants.sp15(context),
          isEnabled: !state.isSubmitting,
          onPress: () => context.read<AccountDeletionCubit>().submit(reason: reason.text),
        ),
      ],
    );
  }
}
