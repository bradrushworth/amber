import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amber/main.dart' show darkTheme;
import 'package:amber/model/Sites.dart';
import 'package:amber/screens/home_shell.dart';
import 'package:amber/state/dashboard_state.dart';

const String _token = 'psk_73928b0b75931018721fcbbbd4deda5b';

Site _site(String id, String nmi, {String network = 'Ausgrid', String status = 'active'}) =>
    Site(id: id, nmi: nmi, network: network, status: status, intervalLength: 30);

/// A [DashboardState] with a stubbed fetch (so nothing hits the network) and
/// its token read back from the SharedPreferences mock, exactly as `init()`
/// would. `init()` itself is deliberately not called: it starts the 1-minute /
/// 1-hour polling timers, which a widget test has no way to settle.
Future<DashboardState> _state({required bool withToken}) async {
  SharedPreferences.setMockInitialValues(withToken ? {'amberToken': _token} : {});
  final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));
  final prefs = await SharedPreferences.getInstance();
  s.token = prefs.getString('amberToken');
  if (withToken) {
    s.sites = [
      _site('site-1', '4103000001'),
      _site('site-2', '4103000002', network: 'Endeavour', status: 'closed'),
    ];
    s.selectedSite = s.sites.first;
  }
  return s;
}

Widget _host(DashboardState s, {ThemeData? theme}) =>
    ChangeNotifierProvider<DashboardState>.value(
      value: s,
      child: MaterialApp(theme: theme, home: const HomeShell()),
    );

/// The default 800x600 test surface is landscape-shaped; the history tab only
/// renders its metric chips in portrait, so force a portrait surface.
void _portrait(WidgetTester t) {
  final originalSize = t.view.physicalSize;
  final originalRatio = t.view.devicePixelRatio;
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(() {
    t.view.physicalSize = originalSize;
    t.view.devicePixelRatio = originalRatio;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows a NavigationBar with Now / Days / Weeks destinations',
      (t) async {
    _portrait(t);
    await t.pumpWidget(_host(await _state(withToken: true)));
    await t.pump();

    final bar = t.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 3);
    expect(find.text('Now'), findsOneWidget);
    expect(find.text('Days'), findsOneWidget);
    expect(find.text('Weeks'), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsOneWidget);
    expect(find.byIcon(Icons.calendar_view_day), findsOneWidget);
    expect(find.byIcon(Icons.calendar_view_week), findsOneWidget);
    // Gear opens Settings.
    expect(find.byIcon(Icons.settings), findsOneWidget);
    await t.tap(find.byIcon(Icons.settings));
    await t.pumpAndSettle();
    expect(find.text('AMBER API TOKEN'), findsOneWidget);
  });

  testWidgets('tapping Days swaps the visible tab to the history feed',
      (t) async {
    _portrait(t);
    await t.pumpWidget(_host(await _state(withToken: true)));
    await t.pump();

    // The IndexedStack builds every tab, so the Cost chip exists in the tree
    // from the start — but only the selected tab is hit-testable.
    expect(find.text('Cost').hitTestable(), findsNothing);

    await t.tap(find.text('Days'));
    await t.pumpAndSettle();

    expect(find.text('Cost').hitTestable(), findsOneWidget);
    expect(t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
  });

  testWidgets('with no token the body is the onboarding screen', (t) async {
    _portrait(t);
    await t.pumpWidget(_host(await _state(withToken: false)));
    await t.pump();

    expect(find.text('2. Generate a new Token'), findsOneWidget);
    expect(find.text('3. Paste it in Settings'), findsOneWidget);
    // No tabs to switch between yet, so no (inert) NavigationBar.
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('app-bar site line opens a picker that selects another site',
      (t) async {
    _portrait(t);
    final s = await _state(withToken: true);
    await t.pumpWidget(_host(s));
    await t.pump();

    // Context line for the active site, no '(closed)' badge.
    expect(find.text('Ausgrid · 4103000001'), findsOneWidget);

    await t.tap(find.text('Ausgrid · 4103000001'));
    await t.pumpAndSettle();

    // The closed site is listed and badged.
    final closed = find.text('Endeavour\n4103000002 (closed)');
    expect(closed, findsOneWidget);

    await t.tap(closed);
    await t.pumpAndSettle();

    expect(s.selectedSite, same(s.sites[1]));
    expect(find.text('Endeavour · 4103000002 (closed)'), findsOneWidget);
  });

  testWidgets('renders under the app dark theme', (t) async {
    _portrait(t);
    await t.pumpWidget(_host(await _state(withToken: true), theme: darkTheme));
    await t.pump();

    expect(find.text('Amber'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
