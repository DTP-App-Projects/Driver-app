import 'package:dartz/dartz.dart';
import 'package:digital_trade_portal_driver/core/errors/failure.dart';
import 'package:digital_trade_portal_driver/features/training/data/models/training_models.dart';

/// 12 · Training & certification (wrapped `{status, data}` envelope).
abstract class TrainingRepo {
  /// `GET /api/v2/driver/training/curriculum`.
  Future<Either<Failure, CurriculumModel>> getCurriculum();

  /// `GET /api/v2/driver/training/modules/{id}`.
  Future<Either<Failure, TrainingModuleModel>> getModule({required int moduleId});

  /// `POST /api/v2/driver/training/modules/{id}/start`.
  Future<Either<Failure, Unit>> startModule({required int moduleId});

  /// `POST /api/v2/driver/training/modules/{id}/submit`.
  Future<Either<Failure, QuizResultModel>> submitQuiz({required int moduleId, required Map<int, String> answers});

  /// `GET /api/v2/driver/training/certificate`.
  Future<Either<Failure, CertificationStatusModel>> getCertificate();
}
