import 'package:flutter/foundation.dart';
import 'package:winche_core/winche_core.dart';

import 'app_attest.dart';
import 'native.dart';
import 'play_integrity.dart';
import 'turnstile.dart';

/// The proof this platform has: App Attest on iOS and macOS, Play Integrity on
/// Android, the browser check (Turnstile) on the web; elsewhere (simulators,
/// Windows, Linux), the
/// [debugToken] when one is given, else none (a project that enforces Integrity
/// then refuses the app).
///
/// ```dart
/// app.useIntegrity(WinchePlatformIntegrity(
///   debugToken: kDebugMode ? const String.fromEnvironment('WINCHE_DEBUG_TOKEN') : null,
/// ));
/// ```
final class WinchePlatformIntegrity extends WincheIntegrityProvider {
  /// A debug token for where no proof is available (never in release builds).
  final String? debugToken;
  final WincheIntegrityNative _native;
  final TargetPlatform? _platform;
  final bool _web;
  final WincheTurnstile? _turnstile;
  WincheIntegrityProvider? _chosen;

  /// The proof for this platform; [platform] and [web] stand in for it in tests.
  WinchePlatformIntegrity({String? debugToken, WincheIntegrityNative native = const WincheIntegrityNative(), @visibleForTesting TargetPlatform? platform, @visibleForTesting bool? web,
      @visibleForTesting WincheTurnstile? turnstile})
      : debugToken = (debugToken?.isEmpty ?? true) ? null : debugToken,
        _native = native,
        _turnstile = turnstile,
        _platform = platform,
        _web = web ?? kIsWeb;

  /// The provider in use, once the first proof chose it.
  WincheIntegrityProvider? get chosen => _chosen;

  Future<WincheIntegrityProvider?> _choose() async {
    if (_chosen != null) return _chosen;
    final platform = _platform ?? defaultTargetPlatform;
    WincheIntegrityProvider? p;
    if (_web) {
      p = _turnstile ?? WincheTurnstile();
    } else if ((platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) && await WincheAppAttest.isSupported(native: _native)) {
      p = WincheAppAttest(native: _native);
    } else if (platform == TargetPlatform.android) {
      p = WinchePlayIntegrity(native: _native);
    } else if (debugToken != null) {
      p = WincheDebugIntegrity(debugToken!);
    }
    return _chosen = p;
  }

  @override
  String get provider => _chosen?.provider ?? 'none';

  @override
  Future<Map<String, Object?>> proof(WincheIntegrityRequest request) async {
    final p = await _choose() ?? (throw StateError('No proof of integrity on this platform: give WinchePlatformIntegrity a debug token here.'));
    try {
      return await p.proof(request);
    } on StateError {
      // Play Integrity or the browser check without what they need from the project (its Cloud project number, its
      // site key: the emulator has neither): the debug token, when there is one.
      if (debugToken == null || p is WincheDebugIntegrity) rethrow;
      _chosen = WincheDebugIntegrity(debugToken!);
      return _chosen!.proof(request);
    }
  }

  @override
  bool refused(String? reason) => _chosen?.refused(reason) ?? false;
}
