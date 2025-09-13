import 'dart:html' as html;

import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:screenshot_modes/screenshot_modes.dart';

///
/// Automatically take screenshots for the Apple and Google App Stores!
///
final simpleScreenShotModesPlugin = SimpleScreenShot(
  processor: saveScreenShot,
  pages: listPush,
  devices: [
    Devices.android.samsungGalaxyNote20Ultra.identifier,
    Devices.android.sonyXperia1II.identifier,
    Devices.android.smallPhone.identifier,
    Devices.android.largeTablet.identifier,
    Devices.ios.iPadAir4.identifier,
    Devices.ios.iPhoneSE.identifier,
    Devices.ios.iPhone13ProMax.identifier,
  ],
  lang: const [Locale('en_AU')],
  useToggleDarkMode: false,
);

final listPush = [
  const ItemScreenMode(function: pushFirstScreenshot, label: 'home'),
];

Future pushFirstScreenshot(BuildContext context) async {
  // navigatorKey.currentState!.push(DirectPageRouteBuilder(
  //     builder: (BuildContext context) =>
  //         MyHomePage(title: 'Ant Nuptial Flight Predictor')));
}

Future<String> saveScreenShot(DeviceScreenshotWithLabel screen) async {
  // Flutter image resize is SUPER slow!
  // images.Image image = images.decodePng(screen.deviceScreenshot.bytes)!;
  // print('image width=${image.width} height=${image.height}');
  // images.Image thumbnail = images.copyResize(image,
  //     // Exact size needed for Apple App Store
  //     height: (image.height * 0.52316384180790960451977401129944).toInt(),
  //     width: (image.width * 0.52316384180790960451977401129944).toInt(),
  //     interpolation: images.Interpolation.linear);
  // final blob =
  //     html.Blob([Uint8List.fromList(images.encodePng(thumbnail))], 'image/png');

  final blob = html.Blob([screen.deviceScreenshot.bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..style.display = 'none'
    ..download =
        '${screen.deviceScreenshot.device.name} ${screen.label.toString()}.png';
  html.document.body!.children.add(anchor);

  // download
  anchor.click();

  // cleanup
  html.document.body!.children.remove(anchor);
  html.Url.revokeObjectUrl(url);

  return screen.deviceScreenshot.device.name;
}
