import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_guard/app.dart';
import 'package:grid_guard/services/app_providers.dart';
import 'package:grid_guard/services/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots to the main menu without throwing', (tester) async {
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

    // The main menu is the entry screen; its actions prove the app booted.
    expect(find.text('BASE · SURVIVAL'), findsOneWidget);
    expect(find.text('MARKET'), findsOneWidget);
  });
}
