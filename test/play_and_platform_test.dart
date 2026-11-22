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
  WincheIntegrityRequest request({int? project = 123456789012, String? siteKey = '0x4AAAAAAAsitekey123'}) =>
      WincheIntegrityRequest('clinic-app', () async => WincheIntegrityChallenge('ch-1', DateTime(2030), androidCloudProjectNumber: project, webSiteKey: siteKey));

  test('Play Integrity: a token for SHA-256 of the challenge, from the Cloud project the project names', () async {
    final native = FakeNative();
    final play = WinchePlayIntegrity(native: native);
    expect(play.provider, 'playIntegrity');
    expect(await play.proof(request()), {'challenge': 'ch-1', 'token': 'play-token-1'});
    expect(native.playCalls.single, (123456789012, WinchePlayIntegrity.requestHash('ch-1')));
    // As the server makes it: SHA-256 of the challenge's UTF-8, lower-case hex.
    expect(WinchePlayIntegrity.requestHash('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    await expectLater(play.proof(request(project: null)),
        throwsA(isA<WincheIntegrityUnsupported>().having((e) => e.message, 'message', contains('Google Cloud project number'))));
  });

  test('Google failures come to the caller as they are; a device without Play services is unsupported', () async {
    final play = WinchePlayIntegrity(native: _Failing(-3));   // NETWORK_ERROR
    await expectLater(play.proof(request()), throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'playIntegrity')));
    for (final code in [-1, -2, -6, -9, -14, -15]) {
      await expectLater(WinchePlayIntegrity(native: _Failing(code)).proof(request()),
          throwsA(isA<WincheIntegrityUnsupported>().having((e) => e.cause, 'cause', isA<PlatformException>())));
    }
  });

  test('the platform picks: App Attest on iOS and macOS, Play Integrity on Android, else the debug token', () async {
    Future<String> chosen(TargetPlatform p, {bool appAttest = true, String? debug, bool web = false}) async {
      final picker = WinchePlatformIntegrity(native: FakeNative()..appAttest = appAttest, platform: p, web: web, debugToken: debug,
          turnstile: WincheTurnstile(run: ({required siteKey, required action, required cData}) async => 'cf-token'));
      try {
        await picker.proof(request());
      } on WincheIntegrityUnsupported {
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
    expect(await chosen(TargetPlatform.android, web: true, debug: 'wdt_x'), 'turnstile');   // the browser check
    expect(await chosen(TargetPlatform.windows, debug: ''), 'none');   // an empty --dart-define is none
  });

  test('the browser check: the site key from the challenge, our action, the challenge as cData', () async {
    final runs = <String>[];
    final turnstile = WincheTurnstile(run: ({required siteKey, required action, required cData}) async {
      runs.add('$siteKey $action $cData');
      return 'cf-token';
    });
    expect(turnstile.provider, 'turnstile');
    expect(await turnstile.proof(request()), {'challenge': 'ch-1', 'token': 'cf-token'});
    expect(runs, ['0x4AAAAAAAsitekey123 winche-integrity ch-1']);
    await expectLater(turnstile.proof(request(siteKey: null)),
        throwsA(isA<WincheIntegrityUnsupported>().having((e) => e.message, 'message', contains('Turnstile site key'))));
    // Off the web, the real runner says it can't run.
    await expectLater(WincheTurnstile().proof(request()), throwsA(isA<WincheIntegrityUnsupported>()));
  });

  test('without what Play Integrity or the browser check needs (the emulator), the debug token', () async {
    for (final (platform, web) in [(TargetPlatform.android, false), (TargetPlatform.windows, true)]) {
      final picker = WinchePlatformIntegrity(native: FakeNative(), platform: platform, web: web, debugToken: 'wdt_local',
          turnstile: WincheTurnstile(run: ({required siteKey, required action, required cData}) async => 'cf'));
      expect(await picker.proof(request(project: null, siteKey: null)), {'debugToken': 'wdt_local'});
      expect(picker.provider, 'debug');
    }
    final noDebug = WinchePlatformIntegrity(native: FakeNative(), platform: TargetPlatform.android);
    await expectLater(noDebug.proof(request(project: null)), throwsA(isA<WincheIntegrityUnsupported>()));
  });

  test("an emulator without Play services, or a simulator App Attest refuses: the debug token, from then on", () async {
    final android = WinchePlatformIntegrity(native: _Failing(-6), platform: TargetPlatform.android, debugToken: 'wdt_local');
    expect(await android.proof(request()), {'debugToken': 'wdt_local'});
    expect(android.provider, 'debug');
    final apple = WinchePlatformIntegrity(native: _NoAttest(), platform: TargetPlatform.iOS, debugToken: 'wdt_local');
    expect(await apple.proof(request()), {'debugToken': 'wdt_local'});
    expect(apple.provider, 'debug');
  });

  test("a failure that may pass (the network, a timeout) isn't a reason to switch to the debug token", () async {
    final android = WinchePlatformIntegrity(native: _Failing(-3), platform: TargetPlatform.android, debugToken: 'wdt_local');
    await expectLater(android.proof(request()), throwsA(isA<PlatformException>()));
    expect(android.provider, 'playIntegrity');
    final browser = WinchePlatformIntegrity(native: FakeNative(), web: true, debugToken: 'wdt_local',
        turnstile: WincheTurnstile(run: ({required siteKey, required action, required cData}) async =>
            throw StateError('Turnstile timed out waiting for the person.')));
    await expectLater(browser.proof(request()), throwsA(isA<StateError>()));
    expect(browser.provider, 'turnstile');
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
  final int code;
  _Failing(this.code);

  @override
  Future<String> playIntegrityToken(int cloudProjectNumber, String requestHash) async =>
      throw PlatformException(code: 'playIntegrity', message: 'Play Integrity failed', details: {'code': code, 'retryable': code == -3});
}

/// Says it has App Attest, then Apple answers featureUnsupported.
class _NoAttest extends FakeNative {
  @override
  Future<String> attestKey(String keyId, String challenge) async => throw PlatformException(code: 'unsupported');
}
