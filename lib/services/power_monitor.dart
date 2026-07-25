import 'dart:convert';
import 'dart:io';

import 'windows_paths.dart';

class BatteryUsagePoint {
  final DateTime time;
  final double percent;

  const BatteryUsagePoint({required this.time, required this.percent});
}

class BatteryCapacityPoint {
  final DateTime time;
  final String period;
  final int fullChargeCapacityMwh;
  final int designCapacityMwh;

  const BatteryCapacityPoint({
    required this.time,
    required this.period,
    required this.fullChargeCapacityMwh,
    required this.designCapacityMwh,
  });

  double get healthPercent => fullChargeCapacityMwh / designCapacityMwh * 100;
}

class PowerSnapshot {
  final bool hasBattery;
  final String batteryName;
  final String manufacturer;
  final String serialNumber;
  final String chemistry;
  final int? designCapacityMwh;
  final int? fullChargeCapacityMwh;
  final int? cycleCount;
  final int? currentPercent;
  final int? currentCapacityMwh;
  final DateTime? reportTime;
  final List<BatteryUsagePoint> usageHistory;
  final List<BatteryCapacityPoint> capacityHistory;
  final String? reportPath;
  final String? message;

  const PowerSnapshot({
    required this.hasBattery,
    required this.batteryName,
    required this.manufacturer,
    required this.serialNumber,
    required this.chemistry,
    required this.designCapacityMwh,
    required this.fullChargeCapacityMwh,
    required this.cycleCount,
    required this.currentPercent,
    required this.currentCapacityMwh,
    required this.reportTime,
    required this.usageHistory,
    required this.capacityHistory,
    this.reportPath,
    this.message,
  });

  factory PowerSnapshot.empty({String? message}) => PowerSnapshot(
    hasBattery: false,
    batteryName: '',
    manufacturer: '',
    serialNumber: '',
    chemistry: '',
    designCapacityMwh: null,
    fullChargeCapacityMwh: null,
    cycleCount: null,
    currentPercent: null,
    currentCapacityMwh: null,
    reportTime: null,
    usageHistory: const [],
    capacityHistory: const [],
    message: message,
  );

  double? get healthPercent {
    final design = designCapacityMwh;
    final full = fullChargeCapacityMwh;
    if (design == null || design <= 0 || full == null || full <= 0) return null;
    return (full / design * 100).clamp(0, 100).toDouble();
  }
}

class PowerMonitor {
  PowerMonitor._();

  static const _cacheDuration = Duration(minutes: 5);
  static PowerSnapshot? _cached;
  static DateTime? _cachedAt;
  static Future<PowerSnapshot>? _inFlight;

  /// Returns a recent report without starting `powercfg`.
  ///
  /// Lightweight pages can use this to avoid generating a full battery report
  /// as part of their own initial load.
  static PowerSnapshot? get cached {
    final cachedAt = _cachedAt;
    if (_cached == null ||
        cachedAt == null ||
        DateTime.now().difference(cachedAt) >= _cacheDuration) {
      return null;
    }
    return _cached;
  }

  static Future<PowerSnapshot> collect({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _cached != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _cacheDuration) {
      return Future.value(_cached);
    }
    if (_inFlight != null) return _inFlight!;

    final future = _generateAndParse();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  static Future<PowerSnapshot> _generateAndParse() async {
    if (!Platform.isWindows || Platform.environment['FLUTTER_TEST'] == 'true') {
      return PowerSnapshot.empty(message: '当前环境不生成电池报告');
    }

    Directory? reportDirectory;
    try {
      reportDirectory = await Directory.systemTemp.createTemp('ramizom_sht_');
      final reportFile = File(
        '${reportDirectory.path}${Platform.pathSeparator}battery-report.html',
      );
      final process = await Process.start(
        WindowsPaths.systemExecutable('powercfg.exe'),
        ['/batteryreport', '/output', reportFile.path, '/duration', '14'],
      );
      final stdoutFuture = process.stdout.drain<void>();
      final stderrFuture = process.stderr.drain<void>();
      var timedOut = false;
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          timedOut = true;
          process.kill();
          return -1;
        },
      );
      await Future.wait([stdoutFuture, stderrFuture]).timeout(
        const Duration(seconds: 1),
        onTimeout: () => const [null, null],
      );

      if (timedOut) {
        return _cached ?? PowerSnapshot.empty(message: '生成电池报告超时');
      }
      if (exitCode != 0 || !await reportFile.exists()) {
        return _cached ?? PowerSnapshot.empty(message: 'Windows 无法生成电池报告');
      }

      final html = await reportFile.readAsString(encoding: utf8);
      final parsed = parseHtml(html);
      _cached = parsed;
      _cachedAt = DateTime.now();
      return parsed;
    } catch (error) {
      return _cached ?? PowerSnapshot.empty(message: '读取电池报告失败：$error');
    } finally {
      if (reportDirectory != null) {
        final reportFile = File(
          '${reportDirectory.path}${Platform.pathSeparator}'
          'battery-report.html',
        );
        try {
          if (await reportFile.exists()) await reportFile.delete();
          if (await reportDirectory.exists()) await reportDirectory.delete();
        } catch (_) {
          // 临时报告清理失败不会影响系统或读取结果。
        }
      }
    }
  }

  /// 解析 Windows `powercfg /batteryreport` 生成的固定格式 HTML。
  static PowerSnapshot parseHtml(String html, {String? reportPath}) {
    final installed = _section(html, 'Installed batteries', 'Recent usage');
    final recent = _section(html, 'Recent usage', 'Battery usage');
    final name = _labelValue(installed, 'NAME');
    final design = _capacity(_labelValue(installed, 'DESIGN CAPACITY'));
    final full = _capacity(_labelValue(installed, 'FULL CHARGE CAPACITY'));
    final reportTimeText = _labelValue(html, 'REPORT TIME');

    final percentMatches = RegExp(r'(\d{1,3})\s*%')
        .allMatches(recent)
        .map((match) => int.tryParse(match.group(1)!))
        .whereType<int>()
        .where((value) => value >= 0 && value <= 100)
        .toList();
    final remainingMatches =
        RegExp(r'class="mw"[^>]*>\s*([\d,.]+)\s*mWh', caseSensitive: false)
            .allMatches(recent)
            .map((match) => _capacity(match.group(1)!))
            .whereType<int>()
            .toList();
    final capacityHistory = _parseCapacityHistory(html);
    final usageHistory = _parseUsageGraph(html);
    final hasBattery = name.isNotEmpty || design != null || full != null;

    return PowerSnapshot(
      hasBattery: hasBattery,
      batteryName: name,
      manufacturer: _labelValue(installed, 'MANUFACTURER'),
      serialNumber: _labelValue(installed, 'SERIAL NUMBER'),
      chemistry: _labelValue(installed, 'CHEMISTRY'),
      designCapacityMwh: design,
      fullChargeCapacityMwh: full,
      cycleCount: _integer(_labelValue(installed, 'CYCLE COUNT')),
      currentPercent: percentMatches.isEmpty ? null : percentMatches.last,
      currentCapacityMwh: remainingMatches.isEmpty
          ? null
          : remainingMatches.last,
      reportTime: _dateTime(reportTimeText),
      usageHistory: usageHistory,
      capacityHistory: capacityHistory,
      reportPath: reportPath,
      message: hasBattery ? null : '电池报告中没有检测到已安装电池',
    );
  }

  static List<BatteryUsagePoint> _parseUsageGraph(String html) {
    final dataMatch = RegExp(
      r'drainGraphData\s*=\s*\[(.*?)\];',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (dataMatch == null) return const [];

    final points = <BatteryUsagePoint>[];
    for (final object in RegExp(
      r'\{(.*?)\}',
      dotAll: true,
    ).allMatches(dataMatch.group(1)!)) {
      final body = object.group(1)!;
      final start = _javascriptValue(body, 'x0');
      final end = _javascriptValue(body, 'x1');
      final startPercent = _javascriptNumber(body, 'y0');
      final endPercent = _javascriptNumber(body, 'y1');
      final startTime = _dateTime(start);
      final endTime = _dateTime(end);
      if (startTime != null && startPercent != null) {
        points.add(
          BatteryUsagePoint(
            time: startTime,
            percent: _graphPercent(startPercent),
          ),
        );
      }
      if (endTime != null && endPercent != null) {
        points.add(
          BatteryUsagePoint(time: endTime, percent: _graphPercent(endPercent)),
        );
      }
    }
    points.sort((a, b) => a.time.compareTo(b.time));
    return points;
  }

  static List<BatteryCapacityPoint> _parseCapacityHistory(String html) {
    final section = _section(
      html,
      'Battery capacity history',
      'Battery life estimates',
    );
    final points = <BatteryCapacityPoint>[];
    for (final row in RegExp(
      r'<tr\b[^>]*>(.*?)</tr>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(section)) {
      final cells =
          RegExp(r'<td\b[^>]*>(.*?)</td>', caseSensitive: false, dotAll: true)
              .allMatches(row.group(1)!)
              .map((match) => _plain(match.group(1)!))
              .toList();
      if (cells.length < 3) continue;
      final full = _capacity(cells[1]);
      final design = _capacity(cells[2]);
      final time = _dateTime(cells[0]);
      if (full == null || design == null || design <= 0 || time == null) {
        continue;
      }
      points.add(
        BatteryCapacityPoint(
          time: time,
          period: cells[0],
          fullChargeCapacityMwh: full,
          designCapacityMwh: design,
        ),
      );
    }
    return points;
  }

  static String _section(String html, String heading, String nextHeading) {
    final match = RegExp(
      '<h2>\\s*${RegExp.escape(heading)}\\s*</h2>'
      '(.*?)'
      '<h2>\\s*${RegExp.escape(nextHeading)}\\s*</h2>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    return match?.group(1) ?? '';
  }

  static String _labelValue(String html, String label) {
    final match = RegExp(
      '(?:<span\\s+class="label">|<td\\s+class="label">)'
      '\\s*${RegExp.escape(label)}\\s*'
      '(?:</span>\\s*</td>|</td>)'
      '\\s*<td[^>]*>(.*?)</td>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    return match == null ? '' : _plain(match.group(1)!);
  }

  static String _plain(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int? _capacity(String value) {
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    final parsed = int.tryParse(digits);
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static int? _integer(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  static DateTime? _dateTime(String value) {
    final match = RegExp(
      r'(\d{4}-\d{2}-\d{2})(?:[ T](\d{2}:\d{2}:\d{2}))?',
    ).firstMatch(value);
    if (match == null) return null;
    final time = match.group(2) ?? '00:00:00';
    return DateTime.tryParse('${match.group(1)}T$time');
  }

  static String _javascriptValue(String body, String key) {
    final match = RegExp(
      '["\\\']?$key["\\\']?\\s*:\\s*["\\\']([^"\\\']+)["\\\']',
      caseSensitive: false,
    ).firstMatch(body);
    return match?.group(1) ?? '';
  }

  static double? _javascriptNumber(String body, String key) {
    final match = RegExp(
      '["\\\']?$key["\\\']?\\s*:\\s*(-?\\d*\\.?\\d+)',
      caseSensitive: false,
    ).firstMatch(body);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  static double _graphPercent(double value) {
    final percent = value <= 1 ? value * 100 : value;
    return percent.clamp(0, 100).toDouble();
  }
}
