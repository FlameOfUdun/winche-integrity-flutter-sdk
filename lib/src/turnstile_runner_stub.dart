import 'unsupported.dart';

/// Not on the web: there's no browser to run Turnstile in.
Future<String> runTurnstile({required String siteKey, required String action, required String cData}) =>
    throw const WincheIntegrityUnsupported('The browser check (Turnstile) runs on the web only.');
