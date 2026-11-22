import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:winche_integrity/winche_integrity.dart';
import 'package:winche_core/winche_core.dart';

/// Proves this app to a Winche project (App Attest on iOS and macOS, Play Integrity on Android, a debug token
/// elsewhere) and shows the Integrity token it gets. Run on a real device, with:
///   --dart-define=WINCHE_URL=https://api.example.com/projects/clinic --dart-define=WINCHE_APP=clinic-app
void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  String _status = 'Not tried yet';

  Future<void> _prove() async {
    setState(() => _status = 'Proving…');
    final app = WincheApp('example', options: WincheOptions(
      baseUrl: Uri.parse(const String.fromEnvironment('WINCHE_URL', defaultValue: 'http://localhost:9090')),
      appId: const String.fromEnvironment('WINCHE_APP', defaultValue: 'example-app'),
    ));
    try {
      // A debug token only in debug builds (simulators, emulators): never in a release.
      final integrity = WinchePlatformIntegrity(debugToken: kDebugMode ? const String.fromEnvironment('WINCHE_DEBUG_TOKEN') : null);
      app.useIntegrity(integrity);
      final errors = <Object>[];
      app.integrity.errors.listen(errors.add);
      final token = await app.integrity.token();
      setState(() => _status = token != null
          ? 'Proved with ${integrity.provider}: an Integrity token until ${app.integrity.current!.expiresAt.toLocal()}'
          : 'Refused: ${errors.isEmpty ? 'no token' : errors.last}');
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    } finally {
      await app.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Winche Integrity')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_status),
              const SizedBox(height: 16),
              FilledButton(onPressed: _prove, child: const Text('Prove this app')),
            ]),
          ),
        ),
      );
}
