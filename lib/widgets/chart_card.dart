import 'package:flutter/material.dart';

/// A dark, rounded card used to host a chart: a title row (title left,
/// optional [trailing] right in grey) above the [chart], which is laid out
/// at a fixed height.
class ChartCard extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget chart;

  const ChartCard({super.key, required this.title, this.trailing, required this.chart});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A26),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(color: Color(0xFF9595A4)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(height: 180, child: chart),
        ],
      ),
    );
  }
}
