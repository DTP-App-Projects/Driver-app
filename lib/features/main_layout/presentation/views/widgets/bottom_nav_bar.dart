import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/features/main_layout/presentation/view_model/change_nav_bar_status/change_nav_bar_status_cubit.dart';
import 'package:digital_trade_portal_driver/features/main_layout/presentation/views/widgets/bottom_nav_bar_item.dart';
import 'package:digital_trade_portal_driver/features/main_layout/presentation/views/widgets/nav_tabs.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeNavBarStatusCubit, ChangeNavBarStatusState>(
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.neutralColor.withValues(alpha: .07),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            // Keep the items clear of the gesture bar now that the app draws edge to edge.
            padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom),
            child: Material(
              color: Colors.transparent,
              child: Row(
                children: List.generate(navTabs.length, (index) => BottomNavBarItem(tab: navTabs[index], index: index)),
              ),
            ),
          ),
        );
      },
    );
  }
}
