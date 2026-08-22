import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amber/my_theme_model.dart';
import 'package:amber/screens/settings_screen.dart';
import 'package:amber/state/dashboard_state.dart';

Widget _host(DashboardState s) => MultiProvider(providers: [
      ChangeNotifierProvider<DashboardState>.value(value: s),
      ChangeNotifierProvider(create: (_) => MyThemeModel()),
    ], child: const MaterialApp(home: SettingsScreen()));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('entering a short token and tapping Save shows inline error',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));

    await t.pumpWidget(_host(s));
    await t.pump();

    await t.enterText(find.byType(TextFormField), 'short');
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await t.pump();

    expect(find.text('Token should be 36 characters'), findsOneWidget);
    expect(s.token, isNull);
  });

  testWidgets('entering a valid 36-char token and tapping Save clears error and saves',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));

    await t.pumpWidget(_host(s));
    await t.pump();

    const validToken = 'psk_73928b0b75931018721fcbbbd4deda5b';
    await t.enterText(find.byType(TextFormField), validToken);
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await t.pump();
    await t.pump();

    expect(find.text('Token should be 36 characters'), findsNothing);
    expect(s.token, validToken);
  });
}
