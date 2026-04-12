import 'package:flutter/material.dart';

/// Root [ScaffoldMessenger] so SnackBars survive route replacement after login.
final GlobalKey<ScaffoldMessengerState> hiDooScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Avoid duplicate "signed in" SnackBar when [AuthChangeEvent.signedIn] fires
/// right after email/password login (we already show one from [LoginScreen]).
class LoginSnackCoordinator {
  static DateTime? _suppressUntil;

  static void suppressGlobalSignedInSnackFor(Duration d) {
    _suppressUntil = DateTime.now().add(d);
  }

  static bool get shouldSuppressGlobalSignedInSnack =>
      _suppressUntil != null && DateTime.now().isBefore(_suppressUntil!);

  static void clearSuppress() {
    _suppressUntil = null;
  }
}
