import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/shared_repo/models/app_settings_model.dart';
import 'package:digital_trade_portal_driver/core/shared_repo/models/banners_model.dart';
import 'package:digital_trade_portal_driver/core/shared_repo/models/blocks_model.dart';
import 'package:digital_trade_portal_driver/core/shared_repo/models/categories_model.dart';
import 'package:digital_trade_portal_driver/core/shared_repo/models/cities_model.dart';
import 'package:digital_trade_portal_driver/core/shared_repo/models/customer_cities_model.dart';
import 'package:digital_trade_portal_driver/core/shared_repo/models/interests_model.dart';
import 'package:digital_trade_portal_driver/core/shared_repo/models/my_interests_model.dart';
import 'package:digital_trade_portal_driver/core/shared_repo/models/nationalites_model.dart';
import 'package:digital_trade_portal_driver/core/shared_repo/models/pages_model.dart';

abstract class SharedRepo {
  Future<Either<Failure, AppSettingsModel>> getAppSettings();

  Future<Either<Failure, AllCitiesModel>> getAllCities();

  Future<Either<Failure, CategoriesModelModel>> getCategoriesByPlugin({
    required String pluginName,
    required Map<String, dynamic> data,
  });

  Future<Either<Failure, NationalitiesModel>> getNationalities();
  Future<Either<Failure, PagesModel>> getPages({required String slug});
  Future<Either<Failure, BannersModel>> getBanners({required Map<String, dynamic> data});

  Future<Either<Failure, InterestsModel>> getInterests();

  Future<Either<Failure, CustomerCitiesModel>> getCustomerCities();

  Future<Either<Failure, MyInterestsModel>> getMyInterests();

  Future<Either<Failure, MyInterestsModel>> saveMyInterests({required List<int> interests});

  Future<Either<Failure, BlocksModel>> getBlocks({required Map<String, dynamic> data});
}
