import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal_driver/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal_driver/core/utils/navigation_utility.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/cache_helper.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/cache_keys.dart';
import 'package:digital_trade_portal_driver/features/notification/presentation/view_models/notifications/notifications_cubit.dart';
import 'package:digital_trade_portal_driver/features/profile/presentation/view_models/driver_profile/driver_profile_cubit.dart';
import 'package:digital_trade_portal_driver/features/routes/presentation/view_models/today_route/today_route_cubit.dart';

class ChangeLanguageCubit extends Cubit<ChangeLanguageStates> {
  ChangeLanguageCubit() : super(ChangeLanguageInitState());

  Future<void> changeLanguage({required String lang, required BuildContext context}) async {
    if (lang != CacheKeysManger.getUserLanguage()) {
      context.setLocale(Locale(lang));
      CacheHelper.saveData(key: "lang", value: lang);
      emit(ChangeLanguageSuccessState());
      if (await CacheKeysManger.getToken() != "") {
        if (!context.mounted) return;
        // Persist the choice on the backend (`PUT /driver/language`) and
        // fetch the localized payloads again with the new Accept-Language.
        context.read<DriverProfileCubit>().setLanguage(lang);
        context.read<TodayRouteCubit>().loadTodayRoute(silent: true);
        context.read<NotificationsCubit>().loadNotifications(silent: true);
      }
    }

    if (context.mounted) NavigationUtils.navigateBack(context: context);
  }
}
