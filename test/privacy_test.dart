import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_health_toolkit/localization/app_localizations.dart';
import 'package:system_health_toolkit/localization/security_strings.dart';
import 'package:system_health_toolkit/services/device_privacy.dart';
import 'package:system_health_toolkit/services/elevated_runner.dart';
import 'package:system_health_toolkit/services/privacy_protection.dart';
import 'package:system_health_toolkit/services/system_maintenance.dart';
import 'package:system_health_toolkit/services/windows_paths.dart';

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

  test(
    'device protection filters output/scanners and restores only owned devices',
    () async {
      final fixture = File(
        'test/fixtures/privacy_devices.ps1',
      ).readAsStringSync();
      final result = await Process.run(WindowsPaths.powershell, [
        '-NoProfile',
        '-NonInteractive',
        '-EncodedCommand',
        ElevatedRunner.encode(
          "\$ErrorActionPreference = 'Stop'\n${DevicePrivacy.functions}\n$fixture",
        ),
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect('${result.stdout}', contains('PASS'));
    },
    skip: !Platform.isWindows,
  );

  test('unknown maintenance actions cannot be executed', () async {
    expect(
      (await SystemMaintenance.runTool('cmd.exe /c whoami')).success,
      isFalse,
    );
  });

  test(
    'restoring privacy preserves unowned and subsequently changed policies',
    () async {
      final fixture = File(
        'test/fixtures/privacy_registry.ps1',
      ).readAsStringSync();
      for (final machine in [true, false]) {
        final script = machine
            ? PrivacyProtection.machinePolicyScript()
            : PrivacyProtection.userPolicyScript();
        final type = machine ? '' : "'DWord' ";
        final assertions =
            '''
Set-ItemProperty 'test' 'Policy' -Type DWord -Value 2
Restore-Value 'test' 'Policy' 'Saved' ${type}2
if ((Get-ItemProperty 'test' 'Policy').Policy -ne 2) { throw 'Removed unowned policy' }
Set-ItemProperty 'test' 'Policy' -Type DWord -Value 1
Protect-Value 'test' 'Policy' 'Saved' ${type}2
Protect-Value 'test' 'Policy' 'Saved' ${type}2
Restore-Value 'test' 'Policy' 'Saved' ${type}2
if ((Get-ItemProperty 'test' 'Policy').Policy -ne 1) { throw 'Lost original policy' }
Protect-Value 'test' 'Policy' 'Saved' ${type}2
Set-ItemProperty 'test' 'Policy' -Type DWord -Value 3
Restore-Value 'test' 'Policy' 'Saved' ${type}2
if ((Get-ItemProperty 'test' 'Policy').Policy -ne 3) { throw 'Overwrote administrator change' }
Write-Output 'PASS'
''';
        final result = await Process.run(WindowsPaths.powershell, [
          '-NoProfile',
          '-NonInteractive',
          '-EncodedCommand',
          ElevatedRunner.encode('$fixture\n$script\n$assertions'),
        ]);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect('${result.stdout}', contains('PASS'));
      }
    },
    skip: !Platform.isWindows,
  );

  test(
    'all privacy apply/restore scripts parse without executing them',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ramizom-parser-',
      );
      final source = File('${directory.path}/source.ps1');
      addTearDown(() async {
        if (await source.exists()) await source.delete();
        await directory.delete();
      });
      for (final enabled in [true, false]) {
        for (final script in [
          PrivacyProtection.machinePolicyScript(
            microphone: enabled,
            camera: enabled,
            screenCapture: enabled,
          ),
          PrivacyProtection.userPolicyScript(
            microphone: enabled,
            camera: enabled,
            screenCapture: enabled,
          ),
        ]) {
          expect(ElevatedRunner.encode(script).length, lessThan(30000));
          await source.writeAsString(script);
          final sourcePath = source.path.replaceAll("'", "''");
          final parser =
              '''
\$tokens = \$null; \$errors = \$null
[Management.Automation.Language.Parser]::ParseFile('$sourcePath', [ref]\$tokens, [ref]\$errors) | Out-Null
if (\$errors.Count) { \$errors | Out-String | Write-Output; exit 1 }
''';
          final result = await Process.run(WindowsPaths.powershell, [
            '-NoProfile',
            '-NonInteractive',
            '-EncodedCommand',
            ElevatedRunner.encode(parser),
          ]);
          expect(
            result.exitCode,
            0,
            reason: '${result.stdout}\n${result.stderr}',
          );
        }
      }
    },
    skip: !Platform.isWindows,
  );
}
