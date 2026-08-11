import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/app_providers.dart';
import 'services/save_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-locked mobile game.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await Flame.device.fullScreen();

  // Persistence must be ready before the profile provider reads it.
  final saveService = await SaveService.create();

  final container = ProviderContainer(
    overrides: [saveServiceProvider.overrideWithValue(saveService)],
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
