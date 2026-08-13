import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_guard/app.dart';
import 'package:grid_guard/ui/screens/game_screen.dart';
import 'package:grid_guard/services/app_providers.dart';
import 'package:grid_guard/services/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots straight into the site without throwing',
      (tester) async {
    // In-memory prefs so SaveService works without a device.
    SharedPreferences.setMockInitialValues({});
    final save = await SaveService.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveServiceProvider.overrideWithValue(save)],
        child: const GridGuardApp(),
      ),
    );
    await tester.pump();

    // The site itself is the entry screen now: the build tray proves the game
    // widget mounted and the HUD came up with it.
    expect(find.byType(GameScreen), findsOneWidget);
  });
}
