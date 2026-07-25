import 'dart:convert';

import 'ps_runner.dart';

class SecuritySnapshot {
  final bool? antivirusEnabled;
  final bool? realtimeProtection;
  final bool? firewallEnabled;
  final bool? uacEnabled;
  final String bitlockerStatus;
  final String lastUpdate;
  final int? pendingUpdates;
  final bool? isAdmin;
  final String accountName;
  final String signatureAge;
  final String? message;

  const SecuritySnapshot({
    required this.antivirusEnabled,
    required this.realtimeProtection,
    required this.firewallEnabled,
    required this.uacEnabled,
    required this.bitlockerStatus,
    required this.lastUpdate,
    required this.pendingUpdates,
    required this.isAdmin,
    required this.accountName,
    required this.signatureAge,
    this.message,
  });

  factory SecuritySnapshot.empty({String? message}) => SecuritySnapshot(
    antivirusEnabled: null,
    realtimeProtection: null,
    firewallEnabled: null,
    uacEnabled: null,
    bitlockerStatus: '未知',
    lastUpdate: '未知',
    pendingUpdates: null,
    isAdmin: null,
    accountName: '',
    signatureAge: '未知',
    message: message,
  );
}

class SecurityMonitor {
  SecurityMonitor._();

  static const _cacheDuration = Duration(seconds: 15);
  static SecuritySnapshot? _cached;
  static DateTime? _cachedAt;
  static Future<SecuritySnapshot>? _inFlight;

  static Future<SecuritySnapshot> collect({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _cached != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _cacheDuration) {
      return Future.value(_cached);
    }
    if (_inFlight != null) return _inFlight!;

    final future = _collectNow();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  static Future<SecuritySnapshot> _collectNow() async {
    final result = await PsRunner.runResult(_script);
    if (!result.succeeded) {
      return _cached ??
          SecuritySnapshot.empty(
            message: result.timedOut ? '安全状态读取超时' : '安全状态暂时不可用',
          );
    }
    try {
      final json = jsonDecode(result.stdout) as Map<String, dynamic>;
      final snapshot = SecuritySnapshot(
        antivirusEnabled: _bool(json['antivirusEnabled']),
        realtimeProtection: _bool(json['realtimeProtection']),
        firewallEnabled: _bool(json['firewallEnabled']),
        uacEnabled: _bool(json['uacEnabled']),
        bitlockerStatus: _bitlockerText('${json['bitlockerStatus'] ?? ''}'),
        lastUpdate: _text(json['lastUpdate'], '未知'),
        // 快速、无副作用的系统接口不能可靠返回待安装数量。
        pendingUpdates: null,
        isAdmin: _bool(json['isAdmin']),
        accountName: _text(json['accountName'], '未知'),
        signatureAge: _signatureAge('${json['signatureUpdated'] ?? ''}'),
      );
      _cached = snapshot;
      _cachedAt = DateTime.now();
      return snapshot;
    } catch (e) {
      PsRunner.debugPrint('SecurityMonitor parse error: $e');
      return _cached ?? SecuritySnapshot.empty(message: '安全状态格式无法解析');
    }
  }

  static bool? _bool(dynamic value) {
    if (value is bool) return value;
    if (value == null) return null;
    final text = value.toString().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return null;
  }

  static String _text(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _bitlockerText(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'on':
      case '1':
        return '已加密';
      case 'off':
      case '0':
        return '未加密';
      case 'encryptioninprogress':
        return '加密中';
      default:
        return '未知';
    }
  }

  static String _signatureAge(String raw) {
    final updated = DateTime.tryParse(raw)?.toLocal();
    if (updated == null) return '未知';
    final days = DateTime.now().difference(updated).inDays;
    if (days <= 0) return '今天';
    return '$days 天前';
  }

  static const _script = r'''
$ErrorActionPreference = 'SilentlyContinue'

$mp = $null
try { $mp = Get-MpComputerStatus -ErrorAction Stop } catch {}

$firewallEnabled = $null
try {
  $profiles = @(Get-NetFirewallProfile -ErrorAction Stop)
  if ($profiles.Count -gt 0) {
    $firewallEnabled = @($profiles | Where-Object { $_.Enabled -eq $true }).Count -gt 0
  }
} catch {}

$uacEnabled = $null
try {
  $uac = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -ErrorAction Stop).EnableLUA
  $uacEnabled = ([int]$uac -eq 1)
} catch {}

# Get-BitLockerVolume 在部分机器上需要 5 秒以上且常要求管理员权限。
# 首屏不执行该阻塞命令；无法快速可靠检测时明确返回未知。
$bitlocker = ''

$lastUpdate = ''
try {
  $install = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Install' -ErrorAction Stop
  if ($install.LastSuccessTime) {
    $lastUpdate = ([datetime]$install.LastSuccessTime).ToString('yyyy-MM-dd')
  }
} catch {}

$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
$isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

[pscustomobject]@{
  antivirusEnabled = if ($mp) { [bool]$mp.AntivirusEnabled } else { $null }
  realtimeProtection = if ($mp) { [bool]$mp.RealTimeProtectionEnabled } else { $null }
  signatureUpdated = if ($mp.AntivirusSignatureLastUpdated) { $mp.AntivirusSignatureLastUpdated.ToString('o') } else { '' }
  firewallEnabled = $firewallEnabled
  uacEnabled = $uacEnabled
  bitlockerStatus = $bitlocker
  lastUpdate = $lastUpdate
  isAdmin = $isAdmin
  accountName = [string]$identity.Name
} | ConvertTo-Json -Compress
''';
}
