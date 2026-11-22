/// Winche Integrity for Flutter: proof that requests to a Winche project come
/// from its own app. [WinchePlatformIntegrity] picks the proof the platform
/// has: [WincheAppAttest] on iOS and macOS, [WinchePlayIntegrity] on Android,
/// [WincheTurnstile] (the browser check) on the web, a debug token elsewhere.
library;

export 'src/app_attest.dart' show WincheAppAttest;
export 'src/native.dart' show WincheIntegrityNative;
export 'src/platform_integrity.dart' show WinchePlatformIntegrity;
export 'src/play_integrity.dart' show WinchePlayIntegrity;
export 'src/turnstile.dart' show WincheTurnstile, TurnstileRun;
