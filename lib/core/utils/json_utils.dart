/// Tolerant JSON readers. The backend encodes with `JSON_NUMERIC_CHECK`, so a
/// phone number, an all digit SKU or an id can arrive as either a number or a
/// string depending on the row. Every reader accepts both and never throws.
class JsonUtils {
  const JsonUtils._();

  static int? asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is bool) return value ? 1 : 0;
    return int.tryParse(value.toString().trim()) ?? double.tryParse(value.toString().trim())?.toInt();
  }

  static double? asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  /// Keeps leading zeros: a phone that arrived as a string stays a string.
  static String? asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    return value.toString();
  }

  static bool asBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (text == "true" || text == "1" || text == "yes") return true;
    if (text == "false" || text == "0" || text == "no" || text.isEmpty) return false;
    return fallback;
  }

  static Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry(key.toString(), item));
    return const {};
  }

  static Map<String, dynamic>? asMapOrNull(dynamic value) => value is Map ? asMap(value) : null;

  static List<dynamic> asList(dynamic value) => value is List ? value : const [];

  static List<Map<String, dynamic>> asMapList(dynamic value) => [
    for (final item in asList(value))
      if (item is Map) asMap(item),
  ];

  static List<String> asStringList(dynamic value) => [
    for (final item in asList(value))
      if (item != null) item.toString(),
  ];

  /// Server timestamps come as `YYYY-MM-DD HH:MM:SS` or ISO 8601.
  static DateTime? asDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text) ?? DateTime.tryParse(text.replaceFirst(" ", "T"));
  }

  /// Format the server expects for timestamps it stores: `YYYY-MM-DD HH:MM:SS`.
  static String formatServerDateTime(DateTime date) {
    String two(int value) => value.toString().padLeft(2, "0");
    return "${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}:${two(date.second)}";
  }

  static String formatServerDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, "0");
    return "${date.year}-${two(date.month)}-${two(date.day)}";
  }
}
