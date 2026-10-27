import 'package:easy_localization/easy_localization.dart';

/// Translates [key] when the language file has it, otherwise returns
/// [fallback] — without the "key not found" warning `tr()` logs. Used for
/// server driven labels (KPI names, statuses) that may grow over time.
String trOr(String key, String fallback) => trExists(key) ? tr(key) : fallback;

/// Humanises a server code such as `on_time_pct` when no translation exists.
String trOrHumanized(String key, String code) => trOr(key, code.replaceAll("_", " "));
