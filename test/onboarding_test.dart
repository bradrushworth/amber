import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amber/screens/onboarding.dart';
import 'package:amber/state/dashboard_state.dart';

Widget _host(DashboardState s) => ChangeNotifierProvider<DashboardState>.value(
      value: s,
      child: const MaterialApp(home: Scaffold(body: Onboarding())),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders app name, the three steps, link and Open Settings button',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));

    await t.pumpWidget(_host(s));
    await t.pump();

    expect(find.text('Amber'), findsOneWidget);
    expect(
        find.text("1. Open app.amber.com.au and enable 'For Developers'"),
        findsOneWidget);
    expect(find.text('2. Generate a new Token'), findsOneWidget);
    expect(find.text('3. Paste it in Settings'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Open Settings'), findsOneWidget);
  });

  testWidgets('tapping Open Settings pushes a route with the token field',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));

    await t.pumpWidget(_host(s));
    await t.pump();

    await t.tap(find.widgetWithText(FilledButton, 'Open Settings'));
    await t.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
  });
}
