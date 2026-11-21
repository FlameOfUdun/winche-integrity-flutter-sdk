import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winche_core/winche_core.dart';
import 'package:winche_integrity/winche_integrity.dart';

/// The native side as a test sets it: App Attest there or not, Play Integrity answering.
class FakeNative extends WincheIntegrityNative {
  bool appAttest = true;
  final List<(int, String)> playCalls = [];
  final Map<String, String> kept = {};
  int keys = 0;

  @override
  Future<bool> isSupported() async => appAttest;
  @override
  Future<String> playIntegrityToken(int cloudProjectNumber, String requestHash) async {
    playCalls.add((cloudProjectNumber, requestHash));
    return 'play-token-${playCalls.length}';
  }
  @override
  Future<String> generateKey() async => 'key-${++keys}';
  @override
  Future<String> attestKey(String keyId, String challenge) async => 'attestation';
  @override
  Future<String> generateAssertion(String keyId, String challenge) async => 'assertion';
  @override
  Future<String?> load(String name) async => kept[name];
  @override
  Future<void> save(String name, String value) async => kept[name] = value;
  @override
  Future<void> remove(String name) async => kept.remove(name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WincheIntegrityRequest request({int? project = 123456789012}) =>
      WincheIntegrityRequest('clinic-app', () async => WincheIntegrityChallenge('ch-1', DateTime(2030), androidCloudProjectNumber: project));

  test('Play Integrity: a token for SHA-256 of the challenge, from the Cloud project the project names', () async {
    final native = FakeNative();
    final play = WinchePlayIntegrity(native: native);
    expect(play.provider, 'playIntegrity');
    expect(await play.proof(request()), {'challenge': 'ch-1', 'token': 'play-token-1'});
    expect(native.playCalls.single, (123456789012, WinchePlayIntegrity.requestHash('ch-1')));
    // As the server makes it: SHA-256 of the challenge's UTF-8, lower-case hex.
    expect(WinchePlayIntegrity.requestHash('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    await expectLater(play.proof(request(project: null)), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Google Cloud project number'))));
  });

  test('Google failures come to the caller as they are', () async {
    final play = WinchePlayIntegrity(native: _Failing());
    await expectLater(play.proof(request()), throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'playIntegrity')));
  });

  test('the platform picks: App Attest on iOS and macOS, Play Integrity on Android, else the debug token', () async {
    Future<String> chosen(TargetPlatform p, {bool appAttest = true, String? debug, bool web = false}) async {
      final picker = WinchePlatformIntegrity(native: FakeNative()..appAttest = appAttest, platform: p, web: web, debugToken: debug);
      try {
        await picker.proof(request());
      } on StateError {
        return 'none';
      }
      return picker.provider;
    }

    expect(await chosen(TargetPlatform.iOS), 'appAttest');
    expect(await chosen(TargetPlatform.macOS), 'appAttest');
    expect(await chosen(TargetPlatform.android), 'playIntegrity');
    expect(await chosen(TargetPlatform.iOS, appAttest: false, debug: 'wdt_x'), 'debug');   // a simulator
    expect(await chosen(TargetPlatform.windows, debug: 'wdt_x'), 'debug');
    expect(await chosen(TargetPlatform.linux), 'none');
    expect(await chosen(TargetPlatform.android, web: true, debug: 'wdt_x'), 'debug');   // the web, for now
    expect(await chosen(TargetPlatform.windows, debug: ''), 'none');   // an empty --dart-define is none
  });

  test("the platform's choice hears refusals", () async {
    final native = FakeNative();
    final picker = WinchePlatformIntegrity(native: native, platform: TargetPlatform.iOS);
    expect(picker.refused('integrity-unknown-key'), isFalse);   // nothing chosen yet
    await picker.proof(request());
    expect(picker.chosen, isA<WincheAppAttest>());
    expect(picker.refused('integrity-unknown-key'), isTrue);
    expect(debugDefaultTargetPlatformOverride, isNull);
  });
}

class _Failing extends FakeNative {
  @override
  Future<String> playIntegrityToken(int cloudProjectNumber, String requestHash) async =>
      throw PlatformException(code: 'playIntegrity', message: 'No Play Store', details: {'code': -2, 'retryable': false});
}
