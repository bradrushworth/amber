import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amber/screens/onboarding.dart';
import 'package:amber/state/dashboard_state.dart';

const String _validToken = 'psk_73928b0b75931018721fcbbbd4deda5b';

const _sites = [
  {"id": "s1", "nmi": "4103000001", "network": "Ausgrid", "status": "active",
    "intervalLength": 30, "channels": [], "activeFrom": "2020-01-01"},
];

http.Response _json(Object body) => http.Response(jsonEncode(body), 200);

Widget _host(DashboardState s, {VoidCallback? onConnected}) =>
    ChangeNotifierProvider<DashboardState>.value(
      value: s,
      child: MaterialApp(
          home: Scaffold(body: Onboarding(onConnected: onConnected))),
    );

/// The guide is taller than the default 800x600 surface, which would leave
/// the Connect button off-screen (and unhittable) at the bottom.
void _tall(WidgetTester t) {
  final originalSize = t.view.physicalSize;
  final originalRatio = t.view.devicePixelRatio;
  t.view.physicalSize = const Size(600, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(() {
    t.view.physicalSize = originalSize;
    t.view.devicePixelRatio = originalRatio;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('amberDevelopersUri points at the live Developers page', () {
    expect(amberDevelopersUri.toString(), 'https://app.amber.com.au/developers');
  });

  testWidgets('renders the three steps and the Developers button', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));

    await t.pumpWidget(_host(s));
    await t.pump();

    expect(find.text('See your Amber prices and usage'), findsOneWidget);
    expect(find.text('Open the Developers page in your Amber account'),
        findsOneWidget);
    expect(find.text('Tap "Generate a new Token" and copy it'), findsOneWidget);
    expect(find.text('Paste it here'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Open Amber Developers'),
        findsOneWidget);
    expect(find.text('app.amber.com.au/developers'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Connect'), findsOneWidget);
  });

  testWidgets(
      'entering a token and tapping Connect with an accepting fetch connects and calls onConnected',
      (t) async {
    _tall(t);
    SharedPreferences.setMockInitialValues({});
    final s = DashboardState(fetch: (u, h, ttl) async => _json(_sites));
    var connected = false;

    await t.pumpWidget(_host(s, onConnected: () => connected = true));
    await t.pump();

    await t.enterText(find.byType(TextField), _validToken);
    await t.tap(find.widgetWithText(FilledButton, 'Connect'));
    await t.pumpAndSettle();

    expect(s.token, _validToken);
    expect(connected, isTrue);
  });

  testWidgets('a 401 shows the rejected message inline and does not connect',
      (t) async {
    _tall(t);
    SharedPreferences.setMockInitialValues({});
    final s = DashboardState(
        fetch: (u, h, ttl) async => http.Response('nope', 401));
    var connected = false;

    await t.pumpWidget(_host(s, onConnected: () => connected = true));
    await t.pump();

    await t.enterText(find.byType(TextField), _validToken);
    await t.tap(find.widgetWithText(FilledButton, 'Connect'));
    await t.pumpAndSettle();

    expect(
        find.text(
            "Amber didn't accept that token. Generate a new one and paste it again."),
        findsOneWidget);
    expect(s.token, isNull);
    expect(connected, isFalse);
  });
}
