import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_app_bar.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/custom_loading_item.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/info_row.dart';
import 'package:digital_trade_portal_driver/core/shared_widgets/toast.dart';
import 'package:digital_trade_portal_driver/core/utils/colors/colors.dart';
import 'package:digital_trade_portal_driver/core/utils/constants.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal_driver/core/utils/text_styles/styles.dart';
import 'package:digital_trade_portal_driver/features/my_cars/data/models/vehicle_model.dart';
import 'package:digital_trade_portal_driver/features/my_cars/data/repos/vehicles_repo_impl.dart';
import 'package:digital_trade_portal_driver/features/my_cars/presentation/view_models/vehicles/vehicles_cubit.dart';
import 'package:digital_trade_portal_driver/features/my_cars/presentation/views/widgets/assigned_vehicle_card.dart';
import 'package:digital_trade_portal_driver/features/my_cars/presentation/views/widgets/vehicle_item.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/driver_profile/driver_profile_cubit.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/views/widgets/content_page_body.dart';

class MyCarsView extends StatelessWidget {
  const MyCarsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => VehiclesCubit(
        getIt.get<VehiclesRepoImpl>(),
        assigned: context.read<DriverProfileCubit>().driver?.defaultVehicle,
      )..loadVehicles(),
      child: const _MyCarsBody(),
    );
  }
}

class _MyCarsBody extends StatelessWidget {
  const _MyCarsBody();

  Future<void> assign(BuildContext context, VehicleModel vehicle) async {
    final profileCubit = context.read<DriverProfileCubit>();
    final assigned = await context.read<VehiclesCubit>().assign(vehicle);
    if (assigned != null) profileCubit.applyVehicle(assigned);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
      builder: (context, langState) {
        return BlocConsumer<VehiclesCubit, VehiclesState>(
          listenWhen: (previous, current) => current.message != null,
          listener: (context, state) =>
              toast(text: state.message!.text, context: context, isSuccess: !state.message!.isError),
          builder: (context, state) {
            final assigned = state.assigned;

            return Scaffold(
              backgroundColor: const Color(0xffF5F7FA),
              body: SafeArea(
                child: Column(
                  children: [
                    CustomAppBar(title: "assigned_vehicle".tr()),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primarySwatchColor,
                        onRefresh: context.read<VehiclesCubit>().loadVehicles,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            AppConstants.width20(context),
                            AppConstants.height10(context),
                            AppConstants.width20(context),
                            AppConstants.height30(context),
                          ),
                          children: [
                            if (assigned != null) ...[
                              AssignedVehicleCard(vehicle: assigned),
                              SizedBox(height: AppConstants.height24(context)),
                              Text("vehicle_details".tr(), style: Styles.font16SemiBoldBlack(context)),
                              SizedBox(height: AppConstants.height15(context)),
                              _buildDetailsCard(context, assigned),
                              SizedBox(height: AppConstants.height24(context)),
                            ],
                            Text("available_vehicles".tr(), style: Styles.font16SemiBoldBlack(context)),
                            SizedBox(height: AppConstants.height15(context)),
                            ..._buildFleet(context, state),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailsCard(BuildContext context, VehicleModel vehicle) {
    return Container(
      padding: EdgeInsets.all(AppConstants.sp20(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.sp20(context)),
        border: Border.all(color: const Color(0xffEDEFF2)),
      ),
      child: Column(
        children: [
          InfoRow(label: "manufacturer".tr(), value: vehicle.manufacturer ?? "—"),
          SizedBox(height: AppConstants.height15(context)),
          const Divider(height: 1, color: Color(0xffF0F2F5)),
          SizedBox(height: AppConstants.height15(context)),
          InfoRow(
            label: "refrigerated".tr(),
            value: (vehicle.isRefrigerated ? "yes" : "no").tr(),
            valueColor: vehicle.isRefrigerated ? AppColors.secondaryColor : null,
          ),
          SizedBox(height: AppConstants.height15(context)),
          const Divider(height: 1, color: Color(0xffF0F2F5)),
          SizedBox(height: AppConstants.height15(context)),
          InfoRow(label: "manufacture_year".tr(), value: vehicle.year?.toString() ?? "—"),
        ],
      ),
    );
  }

  List<Widget> _buildFleet(BuildContext context, VehiclesState state) {
    if (state.isLoading && !state.hasLoaded) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppConstants.height30(context)),
          child: const CustomLoadingItem(),
        ),
      ];
    }

    if (state.failure != null && state.vehicles.isEmpty) {
      return [
        SizedBox(
          height: MediaQuery.of(context).size.height * .4,
          child: ContentErrorBody(
            message: state.failure!.errMessage,
            onRetry: context.read<VehiclesCubit>().loadVehicles,
          ),
        ),
      ];
    }

    if (state.vehicles.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppConstants.height30(context)),
          child: Text(
            "no_available_vehicles".tr(),
            textAlign: TextAlign.center,
            style: Styles.font12MediumGrey46(context).copyWith(height: 1.6),
          ),
        ),
      ];
    }

    return [
      for (int i = 0; i < state.vehicles.length; i++) ...[
        if (i != 0) SizedBox(height: AppConstants.height10(context)),
        VehicleItem(
          vehicle: state.vehicles[i],
          onTap: state.assigningId == null ? () => assign(context, state.vehicles[i]) : () {},
        ),
      ],
    ];
  }
}
