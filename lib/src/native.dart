import 'package:flutter/services.dart';

/// The native side: Apple's `DCAppAttestService` and a place to keep the key's
/// id (Swift, iOS and macOS), and Google Play Integrity (Kotlin, Android).
/// Tests replace it.
class WincheIntegrityNative {
  /// The channel the plugin answers on.
  static const channel = MethodChannel('winche_integrity');

  /// The platform, over [channel].
  const WincheIntegrityNative();

  /// Whether this device has App Attest (a real iPhone, iPad or Mac; not a simulator).
  Future<bool> isSupported() async => await channel.invokeMethod<bool>('isSupported') ?? false;

  /// A new key in the Secure Enclave: its id.
  Future<String> generateKey() async => (await channel.invokeMethod<String>('generateKey'))!;

  /// Apple's attestation of [keyId] for SHA-256 of [challenge], base64.
  Future<String> attestKey(String keyId, String challenge) async =>
      (await channel.invokeMethod<String>('attestKey', {'keyId': keyId, 'challenge': challenge}))!;

  /// An assertion with [keyId] for SHA-256 of [challenge], base64.
  Future<String> generateAssertion(String keyId, String challenge) async =>
      (await channel.invokeMethod<String>('generateAssertion', {'keyId': keyId, 'challenge': challenge}))!;

  /// A Play Integrity token (standard API) for [requestHash], from the provider
  /// prepared for [cloudProjectNumber] (prepared now if it isn't yet).
  Future<String> playIntegrityToken(int cloudProjectNumber, String requestHash) async =>
      (await channel.invokeMethod<String>('playIntegrityToken', {'cloudProjectNumber': cloudProjectNumber, 'requestHash': requestHash}))!;

  /// What was kept under [name], if anything.
  Future<String?> load(String name) => channel.invokeMethod<String>('load', {'name': name});

  /// Keeps [value] under [name].
  Future<void> save(String name, String value) => channel.invokeMethod<void>('save', {'name': name, 'value': value});

  /// Forgets [name].
  Future<void> remove(String name) => channel.invokeMethod<void>('remove', {'name': name});
}
