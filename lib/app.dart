import 'package:flutter/material.dart';

import 'ui/screens/main_menu_screen.dart';
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
      home: const MainMenuScreen(),
    );
  }
}
