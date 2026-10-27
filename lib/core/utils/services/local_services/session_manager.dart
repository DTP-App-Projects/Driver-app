import 'package:flutter/foundation.dart';
import 'package:digital_trade_portal_driver/core/utils/roots/app_router.dart';
import 'package:digital_trade_portal_driver/core/utils/services/local_services/cache_keys.dart';

/// Owns the "session is gone" transition so it happens exactly once, whether
/// the driver logged out or the server rejected the token.
class SessionManager {
  const SessionManager._();

  static bool _expiring = false;

  /// Extra cleanup registered by the app (reset cubits, stop tracking…).
  static final List<VoidCallback> _onSessionCleared = [];

  static void addSessionClearedListener(VoidCallback listener) => _onSessionCleared.add(listener);

  static void removeSessionClearedListener(VoidCallback listener) => _onSessionCleared.remove(listener);

  /// Forgets the account locally and notifies listeners. Does not navigate.
  static Future<void> clear() async {
    await CacheKeysManger.clearSession();
    for (final listener in List.of(_onSessionCleared)) {
      listener();
    }
  }

  /// Called by the API client when the backend says the token is invalid:
  /// wipes the session and sends the driver back to the login screen.
  static Future<void> expire() async {
    if (_expiring) return;
    _expiring = true;
    try {
      await clear();
      AppRouter.router.go("/loginView");
    } finally {
      // Let the next expired session (after a new login) be handled again.
      Future.delayed(const Duration(seconds: 2), () => _expiring = false);
    }
  }
}
