import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/exit_alert.dart';
import 'package:digital_trade_portal_driver/features/home/presentation/views/home_view.dart';
import 'package:digital_trade_portal_driver/features/main_layout/presentation/view_model/change_nav_bar_status/change_nav_bar_status_cubit.dart';
import 'package:digital_trade_portal_driver/features/main_layout/presentation/views/widgets/bottom_nav_bar.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/profile_view.dart';
import 'package:digital_trade_portal_driver/features/main_layout/presentation/views/widgets/nav_tabs.dart';

class MainLayoutView extends StatefulWidget {
  const MainLayoutView({super.key, this.initialIndex});

  final int? initialIndex;

  @override
  State<MainLayoutView> createState() => _MainLayoutViewState();
}

class _MainLayoutViewState extends State<MainLayoutView> {
  /// Tabs opened at least once, so screens are built lazily and keep their
  /// state afterwards.
  final Set<int> _visited = {};

  @override
  void initState() {
    super.initState();
    final navCubit = ChangeNavBarStatusCubit.get(context);
    if (widget.initialIndex != null) {
      navCubit.currentIndex = widget.initialIndex!;
    }
    _visited.add(navCubit.currentIndex);
  }

  Widget buildScreen(int index) {
    // لو الـ screen مش اتزارت، نرجع SizedBox.shrink() عشان ما تتبنيش
    if (!_visited.contains(index)) return const SizedBox.shrink();

    // Swap each entry for the real feature screen once it exists.
    switch (index) {
      case 0:
        return const HomeView();
      case 2:
        return const ProfileView();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        // Transparent so the white bottom bar itself reaches the screen edge.
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) exitDialog(context);
        },
        child: BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
          builder: (context, _) {
            return Scaffold(
              backgroundColor: Colors.white,
              resizeToAvoidBottomInset: false,
              body: BlocBuilder<ChangeNavBarStatusCubit, ChangeNavBarStatusState>(
                builder: (context, state) {
                  final currentIndex = ChangeNavBarStatusCubit.get(context).currentIndex;
                  _visited.add(currentIndex);

                  return IndexedStack(
                    index: currentIndex,
                    children: List.generate(navTabs.length, buildScreen),
                  );
                },
              ),
              bottomNavigationBar: const BottomNavBar(),
            );
          },
        ),
      ),
    );
  }
}
