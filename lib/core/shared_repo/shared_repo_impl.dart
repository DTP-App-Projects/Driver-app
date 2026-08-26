import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/shared_repo/shared_repo.dart';
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
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/endpoints.dart';
import '../../../../core/utils/services/remote_services/api_service.dart';

class SharedRepoImpl implements SharedRepo {
  final ApiService? apiService;

  SharedRepoImpl(this.apiService);

  @override
  Future<Either<Failure, AppSettingsModel>> getAppSettings() async {
    try {
      var response = await apiService!.get(endPoint: EndPoints.appSettings);
      return right(AppSettingsModel.fromJson(response.data));
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      } else {
        return left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, AllCitiesModel>> getAllCities() async {
    try {
      var response = await apiService!.get(endPoint: EndPoints.allCities);
      return right(AllCitiesModel.fromJson(response.data));
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      } else {
        return left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, CategoriesModelModel>> getCategoriesByPlugin({
    required String pluginName,
    required Map<String, dynamic> data,
  }) async {
    try {
      var response = await apiService!.get(
        endPoint: EndPoints.categories(pluginName: pluginName),
        query: data,
      );
      return right(CategoriesModelModel.fromJson(response.data));
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      } else {
        return left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, NationalitiesModel>> getNationalities() async {
    try {
      var response = await apiService!.get(endPoint: EndPoints.nationality, query: {
        "pagination": false
      });
      return right(NationalitiesModel.fromJson(response.data));
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      } else {
        return left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, PagesModel>> getPages({required String slug}) async {
    try {
      var response = await apiService!.get(endPoint: EndPoints.pages(slug),);
      return right(PagesModel.fromJson(response.data));
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      } else {
        return left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, BannersModel>> getBanners({required Map<String, dynamic> data}) async {
    try {
      var response = await apiService!.get(
        endPoint: EndPoints.banners,
        query: data,
      );
      return right(BannersModel.fromJson(response.data));
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      } else {
        return left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, InterestsModel>> getInterests() async {
    try {
      var response = await apiService!.get(endPoint: EndPoints.interests);
      return right(InterestsModel.fromJson(response.data));
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      } else {
        return left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, CustomerCitiesModel>> getCustomerCities() async {
    try {
      var response = await apiService!.get(endPoint: EndPoints.customerCities);
      return right(CustomerCitiesModel.fromJson(response.data));
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      } else {
        return left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, MyInterestsModel>> getMyInterests() async {
    try {
      var response = await apiService!.get(endPoint: EndPoints.myInterests, sendToken: true);
      return right(MyInterestsModel.fromJson(response.data));
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      } else {
        return left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, MyInterestsModel>> saveMyInterests({required List<int> interests}) async {
    try {
      // The `interests` key must always be present — an empty list clears them.
      var response = await apiService!.postData(
        endPoint: EndPoints.myInterests,
        sendToken: true,
        data: {"interests": interests},
      );
      return right(MyInterestsModel.fromJson(response.data));
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      } else {
        return left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, BlocksModel>> getBlocks({required Map<String, dynamic> data}) async {
    try {
      var response = await apiService!.get(endPoint: EndPoints.blocks, query: data);
      return right(BlocksModel.fromJson(response.data));
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      } else {
        return left(ServerFailure(e.toString()));
      }
    }
  }
}
