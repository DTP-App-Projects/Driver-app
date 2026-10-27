import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_loading_item.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/repos/routes_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/route_history/route_history_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/routes_details_view.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/route_item.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/content_page_body.dart';

/// Completed routes of the driver, paginated (`GET /driver/history`).
class RoutesView extends StatelessWidget {
  const RoutesView({super.key, this.withBack = true});

  /// False when shown as a bottom tab, true when pushed from the profile.
  final bool withBack;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RouteHistoryCubit(getIt.get<RoutesRepoImpl>())..loadFirstPage(),
      child: _RoutesBody(withBack: withBack),
    );
  }
}

class _RoutesBody extends StatefulWidget {
  const _RoutesBody({required this.withBack});

  final bool withBack;

  @override
  State<_RoutesBody> createState() => _RoutesBodyState();
}

class _RoutesBodyState extends State<_RoutesBody> {
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.dispose();
  }

  /// Loads the next page a little before the end of the list is reached.
  void _onScroll() {
    if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
      context.read<RouteHistoryCubit>().loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F7FA),
          body: SafeArea(
            bottom: widget.withBack,
            child: Column(
              children: [
                CustomAppBar(title: "routes".tr(), withBack: widget.withBack),
                Expanded(
                  child: BlocBuilder<RouteHistoryCubit, RouteHistoryState>(
                    builder: (context, state) {
                      if (state.isLoading && !state.hasLoaded) return const CustomLoadingItem();
                      if (state.failure != null && state.routes.isEmpty) {
                        return ContentErrorBody(
                          message: state.failure!.errMessage,
                          onRetry: context.read<RouteHistoryCubit>().loadFirstPage,
                        );
                      }
                      return RefreshIndicator(
                        color: AppColors.primarySwatchColor,
                        onRefresh: context.read<RouteHistoryCubit>().loadFirstPage,
                        child: state.routes.isEmpty ? _buildEmptyState(context) : _buildList(context, state),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context, RouteHistoryState state) {
    final items = state.routes;

    return ListView.separated(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppConstants.width20(context),
        AppConstants.height10(context),
        AppConstants.width20(context),
        AppConstants.height30(context),
      ),
      itemCount: items.length + (state.isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => SizedBox(height: AppConstants.height10(context)),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: AppConstants.height10(context)),
            child: CustomLoadingItem(size: MediaQuery.of(context).size.width * .08),
          );
        }
        final route = items[index];
        return RouteItem(
          route: route,
          onTap: () => NavigationUtils.navigateTo(
            context: context,
            destinationScreen: RoutesDetailsView(route: route),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final iconSize = MediaQuery.of(context).size.height * .11;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * .2),
        Center(
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
                child: Icon(Icons.route_rounded, size: iconSize * .45, color: AppColors.primarySwatchColor),
              ),
              SizedBox(height: AppConstants.height20(context)),
              Text("no_routes_title".tr(), style: Styles.font16SemiBoldBlack(context)),
              SizedBox(height: AppConstants.height5(context)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppConstants.width30(context)),
                child: Text(
                  "no_routes_hint".tr(),
                  textAlign: TextAlign.center,
                  style: Styles.font12MediumGrey46(context).copyWith(height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
