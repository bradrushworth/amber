import 'dart:async';
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
import 'package:keep_screen_on/keep_screen_on.dart';
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
      tools: !kReleaseMode && kIsWeb
          ? [...DevicePreview.defaultTools, simpleScreenShotModesPlugin]
          : [],
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
          color: Colors.white,

          // Hide the dev banner
          debugShowCheckedModeBanner: false,
          // For DevicePreview
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,

          theme: ThemeData.light().copyWith(
            primaryColor: Colors.white,
            textTheme: const TextTheme(
              bodyText2: TextStyle(color: Color(0xFFA7A7A7), fontSize: 13),
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            primaryColor: Colors.white,
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
  List<Usage>? forecastData = [];
  List<Usage>? rawData = [];
  late SharedPreferences prefs;

  final List<ListItem> _dropdownItems = [
    ListItem("1", "Forecast"),
    ListItem("2", "Recent Days"),
    ListItem("3", "Combined Days"),
    ListItem("4", "Weekly Usage"),
  ];
  late List<DropdownMenuItem<ListItem>> _dropdownMenuItems;
  late ListItem _dropdownItemSelected;

  final TextEditingController _amberTokenController = TextEditingController();
  String? amberToken;
  List<DropdownMenuItem<ListItem>> _siteIdMenuItems = [];
  late List<Site> _sites;
  ListItem? _siteIdItemSelected;
  Timer? _timerForecast, _timerUsage;

  @override
  initState() {
    super.initState();
    _dropdownMenuItems = buildDropDownMenuItems(_dropdownItems);
    _dropdownItemSelected = _dropdownMenuItems[0].value!;
    _loadData();

    if (!kIsWeb) {
      if (Platform.isAndroid || Platform.isIOS) {
        // Keep the screen on
        KeepScreenOn.turnOn();
      }
    }

    _timerForecast = Timer.periodic(const Duration(minutes: 1), (Timer t) => _getForecast());
    _timerUsage = Timer.periodic(const Duration(hours: 1), (Timer t) => _getUsage());
  }

  @override
  void dispose() {
    _timerForecast?.cancel();
    _timerUsage?.cancel();
    if (!kIsWeb) {
      if (Platform.isAndroid || Platform.isIOS) {
        KeepScreenOn.turnOff();
      }
    }
    super.dispose();
  }

  void _loadData() async {
    //print('_loadData');

    // obtain shared preferences
    prefs = await SharedPreferences.getInstance();
    amberToken = prefs.getString('amberToken');
    List<Usage>? data;
    if (amberToken != null) {
      _amberTokenController.text = amberToken!;

      List<ListItem> sites = await _getSites();
      _siteIdMenuItems = buildDropDownMenuItems(sites);
      _siteIdItemSelected = _siteIdMenuItems[0].value!;

      _getForecast();
      _getUsage();
    } else {
      setState(() {
        forecastData = null;
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

  Future<void> _getForecast() async {
    var date = DateTime.now();
    int numPeriodsBack = (2 * date.hour) + (date.minute ~/ 30);
    int numPeriodsForward = 24 * 60 ~/ METER_INTERVAL * 2 - numPeriodsBack - 1;
    numPeriodsBack += 24 * 60 ~/ METER_INTERVAL;

    var utc = date.toUtc();
    var today = DateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute, utc.second).toLocal();
    var yesterday = DateTime.utc(utc.year, utc.month - 6, utc.day, utc.hour, utc.minute, utc.second).toLocal();
    //print('today=$today yesterday=$yesterday difference=${today.difference(yesterday).inHours}');
    if (today.hour > yesterday.hour) {
      // If the day that daylight savings starts
      numPeriodsBack -= 60 ~/ METER_INTERVAL;
      numPeriodsForward += 60 ~/ METER_INTERVAL;
      //print('numPeriodsBack');
    }
    if (today.hour < yesterday.hour) {
      // If the day that daylight savings ends
      numPeriodsBack += 60 ~/ METER_INTERVAL;
      numPeriodsForward -= 60 ~/ METER_INTERVAL;
      //print('numPeriodsForward');
    }

    String uri =
        'https://api.amber.com.au/v1/sites/${_siteIdItemSelected!.value}/prices/current?next=$numPeriodsForward&previous=$numPeriodsBack&resolution=$METER_INTERVAL';
    print(uri);
    final response = await http.get(Uri.parse(uri), headers: {
      "accept": "application/json",
      "Authorization": "Bearer ${amberToken!}",
    });

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      List<Usage> prices = (jsonDecode(response.body) as List)
          .map((json) => Usage.fromJson(json))
          .toList()
          .reversed
          .toList();

      setState(() {
        forecastData = prices;
      });
    } else {
      setState(() {
        forecastData = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.body)));

      // If the server did not return a 200 OK response,
      // then throw an exception.
      throw Exception(
          'Failed to load forecast for site ${_siteIdItemSelected!.value}! code=${response.statusCode}\n${response.body}');
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
                value = value.trim();
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
                  _loadData();
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

    DateTime now = DateTime.now().subtract(const Duration(days: 1));
    final DateFormat weekdayDayMonth = DateFormat('E d LLL');

    return Consumer<MyThemeModel>(
      builder: (context, themeModel, child) {
        return Scaffold(
          backgroundColor: themeModel.isDark() ? const Color(0xFF20202A) : Colors.white,
          resizeToAvoidBottomInset: true,
          extendBody: true,
          extendBodyBehindAppBar: false,
          primary: true,
          body: Stack(
            children: [
              OrientationBuilder(builder: (context, orientation) {
                return LayoutBuilder(builder: (context, constraints) {
                  return SafeArea(
                    minimum: EdgeInsets.only(
                        left: orientation == Orientation.portrait ? 6 : 4,
                        right: orientation == Orientation.portrait ? 2 : 2,
                        top: 0,
                        bottom: 0),
                    bottom: false,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            AutoSizeText.rich(
                              TextSpan(
                                text: orientation == Orientation.portrait &&
                                        _siteIdItemSelected != null
                                    ? constraints.maxWidth <= 360
                                        ? 'Amber'
                                        : 'Amber\nDashboard'
                                    : 'Amber Electric Dashboard',
                                style: TextStyle(
                                  color: themeModel.isDark() ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                                children: orientation == Orientation.portrait &&
                                        _siteIdItemSelected != null
                                    ? [const TextSpan(text: '')]
                                    : [
                                        const TextSpan(text: '\nEnable '),
                                        TextSpan(
                                          text: '\'For Developers\'',
                                          style: TextStyle(
                                              color: Theme.of(context).textTheme.button?.color ??
                                                  Colors.blueAccent,
                                              height: 1.5),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              Utils.launchURI(Uri(
                                                scheme: 'https',
                                                host: 'app.amber.com.au',
                                                path: '/',
                                              ));
                                            },
                                        ),
                                        orientation == Orientation.portrait
                                            ? const TextSpan(
                                                text: '\nThen ', style: TextStyle(height: 1.5))
                                            : const TextSpan(text: ', Then '),
                                        TextSpan(
                                          text: '\'Generate a new Token\'',
                                          style: TextStyle(
                                              color: Theme.of(context).textTheme.button?.color ??
                                                  Colors.blueAccent),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              _displayTextInputDialog(context);
                                            },
                                        ),
                                        const TextSpan(text: ''),
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
                                    _getForecast();
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
                        Expanded(
                          child: GridView.count(
                            // Ensure that widget state changes with dropdown changes
                            key: Key(_dropdownItemSelected.name),
                            crossAxisCount: constraints.maxWidth < 710 ? 1 : 2,
                            semanticChildCount: 2,
                            childAspectRatio: 2.34,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                            children: _dropdownItemSelected.value == _dropdownItems[0].value
                                ? [
                                    MyCard(
                                        child: BarChartWidget1(forecastData, 'Yesterday\'s Price',
                                            const Duration(days: 1),
                                            ending: const Duration(days: 0),
                                            prices: false,
                                            forecast: true)),
                                    MyCard(
                                        child: BarChartWidget1(forecastData, 'Yesterday\'s Prices',
                                            const Duration(days: 1),
                                            ending: const Duration(days: 0),
                                            prices: true,
                                            forecast: true)),
                                    MyCard(
                                        child: BarChartWidget1(
                                            forecastData, 'Today\'s Price', const Duration(days: 1),
                                            ending: const Duration(days: -1),
                                            prices: false,
                                            forecast: true)),
                                    MyCard(
                                        child: BarChartWidget1(forecastData, 'Today\'s Prices',
                                            const Duration(days: 1),
                                            ending: const Duration(days: -1),
                                            prices: true,
                                            forecast: true)),
                                    MyCard(
                                        child: BarChartWidget1(forecastData, 'Tomorrow\'s Price',
                                            const Duration(days: 1),
                                            ending: const Duration(days: -2),
                                            prices: false,
                                            forecast: true)),
                                    MyCard(
                                        child: BarChartWidget1(forecastData, 'Tomorrow\'s Prices',
                                            const Duration(days: 1),
                                            ending: const Duration(days: -2),
                                            prices: true,
                                            forecast: true)),
                                  ]
                                : _dropdownItemSelected.value == _dropdownItems[1].value
                                    ? [
                                        MyCard(
                                          child: BarChartWidget1(
                                            rawData,
                                            '${weekdayDayMonth.format(now.subtract(const Duration(days: 0)))} Use',
                                            const Duration(days: 1),
                                            ending: const Duration(days: 0),
                                            prices: false,
                                          ),
                                        ),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData,
                                                '${weekdayDayMonth.format(now.subtract(const Duration(days: 0)))} Cost',
                                                const Duration(days: 1),
                                                ending: const Duration(days: 0),
                                                prices: true)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData,
                                                '${weekdayDayMonth.format(now.subtract(const Duration(days: 1)))} Use',
                                                const Duration(days: 1),
                                                ending: const Duration(days: 1),
                                                prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData,
                                                '${weekdayDayMonth.format(now.subtract(const Duration(days: 1)))} Cost',
                                                const Duration(days: 1),
                                                ending: const Duration(days: 1),
                                                prices: true)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData,
                                                '${weekdayDayMonth.format(now.subtract(const Duration(days: 2)))} Use',
                                                const Duration(days: 1),
                                                ending: const Duration(days: 2),
                                                prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData,
                                                '${weekdayDayMonth.format(now.subtract(const Duration(days: 2)))} Cost',
                                                const Duration(days: 1),
                                                ending: const Duration(days: 2),
                                                prices: true)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData,
                                                '${weekdayDayMonth.format(now.subtract(const Duration(days: 3)))} Use',
                                                const Duration(days: 1),
                                                ending: const Duration(days: 3),
                                                prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData,
                                                '${weekdayDayMonth.format(now.subtract(const Duration(days: 3)))} Cost',
                                                const Duration(days: 1),
                                                ending: const Duration(days: 3),
                                                prices: true)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData,
                                                '${weekdayDayMonth.format(now.subtract(const Duration(days: 4)))} Use',
                                                const Duration(days: 1),
                                                ending: const Duration(days: 4),
                                                prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData,
                                                '${weekdayDayMonth.format(now.subtract(const Duration(days: 4)))} Cost',
                                                const Duration(days: 1),
                                                ending: const Duration(days: 4),
                                                prices: true)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData,
                                                '${weekdayDayMonth.format(now.subtract(const Duration(days: 5)))} Use',
                                                const Duration(days: 1),
                                                ending: const Duration(days: 5),
                                                prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData,
                                                '${weekdayDayMonth.format(now.subtract(const Duration(days: 5)))} Cost',
                                                const Duration(days: 1),
                                                ending: const Duration(days: 5),
                                                prices: true)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData,
                                                '${weekdayDayMonth.format(now.subtract(const Duration(days: 6)))} Use',
                                                const Duration(days: 1),
                                                ending: const Duration(days: 6),
                                                prices: false)),
                                        MyCard(
                                            child: BarChartWidget1(
                                                rawData,
                                                '${weekdayDayMonth.format(now.subtract(const Duration(days: 6)))} Cost',
                                                const Duration(days: 1),
                                                ending: const Duration(days: 6),
                                                prices: true)),
                                      ]
                                    : _dropdownItemSelected.value == _dropdownItems[2].value
                                        ? [
                                            MyCard(
                                                child: BarChartWidget1(
                                                    rawData, '1 Days Use', const Duration(days: 1),
                                                    prices: false)),
                                            MyCard(
                                                child: BarChartWidget1(
                                                    rawData, '1 Days Cost', const Duration(days: 1),
                                                    prices: true)),
                                            MyCard(
                                                child: BarChartWidget1(
                                                    rawData, '2 Days Use', const Duration(days: 2),
                                                    prices: false)),
                                            MyCard(
                                                child: BarChartWidget1(
                                                    rawData, '2 Days Cost', const Duration(days: 2),
                                                    prices: true)),
                                            MyCard(
                                                child: BarChartWidget1(
                                                    rawData, '7 Days Use', const Duration(days: 7),
                                                    prices: false)),
                                            MyCard(
                                                child: BarChartWidget1(
                                                    rawData, '7 Days Cost', const Duration(days: 7),
                                                    prices: true)),
                                            MyCard(
                                                child: BarChartWidget1(rawData, '14 Days Use',
                                                    const Duration(days: 14),
                                                    prices: false)),
                                            MyCard(
                                                child: BarChartWidget1(rawData, '14 Days Cost',
                                                    const Duration(days: 14),
                                                    prices: true)),
                                            MyCard(
                                                child: BarChartWidget1(rawData, '21 Days Use',
                                                    const Duration(days: 21),
                                                    prices: false)),
                                            MyCard(
                                                child: BarChartWidget1(rawData, '21 Days Cost',
                                                    const Duration(days: 21),
                                                    prices: true)),
                                            MyCard(
                                                child: BarChartWidget1(rawData, '28 Days Use',
                                                    const Duration(days: 28),
                                                    prices: false)),
                                            MyCard(
                                                child: BarChartWidget1(rawData, '28 Days Cost',
                                                    const Duration(days: 28),
                                                    prices: true)),
                                          ]
                                        : [
                                            MyCard(
                                                child: BarChartWidget1(rawData, 'This Week Use',
                                                    const Duration(days: 7),
                                                    ending: const Duration(days: 0),
                                                    prices: false)),
                                            MyCard(
                                                child: BarChartWidget1(rawData, 'This Week Cost',
                                                    const Duration(days: 7),
                                                    ending: const Duration(days: 0), prices: true)),
                                            MyCard(
                                                child: BarChartWidget1(rawData, '1 Week Ago Use',
                                                    const Duration(days: 7),
                                                    ending: const Duration(days: 7),
                                                    prices: false)),
                                            MyCard(
                                                child: BarChartWidget1(rawData, '1 Week Ago Cost',
                                                    const Duration(days: 7),
                                                    ending: const Duration(days: 7), prices: true)),
                                            MyCard(
                                                child: BarChartWidget1(rawData, '2 Weeks Ago Use',
                                                    const Duration(days: 7),
                                                    ending: const Duration(days: 14),
                                                    prices: false)),
                                            MyCard(
                                                child: BarChartWidget1(rawData, '2 Weeks Ago Cost',
                                                    const Duration(days: 7),
                                                    ending: const Duration(days: 14),
                                                    prices: true)),
                                            MyCard(
                                                child: BarChartWidget1(rawData, '3 Weeks Ago Use',
                                                    const Duration(days: 7),
                                                    ending: const Duration(days: 21),
                                                    prices: false)),
                                            MyCard(
                                                child: BarChartWidget1(rawData, '3 Weeks Ago Cost',
                                                    const Duration(days: 7),
                                                    ending: const Duration(days: 21),
                                                    prices: true)),

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
                                // Constrains AutoSizeText to the width of the Row
                                child: TextButton(
                                  onPressed: () {
                                    Utils.launchURI(Uri(
                                      scheme: 'mailto',
                                      path: 'bitbot@bitbot.com.au',
                                      query: 'subject=Help with Amber Electric Dashboard',
                                    ));
                                  },
                                  child: AutoSizeText('Support',
                                      maxLines: 1, softWrap: false, group: bottomButtonGroup),
                                ),
                              ),
                              const MyDivider(),
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    Utils.launchURI(Uri(
                                      scheme: 'https',
                                      host: 'github.com',
                                      path: '/bradrushworth/amber/issues',
                                    ));
                                  },
                                  // Constrains AutoSizeText to the width of the Row
                                  child: AutoSizeText('Improvements',
                                      maxLines: 1, softWrap: false, group: bottomButtonGroup),
                                ),
                              ),
                              const MyDivider(),
                              Expanded(
                                // Constrains AutoSizeText to the width of the Row
                                child: TextButton(
                                  onPressed: () {
                                    Utils.launchURI(Uri(
                                      scheme: 'https',
                                      host: 'github.com',
                                      path: '/bradrushworth/amber',
                                    ));
                                  },
                                  child: AutoSizeText('Source Code',
                                      maxLines: 1, softWrap: false, group: bottomButtonGroup),
                                ),
                              ),
                              const MyDivider(),
                              kIsWeb && kReleaseMode
                                  ? Expanded(
                                      // Constrains AutoSizeText to the width of the Row
                                      child: TextButton(
                                        onPressed: () {
                                          Utils.launchURI(Uri(
                                            scheme: 'https',
                                            host: 'www.buymeacoffee.com',
                                            path: '/bitbot',
                                          ));
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
                                          Utils.launchURI(Uri(
                                            scheme: 'https',
                                            host: 'www.bitbot.com.au',
                                            path: '/',
                                          ));
                                        },
                                        child: AutoSizeText('Visit BitBot',
                                            maxLines: 1,
                                            softWrap: true,
                                            overflow: TextOverflow.visible,
                                            group: bottomButtonGroup),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
