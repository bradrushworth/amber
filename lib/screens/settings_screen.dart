import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/dashboard_state.dart';
import '../utils.dart';

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
    final ok = await context.read<DashboardState>().saveToken(_controller.text.trim());
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = 'Token should be 36 characters');
      return;
    }
    setState(() => _error = null);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Token saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF20202A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A26),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'AMBER API TOKEN',
            style: TextStyle(
              color: Color(0xFF9595A4),
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
              fillColor: const Color(0xFF1A1A26),
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
            onPressed: _save,
            child: const Text('Save'),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              text: 'Enable ',
              style: const TextStyle(color: Color(0xFF9595A4), height: 1.5),
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
              color: Color(0xFF9595A4),
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
    );
  }
}
