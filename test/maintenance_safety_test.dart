import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_health_toolkit/localization/app_localizations.dart';
import 'package:system_health_toolkit/localization/security_strings.dart';
import 'package:system_health_toolkit/services/elevated_runner.dart';
import 'package:system_health_toolkit/services/system_maintenance.dart';

void main() {
  test('all new strings have matching English and Chinese translations', () {
    expect(securityEnglish.keys.toSet(), securityChinese.keys.toSet());
    for (final locale in [const Locale('en'), const Locale('zh', 'CN')]) {
      final l = AppLocalizations(locale);
      for (final id in SystemMaintenance.extraTools) {
        expect(l.tr(id), isNot(id));
        expect(l.tr('${id}Desc'), isNot('${id}Desc'));
      }
    }
  });

  test('PowerShell encoding preserves unicode without shell interpolation', () {
    const original = "Write-Output '麦克风 😀 `\$()'";
    final bytes = base64Decode(ElevatedRunner.encode(original));
    final units = <int>[];
    for (var i = 0; i < bytes.length; i += 2) {
      units.add(bytes[i] | (bytes[i + 1] << 8));
    }
    expect(String.fromCharCodes(units), original);
  });

  test('unknown maintenance actions cannot be executed', () async {
    expect(
      (await SystemMaintenance.runTool('cmd.exe /c whoami')).success,
      isFalse,
    );
  });
}
