import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/main.dart' as app;
import 'package:gymmane/state/fit_state.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

const _routes = [
  'progress', 'exercises', 'settings', 'preferences', 'tools', 'routines', 'measures', 'places',
  'passes', 'timeline', 'compare', 'notes', 'nutrition', 'moments', 'awards', 'about', 'ai-plan', 'health',
];

Future<void> wait(WidgetTester tester, int seconds) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(seconds: seconds)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app starts, screens open and native channels answer', (tester) async {
    final errors = <String>[];
    final original = FlutterError.onError;
    FlutterError.onError = (d) => errors.add('${d.exceptionAsString()}\n${d.context ?? ''}');

    await app.main();
    await wait(tester, 6);
    debugPrint('SMOKE onboarding shown, route=${fit.route}');

    fit.completeOnboarding();
    await wait(tester, 6);

    for (final route in _routes) {
      final before = errors.length;
      fit.pushRoute(route);
      await wait(tester, 5);
      debugPrint('SMOKE route $route errors=${errors.length - before}');
      final swiped = fit.handleBack();
      await wait(tester, 1);
      debugPrint('SMOKE back from $route handled=$swiped now=${fit.route}');
      fit.goHome();
      await wait(tester, 1);
    }

    Future<Object?> call(String channel, String method, [Object? args]) async {
      final r = await tester.runAsync(() => MethodChannel(channel).invokeMethod<Object?>(method, args));
      debugPrint('SMOKE native $channel/$method -> $r');
      return r;
    }

    await call('gymmane/screen', 'keepOn', {'on': true});
    await call('gymmane/screen', 'keepOn', {'on': false});
    await call('gymmane/screen', 'bright', {'on': true});
    await call('gymmane/screen', 'bright', {'on': false});
    await call('gymmane/screen', 'dim', {'on': true});
    await call('gymmane/screen', 'dim', {'on': false});
    await call('gymmane/haptics', 'buzz');
    expect(await call('gymmane/voice', 'check', {'lang': 'en-US'}), 'ok');
    await call('gymmane/voice', 'say', {'text': 'Rest over', 'lang': 'en-US'});
    await call('gymmane/voice', 'stop');
    expect(await call('gymmane/gallery', 'savePng', {'bytes': base64Decode(_png), 'name': 'smoke.png'}), true);

    final library = await tester.runAsync(getLibraryDirectory);
    final sound = File('${library!.path}/Sounds/rest_over.wav');
    debugPrint('SMOKE notification sound installed=${sound.existsSync()}');
    expect(sound.existsSync(), true);

    FlutterError.onError = original;
    debugPrint('SMOKE errors=${errors.length}');
    for (final e in errors.toSet()) {
      debugPrint('SMOKE ERROR: $e');
    }
    expect(errors, isEmpty);
  });
}
