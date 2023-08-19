import 'dart:convert';
import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:amber/bar_chart.dart';
import 'package:amber/my_theme_model.dart';
import 'package:amber/screenshots_mobile.dart'
    if (dart.library.io) 'package:amber/screenshots_mobile.dart'
    if (dart.library.js) 'package:amber/screenshots_other.dart';
import 'package:amber/utils.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'model/Sites.dart';
import 'model/Usage.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: !kReleaseMode && kIsWeb,
      builder: (context) => ChangeNotifierProvider(
        create: (context) => MyThemeModel(),
        child: const MyApp(),
      ), // Wrap your app
      tools: kIsWeb ? [...DevicePreview.defaultTools, simpleScreenShotModesPlugin] : [],
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
          title: 'Amber Electric Dashboard',
          // Create space for camera cut-outs etc
          useInheritedMediaQuery: true,
          // Hide the dev banner
          debugShowCheckedModeBanner: false,
          // For DevicePreview
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,

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
  late List<Usage>? rawData = [];
  late SharedPreferences prefs;

  final List<ListItem> _dropdownItems = [
    ListItem("1", "Recent Days"),
    ListItem("2", "Combined Days"),
    ListItem("3", "Combined Weeks"),
  ];
  late List<DropdownMenuItem<ListItem>> _dropdownMenuItems;
  late ListItem _dropdownItemSelected;

  final TextEditingController _amberTokenController = TextEditingController();
  String? amberToken;
  List<DropdownMenuItem<ListItem>> _siteIdMenuItems = [];
  late List<Site> _sites;
  ListItem? _siteIdItemSelected;

  @override
  initState() {
    super.initState();
    _dropdownMenuItems = buildDropDownMenuItems(_dropdownItems);
    _dropdownItemSelected = _dropdownMenuItems[0].value!;
    _loadDefaultFile();
  }

  void _loadDefaultFile() async {
    //print('_loadDefaultFile');

    // obtain shared preferences
    prefs = await SharedPreferences.getInstance();
    amberToken = prefs.getString('amberToken');
    List<Usage>? data;
    if (amberToken != null) {
      _amberTokenController.text = amberToken!;

      List<ListItem> sites = await _getSites();
      _siteIdMenuItems = buildDropDownMenuItems(sites);
      _siteIdItemSelected = _siteIdMenuItems[0].value!;

      _getUsage();
    } else {
      setState(() {
        rawData = null;
      });
    }
  }

  Future<List<ListItem>> _getSites() async {
    final response = await http.get(Uri.parse('https://api.amber.com.au/v1/sites'), headers: {
      "accept": "application/json",
      "Authorization": "Bearer ${amberToken!}",
    });

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      _sites = (jsonDecode(response.body) as List).map((json) => Site.fromJson(json)).toList();
      int i = 1;
      return _sites.map((site) => ListItem(site.id!, "${site.network}\n${site.nmi}")).toList();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.body)));
      // If the server did not return a 200 OK response,
      // then throw an exception.
      throw Exception('Failed to load sites! code=${response.statusCode}\n${response.body}');
    }
  }

  Future<void> _getUsage() async {
    String startDate =
        DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 32)));
    String endDate =
        DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
    String uri =
        'https://api.amber.com.au/v1/sites/${_siteIdItemSelected!.value}/usage?startDate=$startDate&endDate=$endDate&resolution=$METER_INTERVAL';
    print(uri);
    final response = await http.get(Uri.parse(uri), headers: {
      "accept": "application/json",
      "Authorization": "Bearer ${amberToken!}",
    });

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      List<Usage> usage =
          (jsonDecode(response.body) as List).map((json) => Usage.fromJson(json)).toList();
      // final myData = await File('assets/feedin.json').readAsString();
      // usage = (jsonDecode(myData) as List).map((json) => Usage.fromJson(json)).toList();

      setState(() {
        rawData = usage;
      });
    } else {
      setState(() {
        rawData = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.body)));

      // If the server did not return a 200 OK response,
      // then throw an exception.
      throw Exception(
          'Failed to load usage for site ${_siteIdItemSelected!.value}! code=${response.statusCode}\n${response.body}');
    }
  }

  Future<void> _displayTextInputDialog(BuildContext context) async {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Amber API Token'),
            content: TextField(
              onChanged: (value) async {
                if (value.length != 36) {
                  return;
                }
                await prefs.setString('amberToken', value);
                setState(() {
                  amberToken = value;
                });
              },
              controller: _amberTokenController,
              decoration: const InputDecoration(hintText: "Amber API Token"),
            ),
            actions: <Widget>[
              MaterialButton(
                color: Colors.green,
                textColor: Colors.white,
                child: const Text('OK'),
                onPressed: () {
                  _loadDefaultFile();
                  setState(() {
                    Navigator.pop(context);
                  });
                },
              ),
            ],
          );
        });
  }

  List<DropdownMenuItem<ListItem>> buildDropDownMenuItems(List listItems) {
    List<DropdownMenuItem<ListItem>> items = [];
    for (ListItem listItem in listItems) {
      items.add(
        DropdownMenuItem(
          value: listItem,
          child: Text(
            listItem.name,
            style: const TextStyle(color: Colors.white),
          ),
          //onTap: () => setState(() {}),
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    //print("build");

    AutoSizeGroup bottomButtonGroup = AutoSizeGroup();

    return Consumer<MyThemeModel>(
      builder: (context, themeModel, child) {
        return Scaffold(
          backgroundColor: themeModel.isDark() ? const Color(0xFF20202A) : Colors.white,
          resizeToAvoidBottomInset: true,
          extendBody: true,
          extendBodyBehindAppBar: true,
          primary: true,
          body: Stack(
            children: [
              OrientationBuilder(builder: (context, orientation) {
                return LayoutBuilder(builder: (context, constraints) {
                  return Column(
                    children: [
                      Container(
                        //height: 120,
                        padding: EdgeInsets.only(
                            left: orientation == Orientation.portrait ? 6 : 36,
                            top: orientation == Orientation.portrait ? 65 : 15,
                            bottom: 3),
                        child: Row(
                          children: [
                            orientation == Orientation.portrait && _siteIdItemSelected != null
                                ? const Text('')
                                : AutoSizeText.rich(
                                    TextSpan(
                                      text: 'Amber Electric Dashboard\n(',
                                      style: TextStyle(
                                        color: themeModel.isDark() ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      children: [
                                        const TextSpan(text: 'Click '),
                                        TextSpan(
                                          text: '\'For Developers\' in Amber',
                                          style: TextStyle(
                                              color: Theme.of(context).textTheme.button?.color ??
                                                  Colors.blueAccent,
                                              height: 1.5),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              Utils.launchURL(
                                                  'https://app.amber.com.au/developers/');
                                            },
                                        ),
                                        orientation == Orientation.portrait
                                            ? const TextSpan(
                                                text: '\nThen ', style: TextStyle(height: 1.5))
                                            : const TextSpan(text: '\nThen '),
                                        TextSpan(
                                          text: 'Generate a new Token',
                                          style: TextStyle(
                                              color: Theme.of(context).textTheme.button?.color ??
                                                  Colors.blueAccent),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              _displayTextInputDialog(context);
                                            },
                                        ),
                                        const TextSpan(text: ')'),
                                      ],
                                    ),
                                  ),
                            const Spacer(flex: 10),
                            // Switch(
                            //   value: themeModel.isDark(),
                            //   onChanged: (newValue) {
                            //     Provider.of<MyThemeModel>(context, listen: false)
                            //         .switchTheme();
                            //   },
                            // ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton(
                                  dropdownColor: const Color(0xFF20202A),
                                  value: _siteIdItemSelected,
                                  items: _siteIdMenuItems,
                                  onChanged: (ListItem? value) {
                                    //print("value=${value!.name}");
                                    setState(() {
                                      _siteIdItemSelected = value!;
                                    });
                                    _getUsage();
                                  }),
                            ),
                            const Spacer(),
                            DropdownButtonHideUnderline(
                              child: DropdownButton(
                                  dropdownColor: const Color(0xFF20202A),
                                  value: _dropdownItemSelected,
                                  items: _dropdownMenuItems,
                                  onChanged: (ListItem? value) {
                                    //print("value=${value!.name}");
                                    setState(() {
                                      _dropdownItemSelected = value!;
                                    });
                                  }),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GridView.count(
                          // Ensure that widget state changes with dropdown changes
                          key: Key(_dropdownItemSelected.name),
                          crossAxisCount: constraints.maxWidth < 710 ? 1 : 2,
                          semanticChildCount: 2,
                          childAspectRatio: 2.34,
                          // Random number that makes my phone look good
                          padding: orientation == Orientation.portrait
                              ? const EdgeInsets.only(left: 4, right: 4, bottom: 4, top: 4)
                              : const EdgeInsets.only(left: 30, right: 10, bottom: 4, top: 4),
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                          children: _dropdownItemSelected.value == _dropdownItems[0].value
                              ? [
                                  MyCard(
                                    child: BarChartWidget1(
                                      rawData,
                                      'Yesterday - Use',
                                      const Duration(days: 1),
                                      ending: const Duration(days: 0),
                                      prices: false,
                                    ),
                                  ),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData, 'Yesterday - Cost', const Duration(days: 1),
                                          ending: const Duration(days: 0), prices: true)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData, '1 Before - Use', const Duration(days: 1),
                                          ending: const Duration(days: 1), prices: false)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData, '1 Before - Cost', const Duration(days: 1),
                                          ending: const Duration(days: 1), prices: true)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData, '2 Before - Use', const Duration(days: 1),
                                          ending: const Duration(days: 2), prices: false)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData, '2 Before - Cost', const Duration(days: 1),
                                          ending: const Duration(days: 2), prices: true)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData, '3 Before - Use', const Duration(days: 1),
                                          ending: const Duration(days: 3), prices: false)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData, '3 Before - Cost', const Duration(days: 1),
                                          ending: const Duration(days: 3), prices: true)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData, '4 Before - Use', const Duration(days: 1),
                                          ending: const Duration(days: 4), prices: false)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData, '4 Before - Cost', const Duration(days: 1),
                                          ending: const Duration(days: 4), prices: true)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData, '5 Before - Use', const Duration(days: 1),
                                          ending: const Duration(days: 5), prices: false)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData, '5 Before - Cost', const Duration(days: 1),
                                          ending: const Duration(days: 5), prices: true)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData, '6 Before - Use', const Duration(days: 1),
                                          ending: const Duration(days: 6), prices: false)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData, '6 Before - Cost', const Duration(days: 1),
                                          ending: const Duration(days: 6), prices: true)),
                                ]
                              : _dropdownItemSelected.value == _dropdownItems[1].value
                                  ? [
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData, 'Last 1 - Use', const Duration(days: 1),
                                              prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData, 'Last 1 - Cost', const Duration(days: 1),
                                              prices: true)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData, 'Last 2 - Use', const Duration(days: 2),
                                              prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(rawData, 'Last 2 - Cost',
                                              const Duration(days: 2),
                                              prices: true)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData, 'Last 7 - Use', const Duration(days: 7),
                                              prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(rawData, 'Last 7 - Cost',
                                              const Duration(days: 7),
                                              prices: true)),
                                      MyCard(
                                          child: BarChartWidget1(rawData, 'Last 14 - Use',
                                              const Duration(days: 14),
                                              prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(rawData, 'Last 14 - Cost',
                                              const Duration(days: 14),
                                              prices: true)),
                                      MyCard(
                                          child: BarChartWidget1(rawData, 'Last 21 - Use',
                                              const Duration(days: 21),
                                              prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(rawData, 'Last 21 - Cost',
                                              const Duration(days: 21),
                                              prices: true)),
                                      MyCard(
                                          child: BarChartWidget1(rawData, 'Last 28 - Use',
                                              const Duration(days: 28),
                                              prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(rawData, 'Last 28 - Cost',
                                              const Duration(days: 28),
                                              prices: true)),
                                    ]
                                  : [
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData, 'This Week - Use', const Duration(days: 7),
                                              ending: const Duration(days: 0), prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData, 'This Week - Cost', const Duration(days: 7),
                                              ending: const Duration(days: 0), prices: true)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData, '1 Week Ago - Use', const Duration(days: 7),
                                              ending: const Duration(days: 7), prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData, '1 Week Ago - Cost', const Duration(days: 7),
                                              ending: const Duration(days: 7), prices: true)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData, '2 Weeks Ago - Use', const Duration(days: 7),
                                              ending: const Duration(days: 14), prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(rawData, '2 Weeks Ago - Cost',
                                              const Duration(days: 7),
                                              ending: const Duration(days: 14), prices: true)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData, '3 Weeks Ago - Use', const Duration(days: 7),
                                              ending: const Duration(days: 21), prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(rawData, '3 Weeks Ago - Cost',
                                              const Duration(days: 7),
                                              ending: const Duration(days: 21), prices: true)),

                                      //MyCard(child: BarChartWidget2()),
                                      //const MyCard(child: LineChartWidget1()),
                                      //MyCard(child: LineChartWidget2()),
                                    ],
                        ),
                      ),
                      Container(
                        color: themeModel.isDark() ? const Color(0xFF20202A) : Colors.white,
                        width: double.infinity,
                        height: 30,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  Utils.launchURL('https://github.com/bradrushworth/amber');
                                },
                                // Constrains AutoSizeText to the width of the Row
                                child: AutoSizeText('Source Code',
                                    maxLines: 1, softWrap: false, group: bottomButtonGroup),
                              ),
                            ),
                            const MyDivider(),
                            Expanded(
                              // Constrains AutoSizeText to the width of the Row
                              child: TextButton(
                                onPressed: () {
                                  Utils.launchURL('https://pub.dev/packages/fl_chart');
                                },
                                child: AutoSizeText('Chart Library',
                                    maxLines: 1, softWrap: false, group: bottomButtonGroup),
                              ),
                            ),
                            const MyDivider(),
                            kIsWeb
                                ? Expanded(
                                    // Constrains AutoSizeText to the width of the Row
                                    child: TextButton(
                                      onPressed: () {
                                        Utils.launchURL('https://www.buymeacoffee.com/bitbot');
                                      },
                                      child: AutoSizeText('Buy Coffee',
                                          maxLines: 1,
                                          softWrap: true,
                                          overflow: TextOverflow.visible,
                                          group: bottomButtonGroup),
                                    ),
                                  )
                                : Expanded(
                                    // Constrains AutoSizeText to the width of the Row
                                    child: TextButton(
                                      onPressed: () {
                                        Utils.launchURL('https://www.bitbot.com.au/');
                                      },
                                      child: AutoSizeText('Visit BitBot',
                                          maxLines: 1,
                                          softWrap: true,
                                          overflow: TextOverflow.visible,
                                          group: bottomButtonGroup),
                                    ),
                                  ),
                            const MyDivider(),
                            Expanded(
                              // Constrains AutoSizeText to the width of the Row
                              child: TextButton(
                                onPressed: () {
                                  Utils.launchURL(
                                      'mailto:bitbot@bitbot.com.au?subject=Help with Amber Electric Dashboard');
                                },
                                child: AutoSizeText('Report Issue',
                                    maxLines: 1, softWrap: false, group: bottomButtonGroup),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                });
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
          decoration: BoxDecoration(
              color: themeModel.isDark() ? const Color(0xFF1A1A26) : Colors.white,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ]),
          child: child,
        );
      },
    );
  }
}

class ListItem {
  String value;
  String name;

  ListItem(this.value, this.name);
}
