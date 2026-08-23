import 'package:flutter/material.dart';

import '../bar_chart.dart' show colors;

/// A single row of swatch+label legend entries, wrapping onto multiple lines
/// if there isn't enough horizontal space.
///
/// The color-to-label mapping mirrors the `colors` list in `bar_chart.dart`
/// (see `CustomRodElement.getCostColor`): colors[0]=Supply,
/// colors[1]=Controlled, colors[2]=Off-peak, colors[3]=Shoulder,
/// colors[4]=Peak, colors[6]=Feed-in, colors[7]=Solar sponge.
class LegendBar extends StatelessWidget {
  final bool showSupply;

  const LegendBar({super.key, required this.showSupply});

  @override
  Widget build(BuildContext context) {
    final entries = <_LegendEntry>[
      _LegendEntry('Solar sponge', colors[7]),
      _LegendEntry('Off-peak', colors[2]),
      _LegendEntry('Shoulder', colors[3]),
      _LegendEntry('Peak', colors[4]),
      _LegendEntry('Controlled load', colors[1]),
      _LegendEntry('Feed-in', colors[6]),
      if (showSupply) _LegendEntry('Supply charge', colors[0]),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: entries.map((e) => _LegendSwatch(entry: e)).toList(),
    );
  }
}

class _LegendEntry {
  final String label;
  final Color color;

  const _LegendEntry(this.label, this.color);
}

class _LegendSwatch extends StatelessWidget {
  final _LegendEntry entry;

  const _LegendSwatch({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 10,
          decoration: BoxDecoration(
            color: entry.color,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ),
        const SizedBox(width: 4),
        Text(entry.label, style: const TextStyle(color: Color(0xFFA7A7B7), fontSize: 11)),
      ],
    );
  }
}
