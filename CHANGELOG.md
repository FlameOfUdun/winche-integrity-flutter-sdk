# Changelog

## 0.1.0

First version: `WincheAppAttest`, a `WincheIntegrityProvider` (winche_core 1.1.0) that proves the app to its Winche
project with Apple's App Attest on iOS 15+ and macOS 12+. The key is attested once and each later proof is an
assertion with it; a key the project no longer knows, or one gone from the Secure Enclave, is replaced.
