import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:amber/screens/home_shell.dart';
import 'package:amber/screenshots_mobile.dart'
    if (dart.library.io) 'package:amber/screenshots_mobile.dart'
    if (dart.library.js) 'package:amber/screenshots_other.dart';
import 'package:amber/state/dashboard_state.dart';

/// The app's only theme — the light theme and the runtime toggle
/// (`MyThemeModel`) were removed in the UI overhaul; every screen is painted
/// against `0xFF20202A` / `0xFF1A1A26`.
///
/// Carried over verbatim from the pre-overhaul `darkTheme` block. Public (not
/// `_darkTheme`) only so `test/home_shell_test.dart` can pump the shell under
/// the real theme.
final ThemeData darkTheme = ThemeData.dark().copyWith(
  primaryColor: Colors.white,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Color(0xFFA7A7A7), fontSize: 13),
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
