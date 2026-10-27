import 'dart:math';

/// RFC 4122 version 4 UUIDs, used as the idempotency key of every offline
/// capable action. Generated once per action and never regenerated on retry.
class Uuid {
  const Uuid._();

  static final Random _random = Random.secure();

  static String v4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
    return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-"
        "${hex.substring(16, 20)}-${hex.substring(20)}";
  }
}
