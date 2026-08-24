import 'package:flutter/material.dart';

import '../utils.dart';
import 'settings_screen.dart';
import '../theme.dart';

/// First-run empty state shown when no Amber API token is saved yet.
///
/// Walks the user through generating a token on app.amber.com.au, then
/// hands off to [SettingsScreen] to paste it in.
class Onboarding extends StatelessWidget {
  const Onboarding({super.key});

  static const _stepStyle = TextStyle(color: AmberPalette.muted, height: 1.5);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Amber',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 32,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "1. Open app.amber.com.au and enable 'For Developers'",
              textAlign: TextAlign.center,
              style: _stepStyle,
            ),
            const SizedBox(height: 8),
            const Text(
              '2. Generate a new Token',
              textAlign: TextAlign.center,
              style: _stepStyle,
            ),
            const SizedBox(height: 8),
            const Text(
              '3. Paste it in Settings',
              textAlign: TextAlign.center,
              style: _stepStyle,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Utils.launchURI(Uri(
                scheme: 'https',
                host: 'app.amber.com.au',
                path: '/',
              )),
              child: const Text('app.amber.com.au'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
