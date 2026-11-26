## 0.1.1

- Needs winche_core 1.1.1: its error messages never carry a signed link's signature, a token or a password.

# Changelog

## 0.1.0

First version of Winche Integrity for Flutter (winche_core 1.1.0):

- `WinchePlatformIntegrity`: the proof the platform has, with a debug token where there's none.
- `WincheAppAttest`: Apple's App Attest on iOS 15+ and macOS 12+. A key is attested once, then each proof is an
  assertion with it; a key the project no longer knows, or one gone from the Secure Enclave, is replaced.
- `WinchePlayIntegrity`: Google Play Integrity's standard API on Android 7+ (with the Play Store). It's prepared once per
  Google Cloud project number (which the project sends with each challenge), then a token per challenge.
- `WincheTurnstile`: the browser check on the web, Cloudflare Turnstile (an invisible widget, the challenge as its
  cData), with the site key the project sends with each challenge.
- `WincheIntegrityUnsupported`: thrown where the proof can't be given at all (App Attest missing, Play Integrity
  without the Play Store or Play services, no Cloud project number or site key for the app). `WinchePlatformIntegrity`
  falls back to its debug token only then; a failure that may pass (the network, a Turnstile timeout, Play's
  CANNOT_BIND_TO_SERVICE) is reported and tried again later.
- The web is a listed platform (the plugin is Dart there).
