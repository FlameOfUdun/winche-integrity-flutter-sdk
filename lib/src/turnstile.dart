import 'package:winche_core/winche_core.dart';

import 'turnstile_runner_stub.dart' if (dart.library.js_interop) 'turnstile_runner_web.dart' as runner;

/// Runs a Cloudflare Turnstile widget for a site key, action and cData: its token. Tests give their own.
typedef TurnstileRun = Future<String> Function({required String siteKey, required String action, required String cData});

/// Proof on the web: Cloudflare **Turnstile**, the browser check. An invisible
/// widget (it shows itself only when Cloudflare wants the person to click)
/// solves a check for the project's challenge, and the project has Cloudflare
/// verify it. It tells a person's browser from a script, not which app calls:
/// weaker than App Attest or Play Integrity.
///
/// The project sends the widget's site key with each challenge (Integrity in
/// the console): nothing to set up in the app.
final class WincheTurnstile extends WincheIntegrityProvider {
  /// The action the widget runs with: the project checks it.
  static const action = 'winche-integrity';

  final TurnstileRun _run;

  /// The browser check, through [run] (tests give their own; on the web, Turnstile's own script).
  WincheTurnstile({TurnstileRun? run}) : _run = run ?? runner.runTurnstile;

  @override
  String get provider => 'turnstile';

  @override
  Future<Map<String, Object?>> proof(WincheIntegrityRequest request) async {
    final challenge = await request.challenge();
    final siteKey = challenge.webSiteKey ??
        (throw StateError("The project has no Turnstile site key for ${request.appId}: set it under Integrity in the console."));
    return {'challenge': challenge.value, 'token': await _run(siteKey: siteKey, action: action, cData: challenge.value)};
  }
}
