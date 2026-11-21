import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winche_integrity/winche_integrity.dart';
import 'package:winche_core/winche_core.dart';

/// A device: keys it makes, what it keeps, and keys that can vanish from the Secure Enclave.
class FakeDevice extends WincheIntegrityNative {
  final Map<String, String> kept = {};
  final Set<String> lost = {};
  final List<String> calls = [];
  int keys = 0;
  bool supported = true;

  @override
  Future<bool> isSupported() async => supported;
  @override
  Future<String> generateKey() async => 'key-${++keys}';
  @override
  Future<String> attestKey(String keyId, String challenge) async {
    calls.add('attest $keyId $challenge');
    if (lost.contains(keyId)) throw PlatformException(code: 'invalidKey');
    return 'attestation-of-$keyId';
  }
  @override
  Future<String> generateAssertion(String keyId, String challenge) async {
    calls.add('assert $keyId $challenge');
    if (lost.contains(keyId)) throw PlatformException(code: 'invalidKey');
    return 'assertion-by-$keyId';
  }
  @override
  Future<String?> load(String name) async => kept[name];
  @override
  Future<void> save(String name, String value) async => kept[name] = value;
  @override
  Future<void> remove(String name) async => kept.remove(name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var challenges = 0;
  WincheIntegrityRequest request([String app = 'clinic-app']) => WincheIntegrityRequest(app, () async => 'ch-${++challenges}');
  setUp(() => challenges = 0);

  test('a new key is attested once, then each challenge gets an assertion with it', () async {
    final device = FakeDevice();
    final attest = WincheAppAttest(platform: device);
    expect(attest.provider, 'appAttest');
    expect(await attest.proof(request()), {'keyId': 'key-1', 'challenge': 'ch-1', 'attestation': 'attestation-of-key-1'});
    expect(await attest.proof(request()), {'keyId': 'key-1', 'challenge': 'ch-2', 'assertion': 'assertion-by-key-1'});
    expect(device.kept, {'clinic-app.key': 'key-1', 'clinic-app.attested': 'yes'});
    // Another app id keeps its own key.
    expect((await attest.proof(request('other-app')))['keyId'], 'key-2');
    // Kept across launches: a new provider on the same device asserts with the same key.
    expect(await WincheAppAttest(platform: device).proof(request()), containsPair('assertion', 'assertion-by-key-1'));
  });

  test("a key the project doesn't know: a new one is attested at once; a refused attestation: a new key next time", () async {
    final device = FakeDevice();
    final attest = WincheAppAttest(platform: device);
    await attest.proof(request());
    await attest.proof(request());
    expect(attest.refused('integrity-unknown-key'), isTrue);   // asked again at once
    expect(await attest.proof(request()), {'keyId': 'key-2', 'challenge': 'ch-3', 'attestation': 'attestation-of-key-2'});

    expect(attest.refused('integrity-rejected'), isFalse);   // after an attestation: waits, then a new key
    expect((await attest.proof(request()))['keyId'], 'key-3');
    // A refused assertion (a replay, say) keeps the key.
    expect(await attest.proof(request()), containsPair('assertion', 'assertion-by-key-3'));
    expect(attest.refused('integrity-rejected'), isFalse);
    expect(await attest.proof(request()), containsPair('assertion', 'assertion-by-key-3'));
    expect(attest.refused('integrity-challenge'), isFalse);
    expect((await attest.proof(request()))['keyId'], 'key-3');
  });

  test('a key gone from the Secure Enclave is replaced once; other failures go to the caller', () async {
    final device = FakeDevice();
    final attest = WincheAppAttest(platform: device);
    await attest.proof(request());
    device.lost.add('key-1');
    expect(await attest.proof(request()), {'keyId': 'key-2', 'challenge': 'ch-2', 'attestation': 'attestation-of-key-2'});
    device.lost.add('key-2');
    device.lost.add('key-3');
    await expectLater(attest.proof(request()), throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'invalidKey')));
  });

  test('isSupported: the device says; where there is no plugin (not iOS or macOS), false', () async {
    expect(await WincheAppAttest.isSupported(platform: FakeDevice()..supported = false), isFalse);
    expect(await WincheAppAttest.isSupported(platform: FakeDevice()), isTrue);
    expect(await WincheAppAttest.isSupported(), isFalse);   // no native side in a test
  });

  test('the channel carries the calls to the native side', () async {
    final seen = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(WincheIntegrityNative.channel, (call) async {
      seen.add(call);
      return switch (call.method) { 'isSupported' => true, 'generateKey' => 'k', 'attestKey' => 'a', 'generateAssertion' => 's', _ => null };
    });
    const p = WincheIntegrityNative();
    expect(await p.isSupported(), isTrue);
    expect(await p.generateKey(), 'k');
    expect(await p.attestKey('k', 'ch'), 'a');
    expect(await p.generateAssertion('k', 'ch'), 's');
    await p.save('n', 'v');
    expect(seen.map((c) => '${c.method} ${c.arguments}'), ['isSupported null', 'generateKey null', 'attestKey {keyId: k, challenge: ch}',
      'generateAssertion {keyId: k, challenge: ch}', 'save {name: n, value: v}']);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(WincheIntegrityNative.channel, null);
  });
}
