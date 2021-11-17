import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ui_challenge_7/bar_chart1.dart';
import 'package:ui_challenge_7/my_theme_model.dart';

import 'bar_chart2.dart';
import 'line_chart1.dart';
import 'line_chart2.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => MyThemeModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MyThemeModel>(
      builder: (context, themeModel, child) {
        return MaterialApp(
          title: 'Flutter4fun',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light().copyWith(
            textTheme: const TextTheme(
              bodyText2: TextStyle(color: Color(0xFFA7A7A7), fontSize: 13),
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            textTheme: const TextTheme(
              bodyText2: TextStyle(color: Color(0xFFA7A7A7), fontSize: 13),
            ),
          ),
          themeMode: themeModel.currentTheme(),
          home: const HomePage(),
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MyThemeModel>(
      builder: (context, themeModel, child) {
        return Scaffold(
          backgroundColor:
              themeModel.isDark() ? const Color(0xFF20202A) : Colors.white,
          body: LayoutBuilder(builder: (context, constraints) {
            return Column(
              children: [
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        'Graphs For Dashboards | flutter4fun.com | fl_chart',
                        style: TextStyle(
                          color:
                              themeModel.isDark() ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(child: Container()),
                      Switch(
                        value: themeModel.isDark(),
                        onChanged: (newValue) {
                          Provider.of<MyThemeModel>(context, listen: false)
                              .switchTheme();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: constraints.maxWidth < 800 ? 1 : 2,
                    childAspectRatio: 1.7,
                    padding: const EdgeInsets.only(
                        left: 16, right: 16, bottom: 16, top: 4),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: const [
                      MyCard(child: BarChartWidget1()),
                      MyCard(child: BarChartWidget2()),
                      MyCard(child: LineChartWidget1()),
                      MyCard(child: LineChartWidget2()),
                    ],
                  ),
                ),
              ],
            );
          }),
        );
      },
    );
  }
}

class MyCard extends StatelessWidget {
  final Widget child;

  const MyCard({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MyThemeModel>(
      builder: (context, themeModel, _) {
        return Container(
          child: child,
          decoration: BoxDecoration(
              color:
                  themeModel.isDark() ? const Color(0xFF1A1A26) : Colors.white,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ]),
        );
      },
    );
  }
}
