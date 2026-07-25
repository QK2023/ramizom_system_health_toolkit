import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'localization/app_localizations.dart';
import 'pages/disk_health_page.dart';
import 'pages/home_dashboard_page.dart';
import 'pages/power_page.dart';
import 'pages/recommendations_page.dart';
import 'pages/security_page.dart';
import 'pages/settings_page.dart';

import 'services/app_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  runApp(SystemHealthToolkitApp(settings: settings));
}

class SystemHealthToolkitApp extends StatefulWidget {
  final AppSettings settings;
  const SystemHealthToolkitApp({super.key, required this.settings});

  @override
  State<SystemHealthToolkitApp> createState() => _SystemHealthToolkitAppState();
}

class _SystemHealthToolkitAppState extends State<SystemHealthToolkitApp>
    with WidgetsBindingObserver {
  late Locale _systemLocale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _systemLocale = AppLocalizations.resolveSystemLocales(
      WidgetsBinding.instance.platformDispatcher.locales,
    );
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final locale = AppLocalizations.resolveSystemLocales(locales);
    if (locale == _systemLocale) return;
    setState(() => _systemLocale = locale);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        return MaterialApp(
          onGenerateTitle: (context) => context.l10n.tr('appName'),
          themeMode: widget.settings.materialThemeMode,
          locale: widget.settings.explicitLocale ?? _systemLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: widget.settings.seedColor,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: widget.settings.seedColor,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: ShellPage(settings: widget.settings),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

/// 横屏使用左侧导航栏，竖屏使用底部导航与“其他”菜单。
class ShellPage extends StatefulWidget {
  final AppSettings settings;
  const ShellPage({super.key, required this.settings});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  static const _appChannel = MethodChannel('system_health_toolkit/app');
  int _selectedIndex = 0;
  late final List<Widget?> _pages;
  String? _lastWindowTitle;

  List<NavigationRailDestination> _destinations(BuildContext context) => [
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: Text(context.l10n.tr('home')),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.shield_outlined),
      selectedIcon: Icon(Icons.shield),
      label: Text(context.l10n.tr('privacySecurity')),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.battery_6_bar_outlined),
      selectedIcon: Icon(Icons.battery_6_bar),
      label: Text(context.l10n.tr('powerPerformance')),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.storage_outlined),
      selectedIcon: Icon(Icons.storage),
      label: Text(context.l10n.tr('diskHealth')),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.tips_and_updates_outlined),
      selectedIcon: Icon(Icons.tips_and_updates),
      label: Text(context.l10n.tr('recommendations')),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text(context.l10n.tr('settings')),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pages = List<Widget?>.filled(6, null);
    _pages[0] = HomeDashboardPage(settings: widget.settings);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final title = context.l10n.tr('appName');
    if (title == _lastWindowTitle) return;
    _lastWindowTitle = title;
    _appChannel.invokeMethod<void>('setWindowTitle', title).catchError((_) {});
  }

  Widget _pageFor(int index) {
    return switch (index) {
      0 => HomeDashboardPage(settings: widget.settings),
      1 => const SecurityPage(),
      2 => const PowerPage(),
      3 => const DiskHealthPage(),
      4 => const RecommendationsPage(),
      5 => SettingsPage(settings: widget.settings),
      _ => const SizedBox.shrink(),
    };
  }

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
      _pages[index] ??= _pageFor(index);
    });
  }

  Future<void> _showOtherPages() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              selected: _selectedIndex == 3,
              title: Text(context.l10n.tr('diskHealth')),
              onTap: () => Navigator.pop(context, 3),
            ),
            ListTile(
              leading: const Icon(Icons.tips_and_updates_outlined),
              selected: _selectedIndex == 4,
              title: Text(context.l10n.tr('recommendations')),
              onTap: () => Navigator.pop(context, 4),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              selected: _selectedIndex == 5,
              title: Text(context.l10n.tr('settings')),
              onTap: () => Navigator.pop(context, 5),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && mounted) _selectPage(selected);
  }

  Widget _content() {
    return IndexedStack(
      index: _selectedIndex,
      children: _pages
          .map((page) => page ?? const SizedBox.shrink())
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final portrait = constraints.maxHeight > constraints.maxWidth;
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.tr('appName'))),
          body: portrait
              ? _content()
              : Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _selectPage,
                      labelType: NavigationRailLabelType.all,
                      destinations: _destinations(context),
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(child: _content()),
                  ],
                ),
          bottomNavigationBar: portrait
              ? NavigationBar(
                  selectedIndex: _selectedIndex <= 2 ? _selectedIndex : 3,
                  onDestinationSelected: (index) {
                    if (index == 3) {
                      _showOtherPages();
                    } else {
                      _selectPage(index);
                    }
                  },
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(Icons.home),
                      label: context.l10n.tr('home'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.shield_outlined),
                      selectedIcon: const Icon(Icons.shield),
                      label: context.l10n.tr('security'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.battery_6_bar_outlined),
                      selectedIcon: const Icon(Icons.battery_6_bar),
                      label: context.l10n.tr('battery'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.more_horiz),
                      label: context.l10n.tr('other'),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}
