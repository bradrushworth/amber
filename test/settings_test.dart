import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amber/model/Sites.dart';
import 'package:amber/screens/settings_screen.dart';
import 'package:amber/state/dashboard_state.dart';

const String _token = 'psk_73928b0b75931018721fcbbbd4deda5b';

/// Settings is pushed over a stand-in home so `Navigator.maybePop` (used
/// after Remove) has somewhere to go back to, instead of being a no-op at
/// the root route.
Widget _host(DashboardState s) => ChangeNotifierProvider<DashboardState>.value(
      value: s,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                ),
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _openSettings(WidgetTester t) async {
  await t.tap(find.text('Open Settings'));
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connected shows the selected site and a masked token', (t) async {
    SharedPreferences.setMockInitialValues({'amberToken': _token});
    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));
    s.token = _token;
    s.selectedSite =
        Site(id: 's1', nmi: '4103000001', network: 'Ausgrid', status: 'active');

    await t.pumpWidget(_host(s));
    await _openSettings(t);

    expect(find.text('AMBER ACCOUNT'), findsOneWidget);
    expect(find.text('Ausgrid · 4103000001'), findsOneWidget);
    expect(
        find.text(
            'Token ${_token.substring(0, 4)}…${_token.substring(_token.length - 4)} '
            '· saved on this device'),
        findsOneWidget);
    expect(find.text('Change token'), findsOneWidget);
    expect(find.text('Remove token from this device'), findsOneWidget);
  });

  testWidgets('not connected shows "Not connected" and no remove option', (t) async {
    SharedPreferences.setMockInitialValues({});
    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));

    await t.pumpWidget(_host(s));
    await _openSettings(t);

    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Change token'), findsOneWidget);
    expect(find.text('Remove token from this device'), findsNothing);
  });

  testWidgets('Remove asks first; Cancel keeps the token', (t) async {
    SharedPreferences.setMockInitialValues({'amberToken': _token});
    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));
    s.token = _token;

    await t.pumpWidget(_host(s));
    await _openSettings(t);

    await t.tap(find.text('Remove token from this device'));
    await t.pumpAndSettle();
    expect(find.text('Remove your Amber token?'), findsOneWidget);

    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();

    expect(s.token, _token);
    // Still on Settings — the dialog closed, the screen didn't pop.
    expect(find.text('AMBER ACCOUNT'), findsOneWidget);
  });

  testWidgets('Remove clears the token and pops back', (t) async {
    SharedPreferences.setMockInitialValues({'amberToken': _token});
    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));
    s.token = _token;

    await t.pumpWidget(_host(s));
    await _openSettings(t);

    await t.tap(find.text('Remove token from this device'));
    await t.pumpAndSettle();
    await t.tap(find.text('Remove'));
    await t.pumpAndSettle();

    expect(s.token, isNull);
    // Popped back to the stand-in home.
    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.text('AMBER ACCOUNT'), findsNothing);
  });
}
