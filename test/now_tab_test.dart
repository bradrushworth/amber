import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:amber/screens/now_tab.dart';
import 'package:amber/state/dashboard_state.dart';
import 'package:amber/model/Usage.dart';
import 'package:http/http.dart' as http;

void main() {
  testWidgets('hero shows current price and period', (t) async {
    final s = DashboardState(fetch: (u, h, ttl) async => http.Response('[]', 200));
    s.forecastData = [Usage(type: 'CurrentInterval', perKwh: 18.4,
        channelType: 'general', duration: 30, descriptor: 'low',
        nemTime: DateTime.now().toIso8601String())];
    await t.pumpWidget(ChangeNotifierProvider<DashboardState>.value(
        value: s,
        child: const MaterialApp(home: Scaffold(body: NowTab()))));
    await t.pump();
    expect(find.textContaining('18.4'), findsOneWidget);
    expect(find.textContaining('Off-peak'), findsWidgets);
  });
}
