import 'package:flutter/material.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';

/// A titled white card grouping a set of [ProfileMenuTile]s, separated by
/// hairline dividers.
class ProfileMenuSection extends StatelessWidget {
  const ProfileMenuSection({super.key, required this.items, this.title});

  final String? title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppConstants.sp20(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: AppConstants.width5(context),
              bottom: AppConstants.height10(context),
            ),
            child: Text(title!, style: Styles.font12BoldBlack(context).copyWith(color: AppColors.grey46)),
          ),
        ],
        Material(
          color: Colors.white,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: const Color(0xffEDEFF2)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i != items.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: AppConstants.width20(context) * 2.6,
                      endIndent: AppConstants.width15(context),
                      color: const Color(0xffF3F5F7),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
