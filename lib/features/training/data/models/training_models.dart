import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';

/// Certification state of the driver (`data.status` of the curriculum and
/// the whole payload of `/training/certificate`).
class CertificationStatusModel {
  const CertificationStatusModel({
    this.status,
    this.isCertified = false,
    this.certifiedAt,
    this.expiresAt,
    this.completedModules = 0,
    this.totalModules = 0,
    this.outstandingModuleIds = const [],
    this.raw = const {},
  });

  final String? status;
  final bool isCertified;
  final DateTime? certifiedAt;
  final DateTime? expiresAt;
  final int completedModules;
  final int totalModules;
  final List<int> outstandingModuleIds;
  final Map<String, dynamic> raw;

  factory CertificationStatusModel.fromJson(Map<String, dynamic> json) {
    final status = JsonUtils.asString(json["status"] ?? json["certification_status"]);
    return CertificationStatusModel(
      status: status,
      isCertified: JsonUtils.asBool(json["is_certified"] ?? json["certified"], fallback: status == "certified"),
      certifiedAt: JsonUtils.asDate(json["certified_at"] ?? json["issued_at"]),
      expiresAt: JsonUtils.asDate(json["expires_at"] ?? json["expiry"]),
      completedModules: JsonUtils.asInt(json["completed_modules"] ?? json["completed"]) ?? 0,
      totalModules: JsonUtils.asInt(json["total_modules"] ?? json["total"]) ?? 0,
      outstandingModuleIds: [
        for (final item in JsonUtils.asList(json["outstanding_modules"] ?? json["outstanding"]))
          if (item is Map) JsonUtils.asInt(item["id"]) ?? 0 else JsonUtils.asInt(item) ?? 0,
      ],
      raw: json,
    );
  }
}

class QuizQuestionModel {
  const QuizQuestionModel({required this.id, required this.text, this.type, this.options = const []});

  final int id;
  final String text;
  final String? type;

  /// Answer choices, each either a plain string or `{key/value/label}`.
  final List<QuizOptionModel> options;

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) => QuizQuestionModel(
    id: JsonUtils.asInt(json["id"] ?? json["question_id"]) ?? 0,
    text: JsonUtils.asString(json["question"] ?? json["text"] ?? json["title"]) ?? "",
    type: JsonUtils.asString(json["type"]),
    options: [
      for (final item in JsonUtils.asList(json["options"] ?? json["choices"] ?? json["answers"]))
        QuizOptionModel.fromJson(item),
    ],
  );
}

class QuizOptionModel {
  const QuizOptionModel({required this.value, required this.label});

  /// What is sent back as `answer`.
  final String value;
  final String label;

  factory QuizOptionModel.fromJson(dynamic json) {
    if (json is Map) {
      final map = JsonUtils.asMap(json);
      final value = JsonUtils.asString(map["key"] ?? map["value"] ?? map["id"]) ?? "";
      return QuizOptionModel(
        value: value,
        label: JsonUtils.asString(map["label"] ?? map["text"] ?? map["title"]) ?? value,
      );
    }
    final text = json?.toString() ?? "";
    return QuizOptionModel(value: text, label: text);
  }
}

/// A curriculum entry and, from `/training/modules/{id}`, its content.
class TrainingModuleModel {
  const TrainingModuleModel({
    required this.id,
    required this.title,
    this.description,
    this.content,
    this.status,
    this.order,
    this.durationMinutes,
    this.isRequired = true,
    this.score,
    this.passScore,
    this.questions = const [],
    this.startedAt,
    this.completedAt,
  });

  final int id;
  final String title;
  final String? description;
  final String? content;

  /// Driver progress on this module: `not_started`, `in_progress`, `passed`, `failed`…
  final String? status;
  final int? order;
  final int? durationMinutes;
  final bool isRequired;
  final double? score;
  final double? passScore;
  final List<QuizQuestionModel> questions;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isPassed => status == "passed" || status == "completed";

  bool get isStarted => status == "in_progress" || startedAt != null;

  factory TrainingModuleModel.fromJson(Map<String, dynamic> json) {
    final progress = JsonUtils.asMap(json["progress"]);
    final quiz = json["quiz"] is Map ? JsonUtils.asMap(json["quiz"]) : json;
    return TrainingModuleModel(
      id: JsonUtils.asInt(json["id"] ?? json["module_id"]) ?? 0,
      title: JsonUtils.asString(json["title"] ?? json["name"]) ?? "",
      description: JsonUtils.asString(json["description"] ?? json["summary"]),
      content: JsonUtils.asString(json["content"] ?? json["body"] ?? json["content_html"]),
      status: JsonUtils.asString(json["status"] ?? progress["status"] ?? json["progress_status"]),
      order: JsonUtils.asInt(json["order"] ?? json["sort_order"]),
      durationMinutes: JsonUtils.asInt(json["duration_minutes"] ?? json["duration"]),
      isRequired: JsonUtils.asBool(json["is_required"] ?? json["required"], fallback: true),
      score: JsonUtils.asDouble(json["score"] ?? progress["score"]),
      passScore: JsonUtils.asDouble(json["pass_score"] ?? json["passing_score"]),
      questions: [for (final item in JsonUtils.asMapList(quiz["questions"])) QuizQuestionModel.fromJson(item)],
      startedAt: JsonUtils.asDate(json["started_at"] ?? progress["started_at"]),
      completedAt: JsonUtils.asDate(json["completed_at"] ?? progress["completed_at"]),
    );
  }
}

/// `GET /api/v2/driver/training/curriculum` → `data`.
class CurriculumModel {
  const CurriculumModel({required this.status, required this.modules});

  final CertificationStatusModel status;
  final List<TrainingModuleModel> modules;

  factory CurriculumModel.fromJson(Map<String, dynamic> json) => CurriculumModel(
    status: CertificationStatusModel.fromJson(JsonUtils.asMap(json["status"])),
    modules: [
      for (final item in JsonUtils.asMapList(json["curriculum"] ?? json["modules"])) TrainingModuleModel.fromJson(item),
    ],
  );
}

/// Result of `POST /training/modules/{id}/submit`.
class QuizResultModel {
  const QuizResultModel({this.score, this.passed = false, this.certificateIssued = false, this.raw = const {}});

  final double? score;
  final bool passed;
  final bool certificateIssued;
  final Map<String, dynamic> raw;

  factory QuizResultModel.fromJson(Map<String, dynamic> json) => QuizResultModel(
    score: JsonUtils.asDouble(json["score"] ?? json["percentage"]),
    passed: JsonUtils.asBool(json["passed"] ?? json["is_passed"] ?? json["pass"]),
    certificateIssued: JsonUtils.asBool(json["certificate_issued"] ?? json["certified"]),
    raw: json,
  );
}
