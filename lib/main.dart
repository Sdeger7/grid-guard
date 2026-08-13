import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/app_providers.dart';
import 'services/save_service.dart';
import 'services/weather_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait lock + fullscreen are mobile-only. On web these APIs either no-op
  // or throw (fullscreen needs a user gesture), which would blank the app at
  // startup — so guard them behind kIsWeb.
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    await Flame.device.fullScreen();
  }

  // Persistence must be ready before the profile provider reads it.
  final saveService = await SaveService.create();

  final container = ProviderContainer(
    overrides: [
      saveServiceProvider.overrideWithValue(saveService),
      weatherServiceProvider
          .overrideWithValue(WeatherService(saveService.prefs)),
    ],
  );

  // Warm the audio cache (no-op if placeholder SFX are absent).
  await container.read(audioServiceProvider).preload();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const GridGuardApp(),
    ),
  );
}
