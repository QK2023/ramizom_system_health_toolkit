import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式
enum AppThemeMode { system, light, dark }

enum AppLanguage { system, simplifiedChinese, english }

/// 应用设置：持久化主题模式、主题色、刷新间隔。
class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._();
  factory AppSettings() => _instance;
  AppSettings._();

  static const _kThemeMode = 'themeMode';
  static const _kSeedColor = 'seedColor';
  static const _kRefreshInterval = 'refreshInterval';
  static const _kLanguage = 'language';
  static const supportedRefreshIntervals = [2, 3, 5, 10, 30];

  AppThemeMode _themeMode = AppThemeMode.system;
  Color _seedColor = Colors.teal;
  int _refreshIntervalSec = 3;
  AppLanguage _language = AppLanguage.system;

  AppThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  int get refreshIntervalSec => _refreshIntervalSec;
  AppLanguage get language => _language;

  Locale? get explicitLocale => switch (_language) {
    AppLanguage.system => null,
    AppLanguage.simplifiedChinese => const Locale('zh', 'CN'),
    AppLanguage.english => const Locale('en'),
  };

  ThemeMode get materialThemeMode {
    switch (_themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_kThemeMode) ?? 0;
    _themeMode = modeIndex >= 0 && modeIndex < AppThemeMode.values.length
        ? AppThemeMode.values[modeIndex]
        : AppThemeMode.system;
    final colorValue = prefs.getInt(_kSeedColor);
    if (colorValue != null) {
      _seedColor = Color(colorValue);
    }
    final interval = prefs.getInt(_kRefreshInterval) ?? 3;
    _refreshIntervalSec = supportedRefreshIntervals.contains(interval)
        ? interval
        : 3;
    final languageIndex = prefs.getInt(_kLanguage) ?? 0;
    _language = languageIndex >= 0 && languageIndex < AppLanguage.values.length
        ? AppLanguage.values[languageIndex]
        : AppLanguage.system;
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeMode, mode.index);
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSeedColor, color.toARGB32());
  }

  Future<void> setRefreshInterval(int seconds) async {
    if (!supportedRefreshIntervals.contains(seconds)) return;
    _refreshIntervalSec = seconds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kRefreshInterval, seconds);
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLanguage, language.index);
  }
}
