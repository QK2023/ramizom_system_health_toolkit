import 'dart:convert';

import 'ps_runner.dart';

class SystemSnapshot {
  final String cpuModel;
  final double cpuUsage;
  final String gpuName;
  final double? gpuUsage;
  final double memTotalGb;
  final double memUsedGb;
  final double memUsage;
  final double diskUsage;
  final String? message;

  const SystemSnapshot({
    required this.cpuModel,
    required this.cpuUsage,
    required this.gpuName,
    required this.gpuUsage,
    required this.memTotalGb,
    required this.memUsedGb,
    required this.memUsage,
    required this.diskUsage,
    this.message,
  });

  factory SystemSnapshot.empty({String? message}) => SystemSnapshot(
    cpuModel: '正在获取…',
    cpuUsage: 0,
    gpuName: '正在获取…',
    gpuUsage: null,
    memTotalGb: 0,
    memUsedGb: 0,
    memUsage: 0,
    diskUsage: 0,
    message: message,
  );
}

class SystemMonitor {
  SystemMonitor._();

  static const _cacheDuration = Duration(seconds: 2);
  static SystemSnapshot? _cached;
  static DateTime? _cachedAt;
  static Future<SystemSnapshot>? _inFlight;

  static Future<SystemSnapshot> collect({bool force = false}) {
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

  static Future<SystemSnapshot> _collectNow() async {
    final result = await PsRunner.runResult(_script);
    if (!result.succeeded) {
      return _cached ??
          SystemSnapshot.empty(
            message: result.timedOut ? '系统信息读取超时' : '系统信息暂时不可用',
          );
    }
    try {
      final json = jsonDecode(result.stdout) as Map<String, dynamic>;
      final total = _number(json['memTotalGb']) ?? 0;
      final used = _number(json['memUsedGb']) ?? 0;
      final cpuModel = _text(json['cpuModel'], '未知处理器');
      if (total <= 0 && cpuModel == '未知处理器') {
        return _cached ?? SystemSnapshot.empty(message: 'Windows 未返回可用的系统指标');
      }
      final snapshot = SystemSnapshot(
        cpuModel: cpuModel,
        cpuUsage: _clampPercent(_number(json['cpuUsage']) ?? 0),
        gpuName: _text(json['gpuName'], '未检测到 GPU'),
        gpuUsage: _nullablePercent(json['gpuUsage']),
        memTotalGb: total,
        memUsedGb: used,
        memUsage: total > 0 ? _clampPercent(used / total * 100) : 0,
        diskUsage: _clampPercent(_number(json['diskUsage']) ?? 0),
      );
      _cached = snapshot;
      _cachedAt = DateTime.now();
      return snapshot;
    } catch (e) {
      PsRunner.debugPrint('SystemMonitor parse error: $e');
      return _cached ?? SystemSnapshot.empty(message: '系统信息格式无法解析');
    }
  }

  static String _text(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static double _clampPercent(double value) => value.clamp(0, 100).toDouble();

  static double? _nullablePercent(dynamic value) {
    final parsed = _number(value);
    return parsed == null ? null : _clampPercent(parsed);
  }

  static const _script = r'''
$ErrorActionPreference = 'SilentlyContinue'
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$os = Get-CimInstance Win32_OperatingSystem | Select-Object -First 1
$systemDisk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object -First 1
$gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name } | Select-Object -First 1

$total = if ($os) { [math]::Round([double]$os.TotalVisibleMemorySize / 1MB, 2) } else { 0 }
$free = if ($os) { [math]::Round([double]$os.FreePhysicalMemory / 1MB, 2) } else { 0 }
$diskUsage = 0
if ($systemDisk -and [double]$systemDisk.Size -gt 0) {
  $diskUsage = [math]::Round((([double]$systemDisk.Size - [double]$systemDisk.FreeSpace) / [double]$systemDisk.Size) * 100, 1)
}

[pscustomobject]@{
  cpuModel = if ($cpu.Name) { [string]$cpu.Name } else { '' }
  cpuUsage = if ($null -ne $cpu.LoadPercentage) { [double]$cpu.LoadPercentage } else { 0 }
  memTotalGb = $total
  memUsedGb = [math]::Round($total - $free, 2)
  diskUsage = $diskUsage
  gpuName = if ($gpu.Name) { [string]$gpu.Name } else { '' }
  gpuUsage = $null
} | ConvertTo-Json -Compress
''';
}
