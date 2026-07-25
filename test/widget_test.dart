// Widget tests for the System Health Toolkit app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:system_health_toolkit/main.dart';
import 'package:system_health_toolkit/localization/app_localizations.dart';
import 'package:system_health_toolkit/services/app_settings.dart';

Future<AppSettings> _initSettings() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  await settings.setLanguage(AppLanguage.simplifiedChinese);
  return settings;
}

void main() {
  testWidgets('App renders title and default home section', (
    WidgetTester tester,
  ) async {
    final settings = await _initSettings();
    await tester.pumpWidget(SystemHealthToolkitApp(settings: settings));
    await tester.pump();

    expect(find.text('Ramizom System Health Toolkit'), findsOneWidget);
    // 主页仪表板标题
    expect(find.text('设备概览'), findsOneWidget);
  });

  testWidgets('Selecting a navigation destination switches content', (
    WidgetTester tester,
  ) async {
    final settings = await _initSettings();
    await tester.pumpWidget(SystemHealthToolkitApp(settings: settings));
    await tester.pump();

    // 未访问的功能页不会在启动阶段初始化和采集系统数据。
    expect(find.text('账户信息'), findsNothing);

    // 点击“隐私与安全”导航项
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pumpAndSettle();

    expect(find.text('隐私保护'), findsOneWidget);
    expect(find.text('关闭麦克风访问'), findsOneWidget);
    expect(find.text('关闭录屏和截图'), findsOneWidget);
    expect(find.text('关闭摄像头访问'), findsOneWidget);
    expect(find.text('Windows Defender 防病毒'), findsNothing);
    expect(find.text('设备概览'), findsNothing);
  });

  testWidgets('Settings page allows changing theme mode', (
    WidgetTester tester,
  ) async {
    final settings = await _initSettings();
    await tester.pumpWidget(SystemHealthToolkitApp(settings: settings));
    await tester.pump();

    // 切换到设置页
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('外观'), findsOneWidget);
    expect(find.text('主题模式'), findsWidgets);
    expect(find.text('应用语言'), findsOneWidget);
  });

  testWidgets('Recommendations opens without a lifecycle exception', (
    WidgetTester tester,
  ) async {
    final settings = await _initSettings();
    await tester.pumpWidget(SystemHealthToolkitApp(settings: settings));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.tips_and_updates_outlined));
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('所有工具'), findsOneWidget);
    expect(find.text('暂缓系统更新'), findsWidgets);
  });

  testWidgets('Follow system tracks Windows locale changes', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('zh', 'CN'),
    ];
    final settings = await _initSettings();
    await settings.setLanguage(AppLanguage.system);

    await tester.pumpWidget(SystemHealthToolkitApp(settings: settings));
    await tester.pumpAndSettle();
    expect(find.text('设备概览'), findsOneWidget);

    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('en', 'US'),
    ];
    await tester.pumpAndSettle();
    expect(find.text('Device overview'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('English language setting updates the interface', (
    WidgetTester tester,
  ) async {
    final settings = await _initSettings();
    await settings.setLanguage(AppLanguage.english);
    await tester.pumpWidget(SystemHealthToolkitApp(settings: settings));
    await tester.pumpAndSettle();

    expect(find.text('Ramizom System Health Toolkit'), findsOneWidget);
    expect(find.text('Device overview'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Portrait layout uses bottom navigation and other menu', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = await _initSettings();
    await tester.pumpWidget(SystemHealthToolkitApp(settings: settings));
    await tester.pump();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.battery_6_bar_outlined), findsOneWidget);

    await tester.tap(find.text('其他'));
    await tester.pumpAndSettle();

    expect(find.text('磁盘健康'), findsOneWidget);
    expect(find.text('推荐设置'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  test('Invalid persisted settings fall back to safe defaults', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'themeMode': 999,
      'refreshInterval': 999,
      'language': 999,
    });

    final settings = AppSettings();
    await settings.load();

    expect(settings.themeMode, AppThemeMode.system);
    expect(settings.refreshIntervalSec, 3);
    expect(settings.language, AppLanguage.system);
  });

  test('System language uses Chinese only for Simplified Chinese', () {
    expect(
      AppLocalizations.resolveSystemLocales(const [Locale('zh', 'CN')]),
      const Locale('zh', 'CN'),
    );
    expect(
      AppLocalizations.resolveSystemLocales(const [
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ]),
      const Locale('zh', 'CN'),
    );
    expect(
      AppLocalizations.resolveSystemLocales(const [Locale('zh', 'TW')]),
      const Locale('en'),
    );
    expect(
      AppLocalizations.resolveSystemLocales(const [Locale('zh')]),
      const Locale('en'),
    );
    expect(
      AppLocalizations.resolveSystemLocales(const [Locale('en', 'US')]),
      const Locale('en'),
    );
  });
}
