import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MyThemeModel extends ChangeNotifier {
  bool _isDark = false;

  ThemeMode currentTheme() {
    return _isDark ? ThemeMode.dark : ThemeMode.light;
  }

  bool isDark() {
    return currentTheme() == ThemeMode.dark;
  }

  void switchTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }
}