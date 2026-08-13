import 'package:flutter/material.dart';

import 'data/levels.dart';
import 'ui/screens/game_screen.dart';
import 'ui/theme.dart';

/// Root application widget.
class GridGuardApp extends StatelessWidget {
  const GridGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grid Guard',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // The site is the app. There is only one, it is always running, and
      // everything else - wardrobe, perks, the manual, services - opens from
      // inside it rather than behind a menu the player has to back out to.
      home: GameScreen(config: LevelCatalog.survival),
    );
  }
}
