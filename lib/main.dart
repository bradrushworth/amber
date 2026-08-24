import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:amber/screens/home_shell.dart';
import 'package:amber/screenshots_mobile.dart'
    if (dart.library.io) 'package:amber/screenshots_mobile.dart'
    if (dart.library.js) 'package:amber/screenshots_other.dart';
import 'package:amber/state/dashboard_state.dart';
import 'package:amber/theme.dart';

/// The app's only theme — the light theme and the runtime toggle
/// (`MyThemeModel`) were removed in the UI overhaul; every screen is painted
/// against [AmberPalette] — Amber Electric's own navy and mint, so the app
/// looks like it belongs to the account it reads.
///
/// Material's dark defaults are what leaked the stock lilac into chips,
/// buttons and the navigation bar, so the accent roles are pinned to the mint
/// here rather than tinted from a seed. Public (not `_darkTheme`) only so
/// `test/home_shell_test.dart` can pump the shell under the real theme.
final ThemeData darkTheme = ThemeData.dark().copyWith(
  scaffoldBackgroundColor: AmberPalette.navy,
  primaryColor: AmberPalette.mint,
  colorScheme: const ColorScheme.dark(
    primary: AmberPalette.mint,
    onPrimary: AmberPalette.navy,
    secondary: AmberPalette.mint,
    onSecondary: AmberPalette.navy,
    surface: AmberPalette.navy,
    onSurface: Colors.white,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: AmberPalette.mutedBright, fontSize: 13),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AmberPalette.surface,
    indicatorColor: AmberPalette.mint,
    iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
        color: states.contains(WidgetState.selected)
            ? AmberPalette.navy
            : AmberPalette.muted)),
    labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        fontSize: 12,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.bold
            : FontWeight.normal,
        color: states.contains(WidgetState.selected)
            ? Colors.white
            : AmberPalette.muted)),
  ),
  chipTheme: const ChipThemeData(
    backgroundColor: AmberPalette.surface,
    selectedColor: AmberPalette.mint,
    labelStyle: TextStyle(color: Colors.white),
    secondaryLabelStyle: TextStyle(color: AmberPalette.navy),
    checkmarkColor: AmberPalette.navy,
    side: BorderSide.none,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AmberPalette.mint,
      foregroundColor: AmberPalette.navy,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: AmberPalette.mint),
  ),
);

void main() {
  runApp(
    DevicePreview(
      enabled: !kReleaseMode && kIsWeb,
      builder: (context) => ChangeNotifierProvider(
        create: (_) => DashboardState()..init(),
        child: const MyApp(),
      ), // Wrap your app
      tools: !kReleaseMode && kIsWeb
          ? [...DevicePreview.defaultTools, simpleScreenShotModesPlugin]
          : [],
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amber Electric Dashboard',
      color: Colors.white,

      // Hide the dev banner
      debugShowCheckedModeBanner: false,
      // For DevicePreview
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,

      theme: darkTheme,
      home: const HomeShell(),
    );
  }
}
