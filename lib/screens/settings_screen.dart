import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/dashboard_state.dart';
import '../utils.dart';
import '../theme.dart';
import 'onboarding.dart' show openAmberGuide;

const _kSectionLabelStyle = TextStyle(
  color: AmberPalette.muted,
  fontWeight: FontWeight.bold,
  fontSize: 12,
  letterSpacing: 1.2,
);

/// Settings: the connected Amber account (site, change/remove token) + About
/// links.
///
/// The About section's four links are copied verbatim (scheme/host/path/
/// query and the kIsWeb && kReleaseMode switch) from lib/main.dart:821-897.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Deleting the saved token sends the user back to the onboarding guide,
  /// so it asks first; Settings then closes to show that guide (mirrors the
  /// Momentum twin's `_confirmRemove` for "Remove my data").
  Future<void> _confirmRemove(BuildContext context) async {
    final bool? remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove your Amber token?'),
        content: const Text(
            'The app will forget your token and show the setup guide again. '
            'Your Amber account is not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove != true || !context.mounted) return;
    await context.read<DashboardState>().removeToken();
    if (context.mounted) Navigator.of(context).maybePop();
  }

  List<Widget> _accountSection(BuildContext context, DashboardState state) {
    final site = state.selectedSite;
    // Same one-line badge as the app bar's site picker (home_shell.dart
    // `_contextLine`) — kept in step by hand since that helper is private.
    final bool closed = site?.status == 'closed';
    final String title = site != null
        ? '${site.network} · ${site.nmi}${closed ? ' (closed)' : ''}'
        : 'Not connected';
    final String? token = state.token;
    final String? subtitle = token == null
        ? null
        : 'Token ${token.substring(0, 4)}…${token.substring(token.length - 4)} '
            '· saved on this device';

    return [
      const Text('AMBER ACCOUNT', style: _kSectionLabelStyle),
      ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(color: AmberPalette.muted))
            : null,
      ),
      ListTile(
        leading: const Icon(Icons.key, color: AmberPalette.muted),
        title: const Text('Change token', style: TextStyle(color: Colors.white)),
        onTap: () => openAmberGuide(context),
      ),
      if (token != null)
        ListTile(
          leading: const Icon(Icons.delete_outline, color: AmberPalette.muted),
          title: const Text('Remove token from this device',
              style: TextStyle(color: Colors.white)),
          onTap: () => _confirmRemove(context),
        ),
      const SizedBox(height: 24),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    return Scaffold(
      backgroundColor: AmberPalette.navy,
      appBar: AppBar(
        backgroundColor: AmberPalette.surface,
        title: const Text('Settings'),
      ),
      // SafeArea keeps the last About tile above the Android gesture bar —
      // the same regression master's 40e6724 fixed in the old footer.
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ..._accountSection(context, state),
            const Text('ABOUT', style: _kSectionLabelStyle),
            ListTile(
              title: const Text('Support', style: TextStyle(color: Colors.white)),
              onTap: () {
                Utils.launchURI(Uri(
                  scheme: 'mailto',
                  path: 'bitbot@bitbot.com.au',
                  query: 'subject=Help with Amber Electric Dashboard',
                ));
              },
            ),
            ListTile(
              title: const Text('Improvements', style: TextStyle(color: Colors.white)),
              onTap: () {
                Utils.launchURI(Uri(
                  scheme: 'https',
                  host: 'github.com',
                  path: '/bradrushworth/amber/issues',
                ));
              },
            ),
            ListTile(
              title: const Text('Source Code', style: TextStyle(color: Colors.white)),
              onTap: () {
                Utils.launchURI(Uri(
                  scheme: 'https',
                  host: 'github.com',
                  path: '/bradrushworth/amber',
                ));
              },
            ),
            ListTile(
              title: Text(kIsWeb && kReleaseMode ? 'Buy Coffee' : 'Visit BitBot',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                if (kIsWeb && kReleaseMode) {
                  Utils.launchURI(Uri(
                    scheme: 'https',
                    host: 'www.buymeacoffee.com',
                    path: '/bitbot',
                  ));
                } else {
                  Utils.launchURI(Uri(
                    scheme: 'https',
                    host: 'www.bitbot.com.au',
                    path: '/',
                  ));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
