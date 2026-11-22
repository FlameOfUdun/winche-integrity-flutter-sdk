/// This device or build can't give the proof at all, as opposed to failing
/// this once: App Attest missing (a simulator), Play Integrity without the Play
/// Store or Play services (an emulator), no Google Cloud project number or
/// Turnstile site key for the app, the browser check off the web.
/// [WinchePlatformIntegrity] falls back to its debug token only on this.
final class WincheIntegrityUnsupported implements Exception {
  /// What's missing.
  final String message;

  /// The platform's own error, if there was one.
  final Object? cause;

  /// The proof can't be given here, for [message].
  const WincheIntegrityUnsupported(this.message, {this.cause});

  @override
  String toString() => 'WincheIntegrityUnsupported: $message';
}
