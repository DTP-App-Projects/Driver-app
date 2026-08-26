import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/main_layout/presentation/view_model/change_nav_bar_status/change_nav_bar_status_cubit.dart';
import 'package:digital_trade_portal_driver/features/main_layout/presentation/views/widgets/nav_tabs.dart';

/// A single tab: the icon sits in a brand gradient pill while selected, the
/// label picks up the brand colour with it.
class BottomNavBarItem extends StatelessWidget {
  const BottomNavBarItem({super.key, required this.tab, required this.index});

  final NavTab tab;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cubit = ChangeNavBarStatusCubit.get(context);
    final bool isSelected = cubit.currentIndex == index;
    final Color inactiveColor = AppColors.neutralColor[500]!;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (!isSelected) cubit.changeNavBarIndex(index);
        },
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppConstants.height10(context)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(
                  horizontal: AppConstants.width20(context),
                  vertical: AppConstants.height5(context),
                ),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.brandGradient : null,
                  borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
                ),
                child: SvgPicture.asset(
                  tab.icon,
                  width: MediaQuery.of(context).size.height * .028,
                  height: MediaQuery.of(context).size.height * .028,
                  colorFilter: ColorFilter.mode(
                    isSelected ? Colors.white : inactiveColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              SizedBox(height: AppConstants.height5(context)),
              Text(
                tab.titleKey.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Styles.font11MediumBlack(context).copyWith(
                  color: isSelected ? AppColors.primarySwatchColor : inactiveColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
