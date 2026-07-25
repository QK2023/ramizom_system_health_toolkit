import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/quick_jump.dart';

/// 设置页面：主题模式、主题色、刷新间隔，持久化保存
class SettingsPage extends StatefulWidget {
  final AppSettings settings;
  const SettingsPage({super.key, required this.settings});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _seedColors = <Color>[
    Colors.green,
    Colors.teal,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.pink,
    Colors.red,
    Colors.orange,
  ];

  static const _refreshOptions = AppSettings.supportedRefreshIntervals;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_settingsChanged);
  }

  void _settingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.settings.removeListener(_settingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.settings;
    final l = context.l10n;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 外观
        _SectionTitle(title: l.tr('appearance')),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: Text(l.tr('themeMode')),
                subtitle: Text(_themeModeLabel(context, s.themeMode)),
                trailing: DropdownButton<AppThemeMode>(
                  value: s.themeMode,
                  onChanged: (v) {
                    if (v != null) s.setThemeMode(v);
                  },
                  items: [
                    DropdownMenuItem(
                      value: AppThemeMode.system,
                      child: Text(l.tr('followSystem')),
                    ),
                    DropdownMenuItem(
                      value: AppThemeMode.light,
                      child: Text(l.tr('light')),
                    ),
                    DropdownMenuItem(
                      value: AppThemeMode.dark,
                      child: Text(l.tr('dark')),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.palette),
                title: Text(l.tr('themeColor')),
                subtitle: Text(l.tr('chooseThemeColor')),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _seedColors.map((c) {
                    final selected = s.seedColor.toARGB32() == c.toARGB32();
                    return GestureDetector(
                      onTap: () => s.setSeedColor(c),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(
                                  color: theme.colorScheme.onSurface,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionTitle(title: l.tr('language')),
        Card(
          child: ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.tr('appLanguage')),
            subtitle: Text(_languageLabel(context, s.language)),
            trailing: DropdownButton<AppLanguage>(
              value: s.language,
              onChanged: (value) {
                if (value != null) s.setLanguage(value);
              },
              items: [
                DropdownMenuItem(
                  value: AppLanguage.system,
                  child: Text(l.tr('followSystem')),
                ),
                DropdownMenuItem(
                  value: AppLanguage.simplifiedChinese,
                  child: Text(l.tr('simplifiedChinese')),
                ),
                DropdownMenuItem(
                  value: AppLanguage.english,
                  child: Text(l.tr('english')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 数据刷新
        _SectionTitle(title: l.tr('dataRefresh')),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.update),
                title: Text(l.tr('homeRefreshRate')),
                subtitle: Text(
                  l.tr('everySeconds', {'seconds': s.refreshIntervalSec}),
                ),
                trailing: DropdownButton<int>(
                  value: s.refreshIntervalSec,
                  onChanged: (v) {
                    if (v != null) s.setRefreshInterval(v);
                  },
                  items: _refreshOptions
                      .map(
                        (sec) => DropdownMenuItem(
                          value: sec,
                          child: Text(l.tr('seconds', {'seconds': sec})),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // 关于
        _SectionTitle(title: l.tr('about')),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l.tr('applicationName')),
                subtitle: Text(l.tr('appName')),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.code),
                title: Text(l.tr('version')),
                subtitle: const Text('5.0.0.0'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(l.tr('developer')),
                subtitle: Text(l.tr('developerName')),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(l.tr('developmentDate')),
                subtitle: Text(l.tr('developmentDateValue')),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l.tr('website')),
                subtitle: const Text('Ramizom.com'),
                trailing: TextButton.icon(
                  onPressed: () => QuickJump.launchUrl('https://ramizom.com'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(l.tr('visitWebsite')),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(l.tr('privacyPolicy')),
                trailing: OutlinedButton.icon(
                  onPressed: () =>
                      QuickJump.launchUrl('https://ramizom.com/privacy'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(l.tr('openPrivacyPolicy')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _themeModeLabel(BuildContext context, AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return context.l10n.tr('followSystem');
      case AppThemeMode.light:
        return context.l10n.tr('light');
      case AppThemeMode.dark:
        return context.l10n.tr('dark');
    }
  }

  String _languageLabel(BuildContext context, AppLanguage language) {
    return switch (language) {
      AppLanguage.system => context.l10n.tr('followSystem'),
      AppLanguage.simplifiedChinese => context.l10n.tr('simplifiedChinese'),
      AppLanguage.english => context.l10n.tr('english'),
    };
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
