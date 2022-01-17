import 'package:auto_size_text/auto_size_text.dart';
import 'package:device_preview/device_preview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:momentum_energy/bar_chart1.dart';
import 'package:momentum_energy/my_theme_model.dart';
import 'package:momentum_energy/screenshots_mobile.dart'
    if (dart.library.io) 'package:momentum_energy/screenshots_mobile.dart'
    if (dart.library.js) 'package:momentum_energy/screenshots_other.dart';
import 'package:momentum_energy/utils.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: !kReleaseMode && kIsWeb,
      builder: (context) => ChangeNotifierProvider(
        create: (context) => MyThemeModel(),
        child: const MyApp(),
      ), // Wrap your app
      tools: kIsWeb
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
          title: 'Momentum Energy Dashboard',
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
  late String rawData = loading;

  final List<ListItem> _dropdownItems = [
    ListItem(1, "Recent Days"),
    ListItem(2, "Combined Days"),
    ListItem(3, "Combined Weeks"),
  ];
  late List<DropdownMenuItem<ListItem>> _dropdownMenuItems;
  late ListItem _dropdownItemSelected;

  @override
  initState() {
    super.initState();
    _dropdownMenuItems = buildDropDownMenuItems(_dropdownItems);
    _dropdownItemSelected = _dropdownMenuItems[0].value!;
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
      withData: true,
      type: FileType.any,
      //allowedExtensions: ['csv'],
      allowMultiple: false,
      allowCompression: false,
    );
    if (result != null && result.files.first.bytes != null) {
      String data = String.fromCharCodes(result.files.first.bytes!);
      //print('_pickFile');
      //print('data=$data');
      setState(() {
        rawData = data;
      });
    } else {
      // User canceled the picker
      setState(() {
        rawData = cancelled;
      });

      // Wait then load the template again
      Future.delayed(const Duration(milliseconds: 2000), () {
        _loadDefaultFile();
      });
    }
  }

  List<DropdownMenuItem<ListItem>> buildDropDownMenuItems(List listItems) {
    List<DropdownMenuItem<ListItem>> items = [];
    for (ListItem listItem in listItems) {
      items.add(
        DropdownMenuItem(
          child: Text(
            listItem.name,
            style: const TextStyle(color: Colors.white),
          ),
          value: listItem,
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
          backgroundColor:
              themeModel.isDark() ? const Color(0xFF20202A) : Colors.white,
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
                            AutoSizeText.rich(
                              TextSpan(
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
                                            Colors.blueAccent,
                                        height: 1.5),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Utils.launchURL(
                                            'https://www.momentumenergy.com.au/myaccount/my-usage');
                                      },
                                  ),
                                  orientation == Orientation.portrait
                                      ? const TextSpan(
                                          text: '\nThen ',
                                          style: TextStyle(height: 1.5))
                                      : const TextSpan(text: ', Then '),
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
                              ? const EdgeInsets.only(
                                  left: 4, right: 4, bottom: 4, top: 4)
                              : const EdgeInsets.only(
                                  left: 30, right: 10, bottom: 4, top: 4),
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                          children: _dropdownItemSelected.value ==
                                  _dropdownItems[0].value
                              ? [
                                  MyCard(
                                    child: BarChartWidget1(
                                      rawData,
                                      'Last Day - Use',
                                      const Duration(days: 1),
                                      ending: const Duration(days: 0),
                                      prices: false,
                                    ),
                                  ),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData,
                                          'Last Day - Cost',
                                          const Duration(days: 1),
                                          ending: const Duration(days: 0),
                                          prices: true)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData,
                                          '1 Day Ago - Use',
                                          const Duration(days: 1),
                                          ending: const Duration(days: 1),
                                          prices: false)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData,
                                          '1 Day Ago - Cost',
                                          const Duration(days: 1),
                                          ending: const Duration(days: 1),
                                          prices: true)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData,
                                          '2 Days Ago - Use',
                                          const Duration(days: 1),
                                          ending: const Duration(days: 2),
                                          prices: false)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData,
                                          '2 Days Ago - Cost',
                                          const Duration(days: 1),
                                          ending: const Duration(days: 2),
                                          prices: true)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData,
                                          '3 Days Ago - Use',
                                          const Duration(days: 1),
                                          ending: const Duration(days: 3),
                                          prices: false)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData,
                                          '3 Days Ago - Cost',
                                          const Duration(days: 1),
                                          ending: const Duration(days: 3),
                                          prices: true)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData,
                                          '4 Days Ago - Use',
                                          const Duration(days: 1),
                                          ending: const Duration(days: 4),
                                          prices: false)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData,
                                          '4 Days Ago - Cost',
                                          const Duration(days: 1),
                                          ending: const Duration(days: 4),
                                          prices: true)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData,
                                          '5 Days Ago - Use',
                                          const Duration(days: 1),
                                          ending: const Duration(days: 5),
                                          prices: false)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData,
                                          '5 Days Ago - Cost',
                                          const Duration(days: 1),
                                          ending: const Duration(days: 5),
                                          prices: true)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData,
                                          '6 Days Ago - Use',
                                          const Duration(days: 1),
                                          ending: const Duration(days: 6),
                                          prices: false)),
                                  MyCard(
                                      child: BarChartWidget1(
                                          rawData,
                                          '6 Days Ago - Cost',
                                          const Duration(days: 1),
                                          ending: const Duration(days: 6),
                                          prices: true)),
                                ]
                              : _dropdownItemSelected.value ==
                                      _dropdownItems[1].value
                                  ? [
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              'Last 1 Day - Use',
                                              const Duration(days: 1),
                                              prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              'Last 1 Day - Cost',
                                              const Duration(days: 1),
                                              prices: true)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              'Last 2 Days - Use',
                                              const Duration(days: 2),
                                              prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              'Last 2 Days - Cost',
                                              const Duration(days: 2),
                                              prices: true)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              'Last 7 Days - Use',
                                              const Duration(days: 7),
                                              prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              'Last 7 Days - Cost',
                                              const Duration(days: 7),
                                              prices: true)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              'Last 14 Days - Use',
                                              const Duration(days: 14),
                                              prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              'Last 14 Days - Cost',
                                              const Duration(days: 14),
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
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              'Last 28 Days - Use',
                                              const Duration(days: 28),
                                              prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              'Last 28 Days - Cost',
                                              const Duration(days: 28),
                                              prices: true)),
                                    ]
                                  : [
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              'This Week - Use',
                                              const Duration(days: 7),
                                              ending: const Duration(days: 0),
                                              prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              'This Week - Cost',
                                              const Duration(days: 7),
                                              ending: const Duration(days: 0),
                                              prices: true)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              '1 Week Ago - Use',
                                              const Duration(days: 7),
                                              ending: const Duration(days: 7),
                                              prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              '1 Week Ago - Cost',
                                              const Duration(days: 7),
                                              ending: const Duration(days: 7),
                                              prices: true)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              '2 Weeks Ago - Use',
                                              const Duration(days: 7),
                                              ending: const Duration(days: 14),
                                              prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              '2 Weeks Ago - Cost',
                                              const Duration(days: 7),
                                              ending: const Duration(days: 14),
                                              prices: true)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              '3 Weeks Ago - Use',
                                              const Duration(days: 7),
                                              ending: const Duration(days: 21),
                                              prices: false)),
                                      MyCard(
                                          child: BarChartWidget1(
                                              rawData,
                                              '3 Weeks Ago - Cost',
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
                        color: themeModel.isDark()
                            ? const Color(0xFF20202A)
                            : Colors.white,
                        width: double.infinity,
                        height: 30,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  Utils.launchURL(
                                      'https://github.com/bradrushworth/momentumenergy');
                                },
                                // Constrains AutoSizeText to the width of the Row
                                child: AutoSizeText('Source Code',
                                    maxLines: 1,
                                    softWrap: false,
                                    group: bottomButtonGroup),
                              ),
                            ),
                            const MyDivider(),
                            Expanded(
                              // Constrains AutoSizeText to the width of the Row
                              child: TextButton(
                                onPressed: () {
                                  Utils.launchURL(
                                      'https://pub.dev/packages/fl_chart');
                                },
                                child: AutoSizeText('Chart Library',
                                    maxLines: 1,
                                    softWrap: false,
                                    group: bottomButtonGroup),
                              ),
                            ),
                            const MyDivider(),
                            Expanded(
                              // Constrains AutoSizeText to the width of the Row
                              child: TextButton(
                                onPressed: () {
                                  Utils.launchURL(
                                      'https://www.buymeacoffee.com/bitbot');
                                },
                                child: AutoSizeText('Buy Coffee',
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
                                      'mailto:bitbot@bitbot.com.au?subject=Help with Momentum Energy Dashboard');
                                },
                                child: AutoSizeText('Report Issue',
                                    maxLines: 1,
                                    softWrap: false,
                                    group: bottomButtonGroup),
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

class ListItem {
  int value;
  String name;

  ListItem(this.value, this.name);
}
