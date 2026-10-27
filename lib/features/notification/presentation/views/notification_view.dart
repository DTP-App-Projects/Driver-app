import 'package:digital_trade_portal_driver/core/shared_widgets/custom_back_button.dart';
import 'package:digital_trade_portal_driver/core/utils/assets/assets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_loading_item.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/notification/data/models/notification_model.dart';
import 'package:digital_trade_portal_driver/features/notification/presentation/view_models/notifications/notifications_cubit.dart';
import 'package:digital_trade_portal_driver/features/notification/presentation/views/widgets/notification_item.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/content_page_body.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NotificationView extends StatefulWidget {
  const NotificationView({super.key});

  @override
  State<NotificationView> createState() => _NotificationViewState();
}

class _NotificationViewState extends State<NotificationView> {
  NotificationsCubit get cubit => context.read<NotificationsCubit>();

  @override
  void initState() {
    super.initState();
    // The inbox is polled: refresh on open, silently when a list is on screen.
    cubit.loadNotifications(silent: cubit.state.hasLoaded);
  }

  void markAsRead(NotificationModel notification) => cubit.markAsRead(notification);

  void markAllAsRead() => cubit.markAllAsRead();

  /// The whole feed as one list, newest first.
  List<NotificationModel> sortedNotifications(NotificationsState state) =>
      [...state.notifications]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return BlocConsumer<NotificationsCubit, NotificationsState>(
          listenWhen: (previous, current) => current.actionError != null,
          listener: (context, state) => toast(text: state.actionError!, context: context, isSuccess: false),
          builder: (context, state) {
            return Scaffold(
              backgroundColor: const Color(0xffF5F7FA),
              body: SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(context, state),
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

  Widget _buildBody(BuildContext context, NotificationsState state) {
    if (state.isLoading && !state.hasLoaded) return const CustomLoadingItem();
    if (state.failure != null && !state.hasLoaded) {
      return ContentErrorBody(message: state.failure!.errMessage, onRetry: cubit.loadNotifications);
    }

    return RefreshIndicator(
      color: AppColors.primarySwatchColor,
      onRefresh: () => cubit.loadNotifications(silent: true),
      child: state.notifications.isEmpty ? _buildEmptyState(context) : _buildList(context, state),
    );
  }

  Widget _buildAppBar(BuildContext context, NotificationsState state) {
    final unreadCount = state.unreadCount;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.width20(context),
        vertical: AppConstants.height15(context),
      ),
      child: Row(
        children: [
          CustomBackButton(),
          SizedBox(width: AppConstants.width15(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("notifications".tr(), style: Styles.font18SemiBoldBlack(context)),
                if (unreadCount > 0) ...[
                  SizedBox(height: AppConstants.height5(context) * .5),
                  Text(
                    "unread_count".tr(namedArgs: {"count": unreadCount.toString()}),
                    style: Styles.font11MediumGrey46(context),
                  ),
                ],
              ],
            ),
          ),
          if (unreadCount > 0)
            TextButton(
              onPressed: state.isMarkingAll ? null : markAllAsRead,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primarySwatchColor,
                padding: EdgeInsets.symmetric(horizontal: AppConstants.width10(context)),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                "mark_all_read".tr(),
                style: Styles.font12MediumBlack(
                  context,
                ).copyWith(color: AppColors.primarySwatchColor, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, NotificationsState state) {
    final items = sortedNotifications(state);

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppConstants.width20(context),
        AppConstants.height10(context),
        AppConstants.width20(context),
        AppConstants.height30(context),
      ),
      itemCount: items.length,
      separatorBuilder: (context, index) => SizedBox(height: AppConstants.height10(context)),
      itemBuilder: (context, index) {
        final notification = items[index];
        return NotificationItem(notification: notification, onTap: () => markAsRead(notification));
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final iconSize = MediaQuery.of(context).size.height * .11;

    // A list so pull to refresh keeps working on the empty state.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * .2),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primarySwatchColor.withValues(alpha: .08),
              ),
              child: SvgPicture.asset(
                AssetData.notification,
                height: iconSize * .45,
                width: iconSize * .45,
                colorFilter: const ColorFilter.mode(AppColors.primarySwatchColor, BlendMode.srcIn),
              ),
            ),
            SizedBox(height: AppConstants.height20(context)),
            Text("no_notifications_title".tr(), style: Styles.font16SemiBoldBlack(context)),
            SizedBox(height: AppConstants.height5(context)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppConstants.width30(context)),
              child: Text(
                "no_notifications_hint".tr(),
                textAlign: TextAlign.center,
                style: Styles.font12MediumGrey46(context).copyWith(height: 1.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
