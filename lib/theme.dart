import 'package:flutter/material.dart';

/// Amber Electric's own palette, sampled from amber.com.au's brand custom
/// properties (`--base-color-brand--amber-dark-blue`, `--background-color--
/// background-green`, ...) and their customer app's UI.
///
/// This app is NOT affiliated with Amber Electric. It reads their public API
/// on behalf of their own customers, so it deliberately speaks their visual
/// language — deep navy carrying a mint accent — which is what those customers
/// already associate with their electricity account. What it must never do is
/// pass for the official app: the circular "a" glyph, the wordmark and their
/// screenshots are theirs, and the mark, layout and naming here stay ours.
class AmberPalette {
  AmberPalette._();

  /// Page background. `--base-color-brand--amber-dark-blue`.
  static const navy = Color(0xFF0A1A43);

  /// Cards and app bars: navy lifted just enough to separate from the page.
  static const surface = Color(0xFF12295C);

  /// Chart placeholder while data loads.
  static const skeleton = Color(0xFF17346E);

  /// The accent. `--background-color--background-green`; always paired with
  /// [navy] for text/icons sitting on top of it.
  static const mint = Color(0xFF00FFA8);

  /// `--base-color-brand--amber-dark-green`, for pressed/disabled mint.
  static const mintDeep = Color(0xFF00A97D);

  /// Secondary text on [navy] (labels, captions, axis furniture).
  static const muted = Color(0xFF93A8D4);

  /// Slightly brighter secondary text, for small type that must stay legible.
  static const mutedBright = Color(0xFFB2C4E8);
}
