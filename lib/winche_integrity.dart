/// Apple's App Attest for Winche Integrity: proof, on iOS and macOS, that
/// requests come from the project's own app. See [WincheAppAttest].
library;

export 'src/native.dart' show WincheIntegrityNative;
export 'src/app_attest.dart' show WincheAppAttest;
