import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:winche_core/winche_core.dart';

import 'native.dart';
import 'unsupported.dart';

/// Proof by Google Play Integrity (the standard API; Android 7+ with the Play
/// Store and Play services): a token from Google for each challenge, which the
/// project has Google decode and checks (this app, this challenge, a build
/// Google Play knows, a good enough device).
///
/// The project gives the app its Google Cloud project number with each
/// challenge (Integrity in the console), and keeps the Google service account
/// it decodes tokens with: nothing to set up in the app.
final class WinchePlayIntegrity extends WincheIntegrityProvider {
  final WincheIntegrityNative _native;

  /// Play Integrity, through [native] (tests give their own).
  WinchePlayIntegrity({WincheIntegrityNative native = const WincheIntegrityNative()}) : _native = native;

  @override
  String get provider => 'playIntegrity';

  /// What the app asks Play Integrity for: SHA-256 of [challenge]'s UTF-8, lower-case hex.
  static String requestHash(String challenge) => sha256.convert(utf8.encode(challenge)).toString();

  /// Google's error codes for a device that can't run Play Integrity at all
  /// (no Play Store or Play services, too old, not reachable): an emulator,
  /// mostly. Others (network, too many requests, Google's servers) may work later.
  static const unsupportedCodes = {
    -1, // API_NOT_AVAILABLE
    -2, // PLAY_STORE_NOT_FOUND
    -6, // PLAY_SERVICES_NOT_FOUND
    -9, // CANNOT_BIND_TO_SERVICE
    -14, // PLAY_STORE_VERSION_OUTDATED
    -15, // PLAY_SERVICES_VERSION_OUTDATED
  };

  @override
  Future<Map<String, Object?>> proof(WincheIntegrityRequest request) async {
    final challenge = await request.challenge();
    final project = challenge.androidCloudProjectNumber ??
        (throw WincheIntegrityUnsupported("The project has no Google Cloud project number for ${request.appId}: set it under Integrity in the console."));
    try {
      return {'challenge': challenge.value, 'token': await _native.playIntegrityToken(project, requestHash(challenge.value))};
    } on PlatformException catch (e) {
      final code = switch (e.details) {
        {'code': final num c} => c.toInt(),
        _ => null,
      };
      if (e.code == 'playIntegrity' && unsupportedCodes.contains(code)) {
        throw WincheIntegrityUnsupported("Play Integrity can't run on this device (${e.message}).", cause: e);
      }
      rethrow;
    }
  }
}
