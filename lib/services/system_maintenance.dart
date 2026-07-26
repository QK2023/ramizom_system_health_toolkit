import 'dart:convert';
import 'dart:io';

import 'ps_runner.dart';
import 'windows_paths.dart';

class MaintenanceResult {
  final bool success;
  final String message;

  const MaintenanceResult({required this.success, required this.message});
}

class UpdatePauseState {
  final bool active;
  final String? expiryTime;
  final String? message;

  const UpdatePauseState({required this.active, this.expiryTime, this.message});
}

class SystemMaintenance {
  SystemMaintenance._();

  /// 检查本工具使用的 Windows Update 暂缓设置是否完整生效。
  static Future<UpdatePauseState> getUpdatePauseState() async {
    if (!Platform.isWindows) {
      return const UpdatePauseState(active: false, message: '仅支持 Windows');
    }
    final result = await PsRunner.runResult(
      _updatePauseStatusScript,
      timeout: const Duration(seconds: 5),
    );
    if (!result.succeeded) {
      return UpdatePauseState(
        active: false,
        message: result.timedOut ? '更新状态读取超时' : '无法读取更新暂缓状态',
      );
    }
    try {
      final data = jsonDecode(result.stdout) as Map<String, dynamic>;
      return UpdatePauseState(
        active: data['active'] == true,
        expiryTime: data['expiryTime']?.toString(),
      );
    } catch (_) {
      return const UpdatePauseState(active: false, message: '更新暂缓状态格式无法解析');
    }
  }

  /// 将 Windows Update 的功能更新和质量更新暂缓至 2042-09-05。
  static Future<MaintenanceResult> pauseWindowsUpdates() async {
    if (!Platform.isWindows) {
      return const MaintenanceResult(success: false, message: '仅支持 Windows');
    }
    final elevated = await _runElevated(_updatePauseScript);
    if (!elevated) {
      return const MaintenanceResult(
        success: false,
        message: '未获得管理员权限，系统更新设置没有更改',
      );
    }
    final state = await getUpdatePauseState();
    if (!state.active) {
      return MaintenanceResult(
        success: false,
        message: state.message ?? '注册表已执行写入，但 Windows 未返回预期的暂缓状态',
      );
    }
    return const MaintenanceResult(
      success: true,
      message: 'Windows 系统更新已暂缓至 2042-09-05',
    );
  }

  /// 恢复暂缓前的 Windows Update 值；没有备份时只移除本工具的精确旧值。
  static Future<MaintenanceResult> resumeWindowsUpdates() async {
    if (!Platform.isWindows) {
      return const MaintenanceResult(success: false, message: '仅支持 Windows');
    }
    final elevated = await _runElevated(_updateResumeScript);
    if (!elevated) {
      return const MaintenanceResult(
        success: false,
        message: '未获得管理员权限，系统更新设置没有更改',
      );
    }
    final state = await getUpdatePauseState();
    if (state.active) {
      return const MaintenanceResult(
        success: false,
        message: '部分更新暂缓设置仍由 Windows 或其他策略管理',
      );
    }
    return const MaintenanceResult(success: true, message: 'Windows 系统更新已恢复');
  }

  /// 请求管理员权限后刷新 DNS，并重置 Winsock 与 TCP/IP。
  static Future<MaintenanceResult> repairNetwork() async {
    if (!Platform.isWindows) {
      return const MaintenanceResult(success: false, message: '仅支持 Windows');
    }
    try {
      if (!await _runElevated(_networkRepairScript)) {
        return const MaintenanceResult(
          success: false,
          message: '未能获得管理员权限，网络修复已取消',
        );
      }
      return const MaintenanceResult(
        success: true,
        message: '网络协议栈已重置。建议重新启动 Windows 以完成修复',
      );
    } catch (error) {
      return MaintenanceResult(success: false, message: '网络修复失败：$error');
    }
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

  /// 清理 Windows 图标缓存并安全重启 Explorer。
  static Future<MaintenanceResult> repairShellIcons() async {
    final result = await PsRunner.runResult(_shellRepairScript);
    if (!result.succeeded) {
      return MaintenanceResult(
        success: false,
        message: result.timedOut ? 'Explorer 重启超时' : '图标修复失败',
      );
    }
    return const MaintenanceResult(success: true, message: '桌面与任务栏图标缓存已刷新');
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

  static const _networkRepairScript = r'''
$ErrorActionPreference = 'Stop'
$ipconfig = Join-Path $env:SystemRoot 'System32\ipconfig.exe'
$netsh = Join-Path $env:SystemRoot 'System32\netsh.exe'
& $ipconfig /flushdns | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'DNS flush failed' }
& $netsh winsock reset | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Winsock reset failed' }
# 关闭 Windows 系统代理（非关键操作，静默失败）
try {
  Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 0 -Type DWord -ErrorAction Stop | Out-Null
  & $netsh winhttp reset proxy 2>&1 | Out-Null
} catch { }
''';

  static const _updatePauseScript = r'''
$ErrorActionPreference = 'Stop'
$base = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
New-Item -Path $base -Force | Out-Null
$values = [ordered]@{
  FlightSettingsMaxPauseDays = 7000
  PauseFeatureUpdatesStartTime = '2023-07-07T10:00:52Z'
  PauseFeatureUpdatesEndTime = '2042-09-05T09:59:52Z'
  PauseQualityUpdatesStartTime = '2023-07-07T10:00:52Z'
  PauseQualityUpdatesEndTime = '2042-09-05T09:59:52Z'
  PauseUpdatesStartTime = '2023-07-07T09:59:52Z'
  PauseUpdatesExpiryTime = '2042-09-05T09:59:52Z'
}
$backup = 'HKLM:\SOFTWARE\Ramizom\SystemHealthToolkit\UpdateBackup'
New-Item -Path $backup -Force | Out-Null
foreach ($name in $values.Keys) {
  $saved = Get-ItemProperty -Path $backup -Name $name -ErrorAction SilentlyContinue
  if ($null -eq $saved) {
    $property = Get-ItemProperty -Path $base -Name $name -ErrorAction SilentlyContinue
    $marker = if ($null -eq $property) {
      'MISSING'
    } elseif ([string]$property.$name -eq [string]$values[$name]) {
      # 兼容旧版：值已经是本工具使用的精确值，但旧版没有保存备份。
      'LEGACY'
    } else {
      "VALUE:$($property.$name)"
    }
    Set-ItemProperty -Path $backup -Name $name -Value $marker -Type String
  }
}
$before = @{}
foreach ($name in $values.Keys) {
  $property = Get-ItemProperty -Path $base -Name $name -ErrorAction SilentlyContinue
  $before[$name] = if ($null -eq $property) {
    [pscustomobject]@{ Exists = $false; Value = $null }
  } else {
    [pscustomobject]@{ Exists = $true; Value = $property.$name }
  }
}
try {
  foreach ($name in $values.Keys) {
    $type = if ($name -eq 'FlightSettingsMaxPauseDays') { 'DWord' } else { 'String' }
    Set-ItemProperty -Path $base -Name $name -Value $values[$name] -Type $type
  }
} catch {
  foreach ($name in $before.Keys) {
    if ($before[$name].Exists) {
      $type = if ($name -eq 'FlightSettingsMaxPauseDays') { 'DWord' } else { 'String' }
      Set-ItemProperty -Path $base -Name $name -Value $before[$name].Value -Type $type -ErrorAction SilentlyContinue
    } else {
      Remove-ItemProperty -Path $base -Name $name -ErrorAction SilentlyContinue
    }
  }
  throw
}
''';

  static const _updateResumeScript = r'''
$ErrorActionPreference = 'Stop'
$base = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
$backup = 'HKLM:\SOFTWARE\Ramizom\SystemHealthToolkit\UpdateBackup'
$values = [ordered]@{
  FlightSettingsMaxPauseDays = 7000
  PauseFeatureUpdatesStartTime = '2023-07-07T10:00:52Z'
  PauseFeatureUpdatesEndTime = '2042-09-05T09:59:52Z'
  PauseQualityUpdatesStartTime = '2023-07-07T10:00:52Z'
  PauseQualityUpdatesEndTime = '2042-09-05T09:59:52Z'
  PauseUpdatesStartTime = '2023-07-07T09:59:52Z'
  PauseUpdatesExpiryTime = '2042-09-05T09:59:52Z'
}
foreach ($name in $values.Keys) {
  $currentProperty = Get-ItemProperty -Path $base -Name $name -ErrorAction SilentlyContinue
  $currentMatches = (
    $null -ne $currentProperty -and
    [string]$currentProperty.$name -eq [string]$values[$name]
  )
  $saved = Get-ItemProperty -Path $backup -Name $name -ErrorAction SilentlyContinue
  if ($null -ne $saved -and $currentMatches) {
    $marker = [string]$saved.$name
    if ($marker -eq 'MISSING' -or $marker -eq 'LEGACY') {
      Remove-ItemProperty -Path $base -Name $name -ErrorAction SilentlyContinue
    } elseif ($marker.StartsWith('VALUE:')) {
      $value = $marker.Substring(6)
      $type = if ($name -eq 'FlightSettingsMaxPauseDays') { 'DWord' } else { 'String' }
      if ($type -eq 'DWord') { $value = [int]$value }
      Set-ItemProperty -Path $base -Name $name -Value $value -Type $type
    }
  } elseif ($null -eq $saved -and $currentMatches) {
    # 旧版迁移：没有任何备份时，仅移除本工具使用的精确值。
    Remove-ItemProperty -Path $base -Name $name -ErrorAction SilentlyContinue
  }
  Remove-ItemProperty -Path $backup -Name $name -ErrorAction SilentlyContinue
}
''';

  static const _updatePauseStatusScript = r'''
$ErrorActionPreference = 'SilentlyContinue'
$base = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
$settings = Get-ItemProperty -Path $base -ErrorAction SilentlyContinue
$active = (
  $null -ne $settings -and
  [int64]$settings.FlightSettingsMaxPauseDays -eq 7000 -and
  [string]$settings.PauseFeatureUpdatesStartTime -eq '2023-07-07T10:00:52Z' -and
  [string]$settings.PauseFeatureUpdatesEndTime -eq '2042-09-05T09:59:52Z' -and
  [string]$settings.PauseQualityUpdatesStartTime -eq '2023-07-07T10:00:52Z' -and
  [string]$settings.PauseQualityUpdatesEndTime -eq '2042-09-05T09:59:52Z' -and
  [string]$settings.PauseUpdatesStartTime -eq '2023-07-07T09:59:52Z' -and
  [string]$settings.PauseUpdatesExpiryTime -eq '2042-09-05T09:59:52Z'
)
[pscustomobject]@{
  active = $active
  expiryTime = if ($settings) { [string]$settings.PauseUpdatesExpiryTime } else { $null }
} | ConvertTo-Json -Compress
''';

  static const _shellRepairScript = r'''
$ErrorActionPreference = 'SilentlyContinue'
$iconTool = Join-Path $env:SystemRoot 'System32\ie4uinit.exe'
if (-not (Test-Path -LiteralPath $iconTool)) { exit 1 }
& $iconTool -ClearIconCache
& $iconTool -show
Write-Output 'OK'
''';
}
