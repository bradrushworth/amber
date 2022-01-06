import 'package:flutter/material.dart';

class MyThemeModel extends ChangeNotifier {
  bool _isDark = true;

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