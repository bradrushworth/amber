import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Utils {
  static void launchURI(Uri uri) async =>
      await canLaunchUrl(uri) ? await launchUrl(uri) : throw 'Could not launch $uri';

  static String monthIntToName(double xValue) {
    switch (xValue.toInt()) {
      case 0:
        return 'Jan';
      case 1:
        return 'Feb';
      case 2:
        return 'Mar';
      case 3:
        return 'Apr';
      case 4:
        return 'May';
      case 5:
        return 'Jun';
      case 6:
        return 'Jul';
      case 7:
        return 'Aug';
      case 8:
        return 'Sep';
      case 9:
        return 'Oct';
      case 10:
        return 'Nov';
      case 11:
        return 'Dec';
      default:
        throw StateError('Not supported');
    }
  }

  static DateTime toLocal(DateTime dateTime) {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return dateTime.add(const Duration(hours: 10));
    } else {
      return dateTime.toLocal();
    }
  }

  /// Darken a color by [percent] amount (100 = black)
  static Color darken(Color c, [int percent = 10]) {
    assert(1 <= percent && percent <= 100);
    var f = 1 - percent / 100;
    return Color.fromARGB(
        c.alpha, (c.red * f).round(), (c.green * f).round(), (c.blue * f).round());
  }

  /// Lighten a color by [percent] amount (100 = white)
  static Color lighten(Color c, [int percent = 10]) {
    assert(1 <= percent && percent <= 100);
    var p = percent / 100;
    return Color.fromARGB(c.alpha, c.red + ((255 - c.red) * p).round(),
        c.green + ((255 - c.green) * p).round(), c.blue + ((255 - c.blue) * p).round());
  }
}
