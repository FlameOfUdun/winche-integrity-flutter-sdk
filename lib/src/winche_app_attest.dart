import 'package:flutter/services.dart';
import 'package:winche_core/winche_core.dart';

import 'platform.dart';

/// Proof by Apple's App Attest (iOS 14+, macOS 11+, on a real device): the app
/// makes a key in the Secure Enclave, has Apple attest it once, then signs each
/// challenge from the project with it. The project needs the app's Apple team
/// id and bundle id (Integrity in the console).
///
/// ```dart
/// final app = Winche.initializeApp(options: DefaultWincheOptions.currentPlatform);
/// app.useIntegrity(kDebugMode && !await WincheAppAttest.isSupported()
///     ? const WincheDebugIntegrity(String.fromEnvironment('WINCHE_DEBUG_TOKEN'))   // simulators
///     : WincheAppAttest());
/// ```
///
/// The key's id is kept on the device per app id; a key the project no longer
/// knows (the app's Apple ids changed, its keys were forgotten) is replaced by
/// a new one at once.
final class WincheAppAttest extends WincheIntegrityProvider {
  final WincheAppAttestPlatform _platform;
  final Set<String> _startOver = {};

  /// App Attest, through [platform] (tests give their own).
  WincheAppAttest({WincheAppAttestPlatform platform = const WincheAppAttestPlatform()}) : _platform = platform;

  /// Whether this device can prove itself with App Attest (simulators can't).
  static Future<bool> isSupported({WincheAppAttestPlatform platform = const WincheAppAttestPlatform()}) async {
    try {
      return await platform.isSupported();
    } on MissingPluginException {
      return false;   // not iOS or macOS
    }
  }

  @override
  String get provider => 'appAttest';

  /// The app the last proof was for, and whether it was an attestation.
  String? _lastApp;
  bool _lastAttested = false;

  @override
  Future<Map<String, Object?>> proof(WincheIntegrityRequest request) async {
    final app = request.appId;
    final keyName = '$app.key', attestedName = '$app.attested';
    if (_startOver.remove(app)) {
      await _platform.remove(keyName);
      await _platform.remove(attestedName);
    }
    final challenge = await request.challenge();
    for (var tries = 0; ; tries++) {
      var keyId = await _platform.load(keyName);
      final attested = keyId != null && await _platform.load(attestedName) == 'yes';
      try {
        if (keyId == null) {
          keyId = await _platform.generateKey();
          await _platform.save(keyName, keyId);
        }
        if (!attested) {
          final attestation = await _platform.attestKey(keyId, challenge);
          // Sent now; if the project never got it, its next assertion is refused as an unknown key and it starts over.
          await _platform.save(attestedName, 'yes');
          _lastApp = app;
          _lastAttested = true;
          return {'keyId': keyId, 'challenge': challenge, 'attestation': attestation};
        }
        _lastApp = app;
        _lastAttested = false;
        return {'keyId': keyId, 'challenge': challenge, 'assertion': await _platform.generateAssertion(keyId, challenge)};
      } on PlatformException catch (e) {
        // The key is gone from the Secure Enclave (a restored backup, a new device): a new one, once.
        if (e.code != 'invalidKey' || tries > 0) rethrow;
        await _platform.remove(keyName);
        await _platform.remove(attestedName);
      }
    }
  }

  @override
  bool refused(String? reason) {
    // A key the project doesn't know: a new one, now. An attestation refused (another app's ids, a development build
    // the app doesn't accept): a new key on the next try, a minute later.
    final app = _lastApp;
    if (app != null && (reason == 'integrity-unknown-key' || (reason == 'integrity-rejected' && _lastAttested))) _startOver.add(app);
    return reason == 'integrity-unknown-key' && app != null;
  }
}
