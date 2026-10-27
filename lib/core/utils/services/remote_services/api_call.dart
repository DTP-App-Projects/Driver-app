import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_response.dart';

/// Runs one request and turns every outcome into `Either<Failure, T>`:
///
/// * transport errors and non 2xx responses → [ServerFailure]
/// * a 2xx whose envelope still says it failed (`success:false`,
///   wrapped `status: 4xx`) → [ServerFailure]
/// * anything [map] throws while parsing → [CustomError]
///
/// Repositories stay one-liners and the presentation layer only ever sees a
/// [Failure] with localized copy.
Future<Either<Failure, T>> apiCall<T>(
  Future<ApiResponse> Function() request,
  T Function(ApiResponse response) map,
) async {
  try {
    final response = await request();
    if (!response.isSuccess) return left(ServerFailure.fromApiResponse(response));
    return right(map(response));
  } catch (e) {
    return left(CustomError.getError(e));
  }
}
