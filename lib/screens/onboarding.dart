import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/dashboard_state.dart';
import '../utils.dart';
import '../theme.dart';

/// Amber's Developers page, where a personal API token is generated.
///
/// Verified live 2026-09-23: app.amber.com.au/developers loads the page
/// directly; an unknown path 404s, so this must stay exact if Amber ever
/// moves it.
final Uri amberDevelopersUri = Uri.https('app.amber.com.au', '/developers');

/// Opens the guide as its own screen (from Settings' "Change token"). It
/// pops itself once a connect succeeds, so the user lands back where they
/// were.
Future<void> openAmberGuide(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ConnectAmberScreen()),
  );
}

/// How to generate an Amber API token and connect it to the app.
///
/// [HomeShell] shows it in place of the tabs whenever there is no usable
/// token: on first launch, and when a previously-saved token has been
/// rejected and nothing is left to show (`DashboardState.tokenRejected`). It
/// is also the body of [ConnectAmberScreen], pushed from Settings.
class Onboarding extends StatefulWidget {
  /// Called after [DashboardState.connect] succeeds.
  final VoidCallback? onConnected;

  const Onboarding({super.key, this.onConnected});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  late final TextEditingController _controller;
  String? _connectError;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || !mounted) return;
    _controller.text = text;
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  Future<void> _connect() async {
    // Guard re-entry: a double-tap must not fire two overlapping connects.
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _connectError = null;
    });
    final state = context.read<DashboardState>();
    try {
      final error = await state.connect(_controller.text);
      if (!mounted) return;
      if (error != null) {
        setState(() => _connectError = error);
        return;
      }
      widget.onConnected?.call();
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    // The saved-token failure banner belongs here, not just in HomeShell:
    // this screen is also reached (via "Change token") while a good token is
    // already connected, and that lastError must not follow it there.
    final String? error =
        state.lastError != null && (state.token == null || state.tokenRejected)
            ? state.lastError
            : null;

    return SafeArea(
      top: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'See your Amber prices and usage',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "This app charts your Amber Electric prices and usage with "
                  "a personal API token from your Amber account. It isn't "
                  "made by Amber, and your token stays on this device.",
                  style: TextStyle(color: AmberPalette.muted, height: 1.4),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorNote(error),
                ],
                const SizedBox(height: 24),
                _Step(
                  number: 1,
                  title: 'Open the Developers page in your Amber account',
                  detail: 'Log in if it asks you to.',
                  action: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Utils.launchURI(amberDevelopersUri),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open Amber Developers'),
                      ),
                      // Spelled out too, for when the tap cannot open a
                      // browser (or the user is on another device).
                      const SelectableText(
                        'app.amber.com.au/developers',
                        style: TextStyle(color: AmberPalette.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const _Step(
                  number: 2,
                  title: 'Tap "Generate a new Token" and copy it',
                  detail: 'Give it any name. Amber shows the token only once, '
                      'so copy it before you leave the page.',
                ),
                _Step(
                  number: 3,
                  title: 'Paste it here',
                  detail: '',
                  action: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _controller,
                        obscureText: false,
                        onChanged: (_) {
                          if (_connectError != null) {
                            setState(() => _connectError = null);
                          }
                        },
                        style: const TextStyle(
                            color: Colors.white, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AmberPalette.surface,
                          hintText: 'psk_…',
                          hintStyle: const TextStyle(color: AmberPalette.muted),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.content_paste,
                                color: AmberPalette.muted),
                            tooltip: 'Paste',
                            onPressed: _paste,
                          ),
                        ),
                      ),
                      if (_connectError != null) ...[
                        const SizedBox(height: 8),
                        Text(_connectError!,
                            style: const TextStyle(color: Colors.redAccent)),
                      ],
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _connecting ? null : _connect,
                        child: Text(_connecting ? 'Connecting…' : 'Connect'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [Onboarding] as a pushed screen, for Settings' "Change token".
class ConnectAmberScreen extends StatelessWidget {
  const ConnectAmberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AmberPalette.navy,
      appBar: AppBar(
        backgroundColor: AmberPalette.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Connect your Amber account'),
      ),
      body: Onboarding(
        onConnected: () {
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String detail;
  final Widget? action;

  const _Step({
    required this.number,
    required this.title,
    required this.detail,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AmberPalette.mint,
            child: Text(
              '$number',
              style: const TextStyle(
                color: AmberPalette.navy,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(detail,
                      style: const TextStyle(color: AmberPalette.muted, height: 1.4)),
                ],
                if (action != null) ...[
                  const SizedBox(height: 10),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  final String message;

  const _ErrorNote(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AmberPalette.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
