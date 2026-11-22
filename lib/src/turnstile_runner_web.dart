import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

const _script = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
Future<void>? _loading;

@JS('turnstile')
external _Turnstile? get _turnstile;

extension type _Turnstile._(JSObject _) implements JSObject {
  external JSString render(web.HTMLElement container, JSObject options);
  external void execute(JSString widget);
  external void remove(JSString widget);
}

/// Cloudflare's script, loaded once (from Cloudflare itself: it mustn't be proxied or cached).
Future<void> _load() => _loading ??= () async {
      if (_turnstile != null) return;
      final done = Completer<void>();
      final script = web.HTMLScriptElement()
        ..src = _script
        ..async = true;
      script.onload = ((web.Event _) => done.complete()).toJS;
      script.onerror = ((web.Event _) => done.completeError(StateError("Turnstile's script didn't load (blocked, or no network)."))).toJS;
      web.document.head!.append(script);
      await done.future;
    }()
        .catchError((Object e) {
      _loading = null;   // try again next time
      throw e;
    });

/// A Turnstile token for [siteKey], [action] and [cData]: an invisible widget, shown only when Cloudflare wants the
/// person to interact, removed when done.
Future<String> runTurnstile({required String siteKey, required String action, required String cData}) async {
  await _load();
  final turnstile = _turnstile ?? (throw StateError("Turnstile's script loaded but didn't start."));
  final container = web.HTMLDivElement()
    ..style.position = 'fixed'
    ..style.right = '16px'
    ..style.bottom = '16px'
    ..style.zIndex = '2147483647';
  web.document.body!.append(container);
  final token = Completer<String>();
  final options = JSObject()
    ..['sitekey'] = siteKey.toJS
    ..['action'] = action.toJS
    ..['cData'] = cData.toJS
    ..['execution'] = 'execute'.toJS
    ..['appearance'] = 'interaction-only'.toJS
    ..['retry'] = 'never'.toJS
    ..['refresh-expired'] = 'never'.toJS
    ..['callback'] = ((JSString t) { if (!token.isCompleted) token.complete(t.toDart); }).toJS
    // True: handled here, so Turnstile doesn't also throw it to the page's console.
    ..['error-callback'] = ((JSAny? code) {
      if (!token.isCompleted) token.completeError(StateError('Turnstile failed: ${code.dartify()}'));
      return true.toJS;
    }).toJS
    ..['timeout-callback'] = (() { if (!token.isCompleted) token.completeError(StateError('Turnstile timed out waiting for the person.')); }).toJS;
  JSString? widget;
  try {
    widget = turnstile.render(container, options);
    turnstile.execute(widget);
    return await token.future.timeout(const Duration(minutes: 2));
  } finally {
    if (widget != null) turnstile.remove(widget);
    container.remove();
  }
}
