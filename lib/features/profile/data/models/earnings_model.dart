import 'package:digital_trade_portal_driver/core/utils/json_utils.dart';

class EarningsBonus {
  const EarningsBonus({required this.id, this.type, this.amount, this.description, this.awardedOn});

  final int id;
  final String? type;
  final double? amount;
  final String? description;
  final String? awardedOn;

  factory EarningsBonus.fromJson(Map<String, dynamic> json) => EarningsBonus(
    id: JsonUtils.asInt(json["id"]) ?? 0,
    type: JsonUtils.asString(json["type"]),
    amount: JsonUtils.asDouble(json["amount"]),
    description: JsonUtils.asString(json["description"]),
    awardedOn: JsonUtils.asString(json["awarded_on"]),
  );
}

/// One pay period: the live current month or a closed payroll row.
class EarningsPeriod {
  const EarningsPeriod({
    required this.period,
    this.baseSalary,
    this.ratePerDelivery,
    this.deliveriesCount = 0,
    this.deliveriesPay,
    this.bonusesTotal,
    this.deductionsTotal,
    this.netTotal,
    this.currency,
    this.status,
    this.paidAt,
    this.bonuses = const [],
  });

  final String period;
  final double? baseSalary;
  final double? ratePerDelivery;
  final int deliveriesCount;
  final double? deliveriesPay;
  final double? bonusesTotal;
  final double? deductionsTotal;
  final double? netTotal;
  final String? currency;
  final String? status;
  final String? paidAt;
  final List<EarningsBonus> bonuses;

  factory EarningsPeriod.fromJson(Map<String, dynamic> json) => EarningsPeriod(
    period: JsonUtils.asString(json["period"]) ?? "",
    baseSalary: JsonUtils.asDouble(json["base_salary"]),
    ratePerDelivery: JsonUtils.asDouble(json["rate_per_delivery"]),
    deliveriesCount: JsonUtils.asInt(json["deliveries_count"]) ?? 0,
    deliveriesPay: JsonUtils.asDouble(json["deliveries_pay"]),
    bonusesTotal: JsonUtils.asDouble(json["bonuses_total"]),
    deductionsTotal: JsonUtils.asDouble(json["deductions_total"]),
    netTotal: JsonUtils.asDouble(json["net_total"]),
    currency: JsonUtils.asString(json["currency"]),
    status: JsonUtils.asString(json["status"]),
    paidAt: JsonUtils.asString(json["paid_at"]),
    bonuses: [for (final item in JsonUtils.asMapList(json["bonuses"])) EarningsBonus.fromJson(item)],
  );
}

/// `GET /api/v2/driver/earnings` → `data`.
class EarningsModel {
  const EarningsModel({this.currency, this.current, this.history = const []});

  final String? currency;
  final EarningsPeriod? current;
  final List<EarningsPeriod> history;

  factory EarningsModel.fromJson(Map<String, dynamic> json) {
    final current = JsonUtils.asMapOrNull(json["current"]);
    return EarningsModel(
      currency: JsonUtils.asString(json["currency"]),
      current: current == null ? null : EarningsPeriod.fromJson(current),
      history: [for (final item in JsonUtils.asMapList(json["history"])) EarningsPeriod.fromJson(item)],
    );
  }
}

/// `GET /api/v2/driver/performance` → `data`. The KPI set depends on the
/// backend build, so it is kept as ordered numeric/text metrics.
class PerformanceModel {
  const PerformanceModel({required this.metrics, this.since, this.until});

  final Map<String, dynamic> metrics;
  final String? since;
  final String? until;

  /// Flat scalar KPIs (nested objects such as the period are left out).
  List<MapEntry<String, dynamic>> get scalarMetrics => [
    for (final entry in metrics.entries)
      if (entry.value is num || entry.value is String || entry.value is bool) entry,
  ];

  factory PerformanceModel.fromJson(Map<String, dynamic> json) {
    final period = JsonUtils.asMapOrNull(json["period"]);
    return PerformanceModel(
      metrics: Map.of(json)..removeWhere((key, _) => key == "period" || key == "driver" || key == "driver_id"),
      since: JsonUtils.asString(json["since"] ?? period?["since"] ?? period?["from"]),
      until: JsonUtils.asString(json["until"] ?? period?["until"] ?? period?["to"]),
    );
  }
}
