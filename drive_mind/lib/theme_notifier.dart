import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;

  ThemeNotifier() {
    _loadTheme();
  }

  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool("is_dark_mode") ?? false;
    notifyListeners();
  }

  void toggleTheme() async {
    _isDark = !_isDark;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool("is_dark_mode", _isDark);

    notifyListeners();
  }
}
