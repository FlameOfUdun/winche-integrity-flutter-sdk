import 'package:flutter/foundation.dart';
import 'package:winche_core/winche_core.dart';

import 'app_attest.dart';
import 'native.dart';
import 'play_integrity.dart';

/// The proof this platform has: App Attest on iOS and macOS, Play Integrity on
/// Android; elsewhere (simulators, Windows, Linux, the web for now), the
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
  WincheIntegrityProvider? _chosen;

  /// The proof for this platform; [platform] and [web] stand in for it in tests.
  WinchePlatformIntegrity({String? debugToken, WincheIntegrityNative native = const WincheIntegrityNative(), @visibleForTesting TargetPlatform? platform, @visibleForTesting bool? web})
      : debugToken = (debugToken?.isEmpty ?? true) ? null : debugToken,
        _native = native,
        _platform = platform,
        _web = web ?? kIsWeb;

  /// The provider in use, once the first proof chose it.
  WincheIntegrityProvider? get chosen => _chosen;

  Future<WincheIntegrityProvider?> _choose() async {
    if (_chosen != null) return _chosen;
    final platform = _platform ?? defaultTargetPlatform;
    WincheIntegrityProvider? p;
    if (!_web && (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) && await WincheAppAttest.isSupported(native: _native)) {
      p = WincheAppAttest(native: _native);
    } else if (!_web && platform == TargetPlatform.android) {
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
    return p.proof(request);
  }

  @override
  bool refused(String? reason) => _chosen?.refused(reason) ?? false;
}
