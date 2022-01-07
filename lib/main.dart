import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:momentum_energy/bar_chart1.dart';
import 'package:momentum_energy/my_theme_model.dart';
import 'package:momentum_energy/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => MyThemeModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MyThemeModel>(
      builder: (context, themeModel, child) {
        return MaterialApp(
          title: 'Momentum Energy Dashboard',
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

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late String rawData = 'Loading';

  @override
  initState() {
    super.initState();
    _loadDefaultFile();
  }

  void _loadDefaultFile() async {
    //print('_loadDefaultFile');
    String data = await rootBundle.loadString('assets/Your_Usage_List.csv');
    //print('data=$data');
    setState(() {
      rawData = data;
    });
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: false,
      allowCompression: false,
    );
    if (result != null) {
      String data = String.fromCharCodes(result.files.first.bytes!);
      //print('_pickFile');
      //print('data=$data');
      setState(() {
        rawData = data;
      });
    } else {
      // User canceled the picker, use pre-canned example
      _loadDefaultFile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MyThemeModel>(
      builder: (context, themeModel, child) {
        return Scaffold(
          backgroundColor:
              themeModel.isDark() ? const Color(0xFF20202A) : Colors.white,
          body: Stack(
            children: [
              LayoutBuilder(builder: (context, constraints) {
                return Column(
                  children: [
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          RichText(
                            text: TextSpan(
                              text: 'Momentum Energy Dashboard\n(',
                              style: TextStyle(
                                color: themeModel.isDark()
                                    ? Colors.white
                                    : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                              children: [
                                const TextSpan(text: 'Click '),
                                TextSpan(
                                  text: '\'Export table\' from MyAccount',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                              .textTheme
                                              .button
                                              ?.color ??
                                          Colors.blueAccent),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Utils.launchURL(
                                          'https://www.momentumenergy.com.au/myaccount/my-usage');
                                    },
                                ),
                                const TextSpan(text: ', Then '),
                                TextSpan(
                                  text: 'Upload File',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                              .textTheme
                                              .button
                                              ?.color ??
                                          Colors.blueAccent),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      _pickFile();
                                    },
                                ),
                                const TextSpan(text: ')'),
                              ],
                            ),
                          ),
                          const Spacer(),
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
                        children: [
                          MyCard(
                            child: BarChartWidget1(
                              rawData,
                              'Last Day - Use',
                              const Duration(days: 1),
                              ending: const Duration(days: 0),
                              prices: false,
                              // voidCallback: () {
                              //   setState(() {
                              //     rawData = rawData;
                              //   });
                              // },
                            ),
                          ),
                          MyCard(
                              child: BarChartWidget1(rawData, 'Last Day - Cost',
                                  const Duration(days: 1),
                                  ending: const Duration(days: 0),
                                  prices: true)),
                          MyCard(
                              child: BarChartWidget1(rawData,
                                  '2nd Last Day - Use', const Duration(days: 1),
                                  ending: const Duration(days: 1),
                                  prices: false)),
                          MyCard(
                              child: BarChartWidget1(
                                  rawData,
                                  '2nd Last Day - Cost',
                                  const Duration(days: 1),
                                  ending: const Duration(days: 1),
                                  prices: true)),
                          MyCard(
                              child: BarChartWidget1(rawData,
                                  '3rd Last Day - Use', const Duration(days: 1),
                                  ending: const Duration(days: 2),
                                  prices: false)),
                          MyCard(
                              child: BarChartWidget1(
                                  rawData,
                                  '3rd Last Day - Cost',
                                  const Duration(days: 1),
                                  ending: const Duration(days: 2),
                                  prices: true)),
                          MyCard(
                              child: BarChartWidget1(rawData,
                                  '4th Last Day - Use', const Duration(days: 1),
                                  ending: const Duration(days: 3),
                                  prices: false)),
                          MyCard(
                              child: BarChartWidget1(
                                  rawData,
                                  '4th Last Day - Cost',
                                  const Duration(days: 1),
                                  ending: const Duration(days: 3),
                                  prices: true)),
                          const Spacer(),
                          const Spacer(),
                          MyCard(
                              child: BarChartWidget1(rawData, 'Last Day - Use',
                                  const Duration(days: 1),
                                  prices: false)),
                          MyCard(
                              child: BarChartWidget1(rawData, 'Last Day - Cost',
                                  const Duration(days: 1),
                                  prices: true)),
                          MyCard(
                              child: BarChartWidget1(rawData,
                                  'Last 2 Days - Use', const Duration(days: 2),
                                  prices: false)),
                          MyCard(
                              child: BarChartWidget1(rawData,
                                  'Last 2 Days - Cost', const Duration(days: 2),
                                  prices: true)),
                          MyCard(
                              child: BarChartWidget1(rawData,
                                  'Last 7 Days - Use', const Duration(days: 7),
                                  prices: false)),
                          MyCard(
                              child: BarChartWidget1(rawData,
                                  'Last 7 Days - Cost', const Duration(days: 7),
                                  prices: true)),
                          MyCard(
                              child: BarChartWidget1(
                                  rawData,
                                  'Last 21 Days - Use',
                                  const Duration(days: 21),
                                  prices: false)),
                          MyCard(
                              child: BarChartWidget1(
                                  rawData,
                                  'Last 21 Days - Cost',
                                  const Duration(days: 21),
                                  prices: true)),
                          const Spacer(),
                          const Spacer(),
                          MyCard(
                              child: BarChartWidget1(rawData, 'This Week - Use',
                                  const Duration(days: 7),
                                  ending: const Duration(days: 0),
                                  prices: false)),
                          MyCard(
                              child: BarChartWidget1(rawData,
                                  'This Week - Cost', const Duration(days: 7),
                                  ending: const Duration(days: 0),
                                  prices: true)),
                          MyCard(
                              child: BarChartWidget1(rawData,
                                  '1 Week Ago - Use', const Duration(days: 7),
                                  ending: const Duration(days: 7),
                                  prices: false)),
                          MyCard(
                              child: BarChartWidget1(rawData,
                                  '1 Week Ago - Cost', const Duration(days: 7),
                                  ending: const Duration(days: 7),
                                  prices: true)),
                          MyCard(
                              child: BarChartWidget1(rawData,
                                  '2 Weeks Ago - Use', const Duration(days: 7),
                                  ending: const Duration(days: 14),
                                  prices: false)),
                          MyCard(
                              child: BarChartWidget1(rawData,
                                  '2 Weeks Ago - Cost', const Duration(days: 7),
                                  ending: const Duration(days: 14),
                                  prices: true)),

                          //MyCard(child: BarChartWidget2()),
                          //const MyCard(child: LineChartWidget1()),
                          //MyCard(child: LineChartWidget2()),
                        ],
                      ),
                    ),
                    Container(
                      color: themeModel.isDark()
                          ? const Color(0xFF20202A)
                          : Colors.white,
                      width: double.infinity,
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              Utils.launchURL(
                                  'https://github.com/bradrushworth/momentumenergy');
                            },
                            child: const Text('Source Code'),
                          ),
                          const MyDivider(),
                          TextButton(
                            onPressed: () {
                              Utils.launchURL(
                                  'https://pub.dev/packages/fl_chart');
                            },
                            child: const Text('Chart Library'),
                          ),
                          const MyDivider(),
                          TextButton(
                            onPressed: () {
                              Utils.launchURL(
                                  'https://www.buymeacoffee.com/bitbot');
                            },
                            child: const Text('Buy Brad Coffee'),
                          ),
                          const MyDivider(),
                          TextButton(
                            onPressed: () {
                              Utils.launchURL(
                                  'mailto:bitbot@bitbot.com.au?subject=Help with Momentum Energy Dashboard');
                            },
                            child: const Text('Report Issue'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class MyDivider extends StatelessWidget {
  const MyDivider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      width: 1,
      color: const Color(0xFFA7A7A7),
      margin: const EdgeInsets.only(top: 2),
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
