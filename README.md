# winche_app_attest

Apple's **App Attest** for [Winche](https://github.com/FlameOfUdun/winche-server) Integrity: proof, on iOS and macOS,
that requests to a Winche project come from its own app, not a copy of it, a script or someone's curl.

The app makes a key in the device's Secure Enclave, has Apple attest it once, then signs each challenge from the project
with it. The project checks the attestation against Apple's root and every signature against the key, and gives the app
short-lived Integrity tokens, which every Winche SDK sends with its requests.

## Set up

1. **In the project** (console → **Integrity**, or `winche apps:create`): give the app its Apple **bundle id** and
   **team id**. To try it from Xcode, turn on **Accept development builds** (turn it off again before you enforce in
   production).
2. **In Xcode**: add the **App Attest** capability to the app target (Signing & Capabilities). Builds run from Xcode use
   the development environment; set `com.apple.developer.devicecheck.appattest-environment` to `production` in the
   entitlements to test as TestFlight and the App Store do.
3. **In the app**:

```sh
flutter pub add winche_app_attest
```

```dart
import 'package:winche_app_attest/winche_app_attest.dart';

final app = Winche.initializeApp(options: DefaultWincheOptions.currentPlatform);   // appId from winche configure --app
app.useIntegrity(kDebugMode && !await WincheAppAttest.isSupported()
    ? const WincheDebugIntegrity(String.fromEnvironment('WINCHE_DEBUG_TOKEN'))   // simulators: a debug token
    : WincheAppAttest());
```

Simulators have no App Attest: `WincheAppAttest.isSupported()` is false there, so use a debug token (console →
Integrity → Debug tokens) in debug builds.

## What it does

- The first proof attests a new key (`attestKey`, for SHA-256 of a challenge from the project); every later one is an
  assertion (`generateAssertion`) with it. The key's id is kept in `UserDefaults` per app id (it isn't a secret: the key
  never leaves the Secure Enclave). Apple counts each assertion, so a copied one can't be sent twice.
- A key the project doesn't know (its keys were forgotten, the app's Apple ids changed) is replaced by a new one at once.
  A key gone from the Secure Enclave (a backup restored onto another device) is replaced too.
- A refused attestation (another app's ids, a development build the project doesn't accept) makes a new key on the next
  try, a minute later.

The privacy manifest declares the `UserDefaults` use (reason CA92.1). Nothing is sent anywhere but the project.

## Develop

```sh
flutter test
cd example && flutter build macos --debug   # compiles the Swift (iOS: flutter build ios --simulator)
```

Building the example from this repository needs its folder named `winche_app_attest` (Swift Package Manager names a
package by its folder); apps that install it from pub.dev aren't affected.

## License

MIT (`LICENSE`).
