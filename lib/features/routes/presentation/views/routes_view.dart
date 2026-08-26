import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/routes/data/models/route_model.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/routes_details_view.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/views/widgets/route_item.dart';

class RoutesView extends StatefulWidget {
  const RoutesView({super.key});

  @override
  State<RoutesView> createState() => _RoutesViewState();
}

class _RoutesViewState extends State<RoutesView> {
  // TODO: replace with the routes endpoint once it exists.
  late final List<RouteModel> routes = RouteModel.demoData();

  /// Newest route first.
  List<RouteModel> get sortedRoutes => [...routes]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return Scaffold(
          backgroundColor: const Color(0xffF5F7FA),
          body: SafeArea(
            child: Column(
              children: [
                CustomAppBar(title: "routes".tr()),
                Expanded(child: routes.isEmpty ? _buildEmptyState(context) : _buildList(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context) {
    final items = sortedRoutes;

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
    );
  }
}
