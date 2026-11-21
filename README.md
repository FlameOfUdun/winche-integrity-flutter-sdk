# winche_integrity

[Winche](https://github.com/FlameOfUdun/winche-server) Integrity for Flutter: proof that requests to a Winche project
come from its own app, not a copy of it, a script or someone's curl. The app proves itself, gets a short-lived
Integrity token, and every Winche SDK sends it with its requests (winche_core does that once `useIntegrity` is set).

| Platform | Proof |
| --- | --- |
| iOS 15+, macOS 12+ (real devices) | Apple **App Attest** (`WincheAppAttest`) |
| Android 6+ with the Play Store | Google **Play Integrity**, standard API (`WinchePlayIntegrity`) |
| Simulators, Windows, Linux, web (for now) | a **debug token** from the console |

## Use

```sh
flutter pub add winche_integrity
```

```dart
import 'package:winche_integrity/winche_integrity.dart';

final app = Winche.initializeApp(options: DefaultWincheOptions.currentPlatform);   // appId from winche configure --app
app.useIntegrity(WinchePlatformIntegrity(
  // Where the platform has no proof (simulators, desktop): a debug token, in debug builds only.
  debugToken: kDebugMode ? const String.fromEnvironment('WINCHE_DEBUG_TOKEN') : null,
));
```

Or choose the proof yourself: `app.useIntegrity(WincheAppAttest())`, `app.useIntegrity(WinchePlayIntegrity())`.

## Set up: Apple (App Attest)

1. **In the project** (console → **Integrity**, or `winche apps:create`): give the app its Apple **bundle id** and
   **team id**. To try it from Xcode, turn on **Accept development builds** (and off again before enforcing in
   production).
2. **In Xcode**: add the **App Attest** capability to the app target. Builds run from Xcode use the development
   environment; set `com.apple.developer.devicecheck.appattest-environment` to `production` to test as TestFlight and
   the App Store do.

The first proof attests a new key (for SHA-256 of a challenge from the project); every later one is an assertion with
it. The key's id is kept in `UserDefaults` per app id (not a secret: the key never leaves the Secure Enclave). A key the
project doesn't know is replaced at once; a refused attestation makes a new key on the next try.

## Set up: Android (Play Integrity)

1. **In Google Cloud**: a project with the **Play Integrity API** enabled, and a **service account** with a JSON key.
2. **In Play Console**: the app → App integrity → link that Cloud project.
3. **In the project** (console → **Integrity**): give the app its **Android package** and the Cloud **project number**;
   set the service account's key file (Google Play Integrity card, or `winche integrity:play-account key.json`). Choose
   how good the device must be (device integrity by default), and whether builds from outside Google Play are accepted
   (debug and internal builds; with signing certificates set, only those signed with them).

Nothing goes in the app: the project sends the Cloud project number with each challenge. The app asks Play Integrity
for a token with the request hash SHA-256 of the challenge; the project has Google decode it and checks the package,
the hash, the time, the app's and the device's verdicts. A token provider Google says is no longer valid is prepared
again, once; Google's other errors come to `app.integrity.errors` (`PlatformException` code `playIntegrity`, with its
`code` and whether it's `retryable`).

## Develop

```sh
flutter test
cd example && flutter build apk --debug           # compiles the Kotlin
cd example && flutter build macos --debug         # compiles the Swift (iOS: flutter build ios --simulator)
```

Building the example for iOS or macOS from this repository needs the repository's folder named `winche_integrity`
(Swift Package Manager names a package by its folder): link it, e.g. `ln -s "$PWD" ../winche_integrity`, and build a copy
of the example that depends on `../winche_integrity`. Apps that install it from pub.dev aren't affected.

## License

MIT (`LICENSE`).
