import 'package:digital_trade_portal_driver/core/shared_widgets/custom_back_button.dart';
import 'package:digital_trade_portal_driver/core/utils/assets/assets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/notification/data/models/notification_model.dart';
import 'package:digital_trade_portal_driver/features/notification/presentation/views/widgets/notification_item.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NotificationView extends StatefulWidget {
  const NotificationView({super.key});

  @override
  State<NotificationView> createState() => _NotificationViewState();
}

class _NotificationViewState extends State<NotificationView> {
  // TODO: replace with the notifications endpoint once it exists.
  late final List<NotificationModel> notifications = NotificationModel.demoData();

  int get unreadCount => notifications.where((notification) => !notification.isRead).length;

  void markAsRead(NotificationModel notification) {
    if (notification.isRead) return;
    setState(() => notification.isRead = true);
  }

  void markAllAsRead() {
    setState(() {
      for (final notification in notifications) {
        notification.isRead = true;
      }
    });
  }

  /// The whole feed as one list, newest first.
  List<NotificationModel> get sortedNotifications =>
      [...notifications]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F7FA),
          body: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(child: notifications.isEmpty ? _buildEmptyState(context) : _buildList(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
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
              onPressed: markAllAsRead,
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

  Widget _buildList(BuildContext context) {
    final items = sortedNotifications;

    return ListView.separated(
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

    return Center(
      child: Column(
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
              color: AppColors.primarySwatchColor,
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
    );
  }
}
