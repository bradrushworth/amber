import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/dashboard_state.dart';
import '../utils.dart';
import '../theme.dart';

/// Settings: Amber API token entry + About links.
///
/// The token instructions/links reuse the wording and URIs from
/// lib/main.dart:422-476 ('For Developers' / 'Generate a new Token'), except
/// 'Generate a new Token' opens https://app.amber.com.au/ here instead of the
/// old in-app token dialog (there is no such dialog in this screen — the
/// token field below fills that role).
///
/// The About section's four links are copied verbatim (scheme/host/path/
/// query and the kIsWeb && kReleaseMode switch) from lib/main.dart:821-897.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<DashboardState>();
    _controller = TextEditingController(text: state.token ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Guard re-entry: a double-tap fired two overlapping saveToken calls,
    // which defeated ApiCache's request de-duplication.
    if (_saving) return;
    setState(() => _saving = true);
    final state = context.read<DashboardState>();
    try {
      final ok = await state.saveToken(_controller.text.trim());
      if (!mounted) return;
      if (!ok) {
        setState(() => _error = 'Token should be 36 characters');
        return;
      }
      setState(() => _error = null);
      // Be honest about the outcome: length passing is not the API accepting
      // the token. loadSites has already run inside saveToken by now.
      final accepted = state.sites.isNotEmpty && state.lastError == null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accepted
              ? 'Token saved'
              : 'Saved, but Amber rejected it — check the token and try again')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'AMBER API TOKEN',
            style: TextStyle(
              color: AmberPalette.muted,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _controller,
            obscureText: false,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
            decoration: InputDecoration(
              filled: true,
              fillColor: AmberPalette.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              text: 'Enable ',
              style: const TextStyle(color: AmberPalette.muted, height: 1.5),
              children: [
                TextSpan(
                  text: '\'For Developers\'',
                  style: const TextStyle(color: Colors.blueAccent, height: 1.5),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Utils.launchURI(Uri(
                        scheme: 'https',
                        host: 'app.amber.com.au',
                        path: '/',
                      ));
                    },
                ),
                const TextSpan(text: ', then '),
                TextSpan(
                  text: '\'Generate a new Token\'',
                  style: const TextStyle(color: Colors.blueAccent, height: 1.5),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Utils.launchURI(Uri(
                        scheme: 'https',
                        host: 'app.amber.com.au',
                        path: '/',
                      ));
                    },
                ),
                const TextSpan(text: ' there.'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'ABOUT',
            style: TextStyle(
              color: AmberPalette.muted,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
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
