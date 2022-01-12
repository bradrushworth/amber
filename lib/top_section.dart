import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:momentum_energy/my_theme_model.dart';
import 'package:provider/provider.dart';

final AutoSizeGroup legendSizeGroup = AutoSizeGroup();

class TopSectionWidget extends StatelessWidget {
  final String title;
  final List<Legend> legends;
  final EdgeInsets padding;

  const TopSectionWidget({
    Key? key,
    required this.title,
    required this.legends,
    this.padding = EdgeInsets.zero,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MyThemeModel>(
      builder: (context, themeModel, child) {
        return Container(
          height: 20,
          margin: padding,
          child: Row(
            children: [
              AutoSizeText(title,
                  group: legendSizeGroup,
                  style: TextStyle(
                      color: themeModel.isDark()
                          ? const Color(0xFF9595A4)
                          : const Color(0xFF040420),
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              Expanded(child: Container(), flex: 1),
              ...legends
                  .map(
                    (e) => Row(
                      children: [
                        _LegendWidget(legend: e),
                        const SizedBox(width: 4),
                      ],
                    ),
                  )
                  .toList(),
              //Expanded(child: Container(), flex: 1),
              //const Text('', style: TextStyle(color: Color(0xFFA7A7B7))),
            ],
          ),
        );
      },
    );
  }
}

class _LegendWidget extends StatelessWidget {
  final Legend legend;

  const _LegendWidget({
    Key? key,
    required this.legend,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 10,
          decoration: BoxDecoration(
            color: legend.color,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ),
        const SizedBox(width: 2),
        AutoSizeText(legend.title,
            group: legendSizeGroup,
            style: const TextStyle(color: Color(0xFFA7A7B7))),
      ],
    );
  }
}

class Legend {
  final String title;
  final Color color;

  Legend({
    required this.title,
    required this.color,
  });
}
