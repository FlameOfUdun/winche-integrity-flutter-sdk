# Changelog

## 0.1.0

First version of Winche Integrity for Flutter (winche_core 1.1.0):

- `WinchePlatformIntegrity`: the proof the platform has, with a debug token where there's none.
- `WincheAppAttest`: Apple's App Attest on iOS 15+ and macOS 12+. A key is attested once, then each proof is an
  assertion with it; a key the project no longer knows, or one gone from the Secure Enclave, is replaced.
- `WinchePlayIntegrity`: Google Play Integrity's standard API on Android 6+ (with the Play Store). It's prepared once per
  Google Cloud project number (which the project sends with each challenge), then a token per challenge.
