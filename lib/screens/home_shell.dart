import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:provider/provider.dart';

import '../model/Sites.dart';
import '../state/dashboard_state.dart';
import 'history_tab.dart';
import 'now_tab.dart';
import 'onboarding.dart';
import 'settings_screen.dart';

/// Root screen: an app bar (app name + tappable site context line + Settings
/// gear) over a three-tab body (Now / Days / Weeks) driven by a
/// [NavigationBar].
///
/// Before a token is saved the body is [Onboarding] instead of the tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const Color _background = Color(0xFF20202A);
  static const Color _surface = Color(0xFF1A1A26);

  int _tab = 0;

  /// The [DashboardState.lastError] the user has already dismissed. The error
  /// banner reappears as soon as the message *changes* (a new failure), but a
  /// dismissed message stays hidden while the same error keeps being re-set by
  /// the polling timers.
  String? _dismissedError;

  @override
  void initState() {
    super.initState();
    // Same guard as the pre-overhaul lib/main.dart:127-146 — the plugin has no
    // web implementation and Platform is only meaningful off the web.
    if (!kIsWeb) {
      if (Platform.isAndroid || Platform.isIOS) {
        KeepScreenOn.turnOn();
      }
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      if (Platform.isAndroid || Platform.isIOS) {
        KeepScreenOn.turnOff();
      }
    }
    super.dispose();
  }

  static bool _isClosed(Site site) => site.status == 'closed';

  /// One-line badge for the app bar: `Ausgrid · 4103000001 (closed)`.
  static String _contextLine(Site site) =>
      '${site.network} · ${site.nmi}${_isClosed(site) ? ' (closed)' : ''}';

  /// Two-line badge for the picker sheet.
  static String _sheetLabel(Site site) =>
      '${site.network}\n${site.nmi}${_isClosed(site) ? ' (closed)' : ''}';

  void _showSitePicker(BuildContext context, DashboardState state) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final site in state.sites)
              ListTile(
                title: Text(
                  _sheetLabel(site),
                  style: const TextStyle(color: Colors.white),
                ),
                selected: identical(site, state.selectedSite),
                selectedTileColor: const Color(0xFF23232F),
                onTap: () {
                  state.selectSite(site);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _title(BuildContext context, DashboardState state) {
    final site = state.selectedSite;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Amber',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        if (site != null)
          InkWell(
            onTap: () => _showSitePicker(context, state),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _contextLine(site),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9595A4),
                      fontSize: 12,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down,
                    size: 16, color: Color(0xFF9595A4)),
              ],
            ),
          ),
      ],
    );
  }

  /// The only surface for [DashboardState.lastError]: without it a bad token
  /// (401 on `/sites`) leaves the shell showing empty skeletons forever, since
  /// the old `HomePageState` snackbars are gone.
  Widget _errorBanner(String message) {
    return MaterialBanner(
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      dividerColor: Colors.transparent,
      leading: const Icon(Icons.error_outline, color: Colors.redAccent),
      content: Text(message, style: const TextStyle(color: Colors.white)),
      actions: [
        TextButton(
          onPressed: () => setState(() => _dismissedError = message),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    // Before a token exists there is only one thing to show, so the tab bar is
    // hidden rather than left inert over the onboarding screen.
    final bool hasToken = state.token != null;
    final String? error = state.lastError;
    final bool showError = error != null && error != _dismissedError;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        title: _title(context, state),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF9595A4)),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (showError) _errorBanner(error),
          Expanded(
            child: hasToken
                ? IndexedStack(
                    index: _tab,
                    children: const [
                      NowTab(),
                      HistoryTab(weeks: false),
                      HistoryTab(weeks: true),
                    ],
                  )
                : const Onboarding(),
          ),
        ],
      ),
      bottomNavigationBar: hasToken
          ? NavigationBar(
              backgroundColor: _surface,
              surfaceTintColor: Colors.transparent,
              indicatorColor: const Color(0xFF2E2E3E),
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.bolt), label: 'Now'),
                NavigationDestination(
                    icon: Icon(Icons.calendar_view_day), label: 'Days'),
                NavigationDestination(
                    icon: Icon(Icons.calendar_view_week), label: 'Weeks'),
              ],
            )
          : null,
    );
  }
}
