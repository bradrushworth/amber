
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
}