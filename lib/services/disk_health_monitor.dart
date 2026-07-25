import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'ps_runner.dart';

class DiskHealthInfo {
  final String name;
  final String healthStatus;
  final String mediaType;
  final int sizeGb;
  final String operationalStatus;
  final double? temperatureC;
  final double? temperatureMaxC;
  final int? powerOnHours;
  final int? wearPercent;
  final int? readErrors;
  final int? writeErrors;
  final int? readErrorsUncorrected;
  final int? writeErrorsUncorrected;
  final int? bytesReadSinceBoot;
  final int? bytesWrittenSinceBoot;
  final int? readLatencyMaxMs;
  final int? writeLatencyMaxMs;
  final int? startStopCycles;
  final int? loadUnloadCycles;
  final String firmwareVersion;
  final String busType;
  final int? logicalSectorSize;
  final int? physicalSectorSize;
  final int? spindleSpeed;
  final int? nativeHealthPercent;
  final int? lifetimeBytesRead;
  final int? lifetimeBytesWritten;
  final int? powerCycles;
  final int? unsafeShutdowns;
  final int? mediaErrors;
  final int? deviceId;

  const DiskHealthInfo({
    required this.name,
    required this.healthStatus,
    required this.mediaType,
    required this.sizeGb,
    required this.operationalStatus,
    this.temperatureC,
    this.temperatureMaxC,
    this.powerOnHours,
    this.wearPercent,
    this.readErrors,
    this.writeErrors,
    this.readErrorsUncorrected,
    this.writeErrorsUncorrected,
    this.bytesReadSinceBoot,
    this.bytesWrittenSinceBoot,
    this.readLatencyMaxMs,
    this.writeLatencyMaxMs,
    this.startStopCycles,
    this.loadUnloadCycles,
    this.firmwareVersion = '',
    this.busType = '',
    this.logicalSectorSize,
    this.physicalSectorSize,
    this.spindleSpeed,
    this.nativeHealthPercent,
    this.lifetimeBytesRead,
    this.lifetimeBytesWritten,
    this.powerCycles,
    this.unsafeShutdowns,
    this.mediaErrors,
    this.deviceId,
  });

  int get healthLevel {
    final value = healthStatus.toLowerCase();
    if (value == 'healthy' || value == 'ok' || value == '良好') return 0;
    if (value == 'warning' || value == 'degraded' || value == '警告') return 1;
    if (value == 'unknown' || value == '未知' || value.isEmpty) return -1;
    return 2;
  }

  bool get isSsd {
    final value = mediaType.toLowerCase();
    return value.contains('ssd') ||
        value.contains('solid') ||
        value.contains('nvme');
  }

  bool get hasReliabilityData =>
      temperatureC != null ||
      temperatureMaxC != null ||
      powerOnHours != null ||
      wearPercent != null ||
      readErrors != null ||
      writeErrors != null ||
      readErrorsUncorrected != null ||
      writeErrorsUncorrected != null ||
      readLatencyMaxMs != null ||
      writeLatencyMaxMs != null;

  /// Windows 的 Wear 是“已消耗寿命”，仅在设备上报该指标时才能推导健康度。
  int? get healthPercent =>
      nativeHealthPercent ??
      (wearPercent == null ? null : (100 - wearPercent!).clamp(0, 100));

  DiskHealthInfo withNativeNvme(Map<Object?, Object?> values) {
    return DiskHealthInfo(
      name: name,
      healthStatus: healthStatus,
      mediaType: mediaType,
      sizeGb: sizeGb,
      operationalStatus: operationalStatus,
      temperatureC: temperatureC,
      temperatureMaxC: temperatureMaxC,
      powerOnHours: powerOnHours,
      wearPercent: wearPercent,
      readErrors: readErrors,
      writeErrors: writeErrors,
      readErrorsUncorrected: readErrorsUncorrected,
      writeErrorsUncorrected: writeErrorsUncorrected,
      bytesReadSinceBoot: bytesReadSinceBoot,
      bytesWrittenSinceBoot: bytesWrittenSinceBoot,
      readLatencyMaxMs: readLatencyMaxMs,
      writeLatencyMaxMs: writeLatencyMaxMs,
      startStopCycles: startStopCycles,
      loadUnloadCycles: loadUnloadCycles,
      firmwareVersion: firmwareVersion,
      busType: busType,
      logicalSectorSize: logicalSectorSize,
      physicalSectorSize: physicalSectorSize,
      spindleSpeed: spindleSpeed,
      nativeHealthPercent: _mapInt(values['healthPercent']),
      lifetimeBytesRead: _mapInt(values['lifetimeBytesRead']),
      lifetimeBytesWritten: _mapInt(values['lifetimeBytesWritten']),
      powerCycles: _mapInt(values['powerCycles']),
      unsafeShutdowns: _mapInt(values['unsafeShutdowns']),
      mediaErrors: _mapInt(values['mediaErrors']),
      deviceId: deviceId,
    );
  }

  static int? _mapInt(Object? value) => value is int ? value : null;

  String get lifeEstimate {
    if (healthLevel == 2) return '需要更换';
    if (healthLevel == 1) return '需要关注';
    if (healthLevel == -1) return '无法评估';
    if (wearPercent != null) {
      if (wearPercent! >= 90) return '接近寿命上限';
      if (wearPercent! >= 50) return '已消耗过半';
    }
    if (powerOnHours != null && powerOnHours! > 43800) return '使用时间较长';
    return '状态良好';
  }
}

class DiskHealthReport {
  final List<DiskHealthInfo> disks;
  final String source;
  final String? message;

  const DiskHealthReport({
    required this.disks,
    required this.source,
    this.message,
  });

  bool get hasReliabilityData => disks.any((disk) => disk.hasReliabilityData);
}

class DiskHealthMonitor {
  DiskHealthMonitor._();

  static const _cacheDuration = Duration(seconds: 10);
  static DiskHealthReport? _cached;
  static DateTime? _cachedAt;
  static Future<DiskHealthReport>? _inFlight;
  static const _storageChannel = MethodChannel(
    'system_health_toolkit/storage_health',
  );

  static Future<List<DiskHealthInfo>> collect({bool force = false}) async {
    return (await collectReport(force: force)).disks;
  }

  static Future<DiskHealthReport> collectReport({bool force = false}) {
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

  static Future<DiskHealthReport> _collectNow() async {
    final result = await PsRunner.runResult(_script);
    if (result.stdout.isEmpty) {
      return DiskHealthReport(
        disks: _cached?.disks ?? const [],
        source: _cached?.source ?? '',
        message: result.timedOut ? '磁盘信息读取超时，请稍后重试' : '无法读取磁盘信息',
      );
    }

    try {
      final jsonLine = result.stdout
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.startsWith('{'))
          .last;
      final root = jsonDecode(jsonLine) as Map<String, dynamic>;
      final rawDisks = root['disks'];
      final entries = rawDisks is List
          ? rawDisks
          : rawDisks == null
          ? const []
          : [rawDisks];
      var disks = entries
          .whereType<Map<String, dynamic>>()
          .map(_fromJson)
          .toList(growable: false);
      disks = await _enrichWithNativeNvme(disks);
      final report = DiskHealthReport(
        disks: disks,
        source: '${root['source'] ?? ''}',
        message: disks.isEmpty
            ? 'Windows 未返回可用的物理磁盘信息'
            : result.timedOut
            ? '已显示基础信息；SMART 扩展数据读取超时'
            : null,
      );
      if (disks.isNotEmpty) {
        _cached = report;
        _cachedAt = DateTime.now();
      }
      return report;
    } catch (e) {
      PsRunner.debugPrint('DiskHealthMonitor parse error: $e');
      return DiskHealthReport(
        disks: _cached?.disks ?? const [],
        source: _cached?.source ?? '',
        message: '磁盘信息格式无法解析',
      );
    }
  }

  static DiskHealthInfo _fromJson(Map<String, dynamic> json) {
    return DiskHealthInfo(
      name: _text(json['name'], '未知磁盘'),
      healthStatus: _text(json['health'], 'Unknown'),
      mediaType: _mediaText(_text(json['mediaType'], '未知')),
      sizeGb: _int(json['sizeGb']) ?? 0,
      operationalStatus: _statusText(_text(json['operationalStatus'], '未知')),
      temperatureC: _positiveDouble(json['temperature']),
      temperatureMaxC: _positiveDouble(json['temperatureMax']),
      powerOnHours: _nonNegativeInt(json['powerOnHours']),
      wearPercent: _percent(json['wear']),
      readErrors: _nonNegativeInt(json['readErrors']),
      writeErrors: _nonNegativeInt(json['writeErrors']),
      readErrorsUncorrected: _nonNegativeInt(json['readErrorsUncorrected']),
      writeErrorsUncorrected: _nonNegativeInt(json['writeErrorsUncorrected']),
      bytesReadSinceBoot: _nonNegativeInt(json['bytesReadSinceBoot']),
      bytesWrittenSinceBoot: _nonNegativeInt(json['bytesWrittenSinceBoot']),
      readLatencyMaxMs: _nonNegativeInt(json['readLatencyMax']),
      writeLatencyMaxMs: _nonNegativeInt(json['writeLatencyMax']),
      startStopCycles: _nonNegativeInt(json['startStopCycles']),
      loadUnloadCycles: _nonNegativeInt(json['loadUnloadCycles']),
      firmwareVersion: _text(json['firmwareVersion'], ''),
      busType: _text(json['busType'], ''),
      logicalSectorSize: _positiveInt(json['logicalSectorSize']),
      physicalSectorSize: _positiveInt(json['physicalSectorSize']),
      spindleSpeed: _positiveInt(json['spindleSpeed']),
      deviceId: _nonNegativeInt(json['deviceId']),
    );
  }

  static Future<List<DiskHealthInfo>> _enrichWithNativeNvme(
    List<DiskHealthInfo> disks,
  ) async {
    if (!Platform.isWindows) return disks;
    return Future.wait(
      disks.map((disk) async {
        if (!disk.busType.toLowerCase().contains('nvme') ||
            disk.deviceId == null) {
          return disk;
        }
        try {
          final values = await _storageChannel
              .invokeMapMethod<Object?, Object?>(
                'queryNvmeHealth',
                disk.deviceId,
              );
          return values == null || values.isEmpty
              ? disk
              : disk.withNativeNvme(values);
        } on MissingPluginException {
          return disk;
        } on PlatformException catch (e) {
          PsRunner.debugPrint('NVMe health query failed: ${e.message}');
          return disk;
        }
      }),
    );
  }

  static String _text(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static int? _int(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static int? _nonNegativeInt(dynamic value) {
    final parsed = _int(value);
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  static int? _positiveInt(dynamic value) {
    final parsed = _int(value);
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static int? _percent(dynamic value) {
    final parsed = _nonNegativeInt(value);
    return parsed != null && parsed <= 100 ? parsed : null;
  }

  static double? _positiveDouble(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static String _mediaText(String value) {
    switch (value.toLowerCase()) {
      case 'ssd':
      case 'solid state drive':
      case '4':
        return 'SSD';
      case 'hdd':
      case 'hard disk drive':
      case '3':
        return 'HDD';
      case 'scm':
      case '5':
        return 'SCM';
      case 'unspecified':
      case '0':
        return '未知';
      default:
        return value;
    }
  }

  static String _statusText(String value) {
    return value
        .replaceAll('Healthy', '正常')
        .replaceAll('OK', '正常')
        .replaceAll('Unknown', '未知');
  }

  static const _script = r'''
$ErrorActionPreference = 'SilentlyContinue'
$items = @()
$source = ''
$physicalDisks = @()

try {
  $physicalDisks = @(Get-PhysicalDisk -ErrorAction Stop)
  if ($physicalDisks.Count -gt 0) {
    $source = 'Storage'
    foreach ($disk in $physicalDisks) {
      $items += [pscustomobject]@{
        name = [string]$disk.FriendlyName
        health = [string]$disk.HealthStatus
        mediaType = [string]$disk.MediaType
        sizeGb = [math]::Round([double]$disk.Size / 1GB)
        operationalStatus = (@($disk.OperationalStatus) -join ', ')
        deviceId = [string]$disk.DeviceId
        firmwareVersion = [string]$disk.FirmwareVersion
        busType = [string]$disk.BusType
        logicalSectorSize = $disk.LogicalSectorSize
        physicalSectorSize = $disk.PhysicalSectorSize
        spindleSpeed = $disk.SpindleSpeed
        temperature = $null
        temperatureMax = $null
        powerOnHours = $null
        wear = $null
        readErrors = $null
        writeErrors = $null
        readErrorsUncorrected = $null
        writeErrorsUncorrected = $null
        bytesReadSinceBoot = $null
        bytesWrittenSinceBoot = $null
        readLatencyMax = $null
        writeLatencyMax = $null
        startStopCycles = $null
        loadUnloadCycles = $null
      }
    }
  }
} catch {}

if ($items.Count -eq 0) {
  try {
    $wmiDisks = @(Get-CimInstance Win32_DiskDrive -ErrorAction Stop)
    if ($wmiDisks.Count -gt 0) {
      $source = 'WMI'
      foreach ($disk in $wmiDisks) {
        $items += [pscustomobject]@{
          name = [string]$disk.Model
          health = if ($disk.Status) { [string]$disk.Status } else { 'Unknown' }
          mediaType = if ($disk.MediaType) { [string]$disk.MediaType } else { [string]$disk.InterfaceType }
          sizeGb = [math]::Round([double]$disk.Size / 1GB)
          operationalStatus = if ($disk.Status) { [string]$disk.Status } else { 'Unknown' }
          deviceId = [string]$disk.Index
          firmwareVersion = [string]$disk.FirmwareRevision
          busType = [string]$disk.InterfaceType
          logicalSectorSize = $disk.BytesPerSector
          physicalSectorSize = $null
          spindleSpeed = $null
          temperature = $null
          temperatureMax = $null
          powerOnHours = $null
          wear = $null
          readErrors = $null
          writeErrors = $null
          readErrorsUncorrected = $null
          writeErrorsUncorrected = $null
          bytesReadSinceBoot = $null
          bytesWrittenSinceBoot = $null
          readLatencyMax = $null
          writeLatencyMax = $null
          startStopCycles = $null
          loadUnloadCycles = $null
        }
      }
    }
  } catch {}
}

# 先输出基础磁盘信息。即使后续 SMART 查询超时，调用方仍可使用这一行。
[pscustomobject]@{
  source = $source
  disks = @($items)
} | ConvertTo-Json -Depth 5 -Compress

if ($physicalDisks.Count -gt 0) {
  $perfByIndex = @{}
  try {
    $perfDisks = @(Get-CimInstance Win32_PerfRawData_PerfDisk_PhysicalDisk -ErrorAction Stop)
    foreach ($perf in $perfDisks) {
      if ([string]$perf.Name -match '^(\d+)') {
        $perfByIndex[$matches[1]] = $perf
      }
    }
  } catch {}

  $extendedItems = @()
  foreach ($disk in $physicalDisks) {
    $reliability = $null
    $perf = $perfByIndex[[string]$disk.DeviceId]
    try {
      $reliability = $disk | Get-StorageReliabilityCounter -ErrorAction Stop
    } catch {}
    $extendedItems += [pscustomobject]@{
      name = [string]$disk.FriendlyName
      health = [string]$disk.HealthStatus
      mediaType = [string]$disk.MediaType
      sizeGb = [math]::Round([double]$disk.Size / 1GB)
      operationalStatus = (@($disk.OperationalStatus) -join ', ')
      deviceId = [string]$disk.DeviceId
      firmwareVersion = [string]$disk.FirmwareVersion
      busType = [string]$disk.BusType
      logicalSectorSize = $disk.LogicalSectorSize
      physicalSectorSize = $disk.PhysicalSectorSize
      spindleSpeed = $disk.SpindleSpeed
      temperature = if ($reliability) { $reliability.Temperature } else { $null }
      temperatureMax = if ($reliability) { $reliability.TemperatureMax } else { $null }
      powerOnHours = if ($reliability) { $reliability.PowerOnHours } else { $null }
      wear = if ($reliability) { $reliability.Wear } else { $null }
      readErrors = if ($reliability) { $reliability.ReadErrorsTotal } else { $null }
      writeErrors = if ($reliability) { $reliability.WriteErrorsTotal } else { $null }
      readErrorsUncorrected = if ($reliability) { $reliability.ReadErrorsUncorrected } else { $null }
      writeErrorsUncorrected = if ($reliability) { $reliability.WriteErrorsUncorrected } else { $null }
      bytesReadSinceBoot = if ($perf) { $perf.DiskReadBytesPerSec } else { $null }
      bytesWrittenSinceBoot = if ($perf) { $perf.DiskWriteBytesPerSec } else { $null }
      readLatencyMax = if ($reliability) { $reliability.ReadLatencyMax } else { $null }
      writeLatencyMax = if ($reliability) { $reliability.WriteLatencyMax } else { $null }
      startStopCycles = if ($reliability) { $reliability.StartStopCycleCount } else { $null }
      loadUnloadCycles = if ($reliability) { $reliability.LoadUnloadCycleCount } else { $null }
    }
  }
  [pscustomobject]@{
    source = $source
    disks = @($extendedItems)
  } | ConvertTo-Json -Depth 5 -Compress
}
''';
}
