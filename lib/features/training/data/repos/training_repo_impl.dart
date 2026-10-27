import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_call.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/api_service.dart';
import 'package:digital_trade_portal_driver/core/utils/services/remote_services/endpoints.dart';
import 'package:digital_trade_portal_driver/features/training/data/models/training_models.dart';
import 'package:digital_trade_portal_driver/features/training/data/repos/training_repo.dart';

class TrainingRepoImpl implements TrainingRepo {
  final ApiService apiService;

  TrainingRepoImpl(this.apiService);

  @override
  Future<Either<Failure, CurriculumModel>> getCurriculum() {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.trainingCurriculum),
      (response) => CurriculumModel.fromJson(response.dataMap),
    );
  }

  @override
  Future<Either<Failure, TrainingModuleModel>> getModule({required int moduleId}) {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.trainingModule(moduleId)),
      (response) => TrainingModuleModel.fromJson(JsonUtils.asMap(response.dataMap["module"] ?? response.data)),
    );
  }

  @override
  Future<Either<Failure, Unit>> startModule({required int moduleId}) {
    return apiCall(
      () => apiService.postData(endPoint: EndPoints.trainingModuleStart(moduleId), data: const {}),
      (_) => unit,
    );
  }

  @override
  Future<Either<Failure, QuizResultModel>> submitQuiz({required int moduleId, required Map<int, String> answers}) {
    return apiCall(
      () => apiService.postData(
        endPoint: EndPoints.trainingModuleSubmit(moduleId),
        data: {
          "answers": [
            for (final entry in answers.entries) {"question_id": entry.key, "answer": entry.value},
          ],
        },
      ),
      (response) => QuizResultModel.fromJson(response.dataMap),
    );
  }

  @override
  Future<Either<Failure, CertificationStatusModel>> getCertificate() {
    return apiCall(
      () => apiService.get(endPoint: EndPoints.trainingCertificate),
      (response) => CertificationStatusModel.fromJson(response.dataMap),
    );
  }
}
