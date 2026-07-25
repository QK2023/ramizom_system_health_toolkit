import 'dart:convert';
import 'dart:io';

import 'ps_runner.dart';
import 'windows_paths.dart';

enum PrivacyFeature { microphone, camera, screenCapture }

class PrivacyProtectionState {
  final bool microphoneProtected;
  final bool cameraProtected;
  final bool screenCaptureProtected;
  final String? message;

  const PrivacyProtectionState({
    required this.microphoneProtected,
    required this.cameraProtected,
    required this.screenCaptureProtected,
    this.message,
  });

  factory PrivacyProtectionState.empty({String? message}) =>
      PrivacyProtectionState(
        microphoneProtected: false,
        cameraProtected: false,
        screenCaptureProtected: false,
        message: message,
      );

  bool get allProtected =>
      microphoneProtected && cameraProtected && screenCaptureProtected;

  bool valueOf(PrivacyFeature feature) {
    return switch (feature) {
      PrivacyFeature.microphone => microphoneProtected,
      PrivacyFeature.camera => cameraProtected,
      PrivacyFeature.screenCapture => screenCaptureProtected,
    };
  }
}

class PrivacyApplyResult {
  final bool success;
  final String message;
  final PrivacyProtectionState state;

  const PrivacyApplyResult({
    required this.success,
    required this.message,
    required this.state,
  });
}

class PrivacyProtection {
  PrivacyProtection._();

  static Future<PrivacyProtectionState> collect() async {
    final result = await PsRunner.runResult(_statusScript);
    if (!result.succeeded) {
      return PrivacyProtectionState.empty(
        message: result.timedOut ? '隐私策略读取超时' : '无法读取隐私策略',
      );
    }
    try {
      final json = jsonDecode(result.stdout) as Map<String, dynamic>;
      return PrivacyProtectionState(
        microphoneProtected: json['microphone'] == true,
        cameraProtected: json['camera'] == true,
        screenCaptureProtected: json['screenCapture'] == true,
      );
    } catch (_) {
      return PrivacyProtectionState.empty(message: '隐私策略格式无法解析');
    }
  }

  static Future<PrivacyApplyResult> setFeature(
    PrivacyFeature feature,
    bool enabled,
  ) {
    return apply(
      microphone: feature == PrivacyFeature.microphone ? enabled : null,
      camera: feature == PrivacyFeature.camera ? enabled : null,
      screenCapture: feature == PrivacyFeature.screenCapture ? enabled : null,
    );
  }

  static Future<PrivacyApplyResult> apply({
    bool? microphone,
    bool? camera,
    bool? screenCapture,
  }) async {
    if (!Platform.isWindows) {
      return PrivacyApplyResult(
        success: false,
        message: '仅支持 Windows',
        state: PrivacyProtectionState.empty(),
      );
    }

    final machineScript = _machinePolicyScript(
      microphone: microphone,
      camera: camera,
      screenCapture: screenCapture,
    );
    final elevated = await _runElevated(machineScript);
    if (!elevated) {
      return PrivacyApplyResult(
        success: false,
        message: '未获得管理员权限，设置没有更改',
        state: await collect(),
      );
    }

    final userResult = await PsRunner.runResult(
      _userPolicyScript(
        microphone: microphone,
        camera: camera,
        screenCapture: screenCapture,
      ),
    );
    final state = await collect();
    if (!userResult.succeeded) {
      return PrivacyApplyResult(
        success: false,
        message: '系统策略已写入，但当前用户隐私设置更新失败',
        state: state,
      );
    }
    final fullyApplied =
        (microphone == null || state.microphoneProtected == microphone) &&
        (camera == null || state.cameraProtected == camera) &&
        (screenCapture == null ||
            state.screenCaptureProtected == screenCapture);
    if (!fullyApplied) {
      return PrivacyApplyResult(
        success: false,
        message: '部分策略由 Windows 版本或组织策略管理，未能完全更改',
        state: state,
      );
    }
    return PrivacyApplyResult(
      success: true,
      message: '隐私保护策略已应用；正在运行的相关应用可能需要重启',
      state: state,
    );
  }

  static Future<bool> _runElevated(String script) async {
    try {
      final encoded = _encodePowerShell(script);
      final result = await Process.run(WindowsPaths.powershell, [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        "\$powershell = Join-Path \$env:SystemRoot "
            "'System32\\WindowsPowerShell\\v1.0\\powershell.exe'; "
            "\$process = Start-Process -FilePath \$powershell -Verb RunAs "
            "-WindowStyle Hidden -PassThru -Wait -ArgumentList "
            "'-NoLogo','-NoProfile','-NonInteractive','-EncodedCommand','$encoded'; "
            'exit \$process.ExitCode',
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static String _machinePolicyScript({
    bool? microphone,
    bool? camera,
    bool? screenCapture,
  }) {
    final script = StringBuffer(r'''
$ErrorActionPreference = 'Stop'
$appPrivacy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'
$gameDvr = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'
$backup = 'HKLM:\SOFTWARE\SystemHealthToolkit\PrivacyBackup'
New-Item -Path $appPrivacy -Force | Out-Null
New-Item -Path $gameDvr -Force | Out-Null
New-Item -Path $backup -Force | Out-Null

function Protect-Value($path, $name, $backupName, $value) {
  $saved = Get-ItemProperty -Path $backup -Name $backupName -ErrorAction SilentlyContinue
  if ($null -eq $saved) {
    try {
      $original = (Get-ItemProperty -Path $path -Name $name -ErrorAction Stop).$name
      Set-ItemProperty -Path $backup -Name $backupName -Type String -Value "VALUE:$original"
    } catch {
      Set-ItemProperty -Path $backup -Name $backupName -Type String -Value 'MISSING'
    }
  }
  Set-ItemProperty -Path $path -Name $name -Type DWord -Value $value
}

function Restore-Value($path, $name, $backupName, $protectedValue) {
  try {
    $marker = (Get-ItemProperty -Path $backup -Name $backupName -ErrorAction Stop).$backupName
  } catch {
    # 兼容旧版：旧版写入了保护值，但没有保存备份标记。
    try {
      $current = (Get-ItemProperty -Path $path -Name $name -ErrorAction Stop).$name
      if ([int]$current -eq [int]$protectedValue) {
        Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
      }
    } catch {}
    return
  }
  if ($marker -eq 'MISSING') {
    Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
  } elseif ($marker.StartsWith('VALUE:')) {
    Set-ItemProperty -Path $path -Name $name -Type DWord -Value ([int]$marker.Substring(6))
  }
  Remove-ItemProperty -Path $backup -Name $backupName -ErrorAction SilentlyContinue
}
''');
    if (microphone != null) {
      script.writeln(
        microphone
            ? "Protect-Value \$appPrivacy 'LetAppsAccessMicrophone' "
                  "'MachineMicrophone' 2"
            : "Restore-Value \$appPrivacy 'LetAppsAccessMicrophone' "
                  "'MachineMicrophone' 2",
      );
    }
    if (camera != null) {
      script.writeln(
        camera
            ? "Protect-Value \$appPrivacy 'LetAppsAccessCamera' "
                  "'MachineCamera' 2"
            : "Restore-Value \$appPrivacy 'LetAppsAccessCamera' "
                  "'MachineCamera' 2",
      );
    }
    if (screenCapture != null) {
      if (screenCapture) {
        script
          ..writeln(
            "Protect-Value \$appPrivacy "
            "'LetAppsAccessGraphicsCaptureProgrammatic' "
            "'MachineCaptureProgrammatic' 2",
          )
          ..writeln(
            "Protect-Value \$appPrivacy "
            "'LetAppsAccessGraphicsCaptureWithoutBorder' "
            "'MachineCaptureBorderless' 2",
          )
          ..writeln(
            "Protect-Value \$gameDvr 'AllowGameDVR' 'MachineGameDvr' 0",
          );
      } else {
        script
          ..writeln(
            "Restore-Value \$appPrivacy "
            "'LetAppsAccessGraphicsCaptureProgrammatic' "
            "'MachineCaptureProgrammatic' 2",
          )
          ..writeln(
            "Restore-Value \$appPrivacy "
            "'LetAppsAccessGraphicsCaptureWithoutBorder' "
            "'MachineCaptureBorderless' 2",
          )
          ..writeln(
            "Restore-Value \$gameDvr 'AllowGameDVR' 'MachineGameDvr' 0",
          );
      }
    }
    script.writeln("Write-Output 'OK'");
    return script.toString();
  }

  static String _userPolicyScript({
    bool? microphone,
    bool? camera,
    bool? screenCapture,
  }) {
    final script = StringBuffer(r'''
$ErrorActionPreference = 'Stop'
$backup = 'HKCU:\SOFTWARE\SystemHealthToolkit\PrivacyBackup'
New-Item -Path $backup -Force | Out-Null

function Protect-Value($path, $name, $backupName, $type, $value) {
  New-Item -Path $path -Force | Out-Null
  $saved = Get-ItemProperty -Path $backup -Name $backupName -ErrorAction SilentlyContinue
  if ($null -eq $saved) {
    try {
      $original = (Get-ItemProperty -Path $path -Name $name -ErrorAction Stop).$name
      Set-ItemProperty -Path $backup -Name $backupName -Type String -Value "VALUE:$original"
    } catch {
      Set-ItemProperty -Path $backup -Name $backupName -Type String -Value 'MISSING'
    }
  }
  Set-ItemProperty -Path $path -Name $name -Type $type -Value $value
}

function Restore-Value($path, $name, $backupName, $type, $protectedValue) {
  try {
    $marker = (Get-ItemProperty -Path $backup -Name $backupName -ErrorAction Stop).$backupName
  } catch {
    # 兼容旧版：仅撤销本应用旧版使用的精确保护值。
    try {
      $current = (Get-ItemProperty -Path $path -Name $name -ErrorAction Stop).$name
      if ([string]$current -eq [string]$protectedValue) {
        if ($type -eq 'String') {
          # 旧版没有记录原值。删除本应用写入的 Deny 比强制写入 Allow 更安全，
          # 这样 Windows 会回到未明确授权的状态。
          Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
        } else {
          Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
        }
      }
    } catch {}
    return
  }
  if ($marker -eq 'MISSING') {
    Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
  } elseif ($marker.StartsWith('VALUE:')) {
    $value = $marker.Substring(6)
    if ($type -eq 'DWord') { $value = [int]$value }
    Set-ItemProperty -Path $path -Name $name -Type $type -Value $value
  }
  Remove-ItemProperty -Path $backup -Name $backupName -ErrorAction SilentlyContinue
}
''');
    if (microphone != null) {
      script.writeln(
        _consentCommand('microphone', 'UserMicrophone', microphone),
      );
    }
    if (camera != null) {
      script.writeln(_consentCommand('webcam', 'UserCamera', camera));
    }
    if (screenCapture != null) {
      script
        ..writeln(r"$tabletPc = 'HKCU:\SOFTWARE\Policies\Microsoft\TabletPC'")
        ..writeln(r"$gameConfig = 'HKCU:\System\GameConfigStore'");
      if (screenCapture) {
        script
          ..writeln(
            "Protect-Value \$tabletPc 'DisableSnippingTool' "
            "'UserSnipping' 'DWord' 1",
          )
          ..writeln(
            "Protect-Value \$gameConfig 'GameDVR_Enabled' "
            "'UserGameDvr' 'DWord' 0",
          );
      } else {
        script
          ..writeln(
            "Restore-Value \$tabletPc 'DisableSnippingTool' "
            "'UserSnipping' 'DWord' 1",
          )
          ..writeln(
            "Restore-Value \$gameConfig 'GameDVR_Enabled' "
            "'UserGameDvr' 'DWord' 0",
          );
      }
    }
    script.writeln("Write-Output 'OK'");
    return script.toString();
  }

  static String _consentCommand(
    String capability,
    String backupName,
    bool enabled,
  ) {
    final path =
        r"'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\"
        'CapabilityAccessManager\\ConsentStore\\$capability\'';
    return enabled
        ? "Protect-Value $path 'Value' '$backupName' 'String' 'Deny'"
        : "Restore-Value $path 'Value' '$backupName' 'String' 'Deny'";
  }

  static String _encodePowerShell(String script) {
    final bytes = <int>[];
    for (final unit in script.codeUnits) {
      bytes
        ..add(unit & 0xff)
        ..add(unit >> 8);
    }
    return base64Encode(bytes);
  }

  static const _statusScript = r'''
$appPrivacy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'
$gameDvr = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'
$tabletPc = 'HKCU:\SOFTWARE\Policies\Microsoft\TabletPC'
$gameConfig = 'HKCU:\System\GameConfigStore'

function Read-Value($path, $name) {
  try { return (Get-ItemProperty -Path $path -Name $name -ErrorAction Stop).$name }
  catch { return $null }
}

$micPolicy = Read-Value $appPrivacy 'LetAppsAccessMicrophone'
$cameraPolicy = Read-Value $appPrivacy 'LetAppsAccessCamera'
$captureProgrammatic = Read-Value $appPrivacy 'LetAppsAccessGraphicsCaptureProgrammatic'
$captureBorderless = Read-Value $appPrivacy 'LetAppsAccessGraphicsCaptureWithoutBorder'
$allowGameDvr = Read-Value $gameDvr 'AllowGameDVR'
$disableSnipping = Read-Value $tabletPc 'DisableSnippingTool'
$userGameDvr = Read-Value $gameConfig 'GameDVR_Enabled'
$micConsent = Read-Value 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone' 'Value'
$cameraConsent = Read-Value 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam' 'Value'

[pscustomobject]@{
  microphone = ([int]$micPolicy -eq 2 -or [string]$micConsent -eq 'Deny')
  camera = ([int]$cameraPolicy -eq 2 -or [string]$cameraConsent -eq 'Deny')
  screenCapture = (
    [int]$captureProgrammatic -eq 2 -or
    [int]$captureBorderless -eq 2 -or
    ($null -ne $allowGameDvr -and [int]$allowGameDvr -eq 0) -or
    [int]$disableSnipping -eq 1 -or
    ($null -ne $userGameDvr -and [int]$userGameDvr -eq 0)
  )
} | ConvertTo-Json -Compress
''';
}
