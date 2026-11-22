import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// The plugin on the web: nothing native to register (the browser check is
/// Dart, `WincheTurnstile`); declared so Flutter lists the web as supported.
class WincheIntegrityWeb {
  /// Called by Flutter's web plugin registrant.
  static void registerWith(Registrar registrar) {}
}
