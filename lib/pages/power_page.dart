import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/power_monitor.dart';
import '../services/quick_jump.dart';

/// 解析 Windows battery report 后展示电池健康和历史曲线。
class PowerPage extends StatefulWidget {
  const PowerPage({super.key});

  @override
  State<PowerPage> createState() => _PowerPageState();
}

class _PowerPageState extends State<PowerPage> {
  PowerSnapshot _report = PowerSnapshot.empty();
  bool _loading = true;
  bool _refreshing = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh({bool force = false}) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _refreshing = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && requestId == _requestId && _loading) {
        setState(() => _loading = false);
      }
    });
    try {
      final report = await PowerMonitor.collect(force: force);
      if (mounted && requestId == _requestId) {
        setState(() {
          _report = report;
          _loading = false;
          _refreshing = false;
        });
      }
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    final report = _report;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Icon(Icons.battery_6_bar, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              context.l10n.tr('windowsBatteryReport'),
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _refreshing ? null : () => _refresh(force: true),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.l10n.tr('regenerate')),
            ),
          ],
        ),
        if (_refreshing) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            context.l10n.tr('generatingBatteryReport'),
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        if (report.message != null) ...[
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(context.l10n.tr('notAvailable')),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (report.hasBattery) ...[
          _ReportOverviewCard(report: report),
          const SizedBox(height: 16),
          _CapacityCard(report: report),
          const SizedBox(height: 16),
          _UsageHistoryCard(points: report.usageHistory),
          const SizedBox(height: 16),
          _CapacityHistoryCard(points: report.capacityHistory),
          const SizedBox(height: 16),
        ] else
          const _NoBatteryCard(),
        const SizedBox(height: 16),
        const _PerformanceSettingsCard(),
      ],
    );
  }
}

class _ReportOverviewCard extends StatelessWidget {
  final PowerSnapshot report;
  const _ReportOverviewCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = report.currentPercent;
    final health = report.healthPercent;
    final color = health == null
        ? Colors.grey
        : health < 60
        ? Colors.red
        : health < 80
        ? Colors.orange
        : Colors.green;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.battery_full, size: 40, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.batteryName.isEmpty
                            ? context.l10n.tr('systemBattery')
                            : report.batteryName,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        [
                          report.manufacturer,
                          report.chemistry,
                        ].where((value) => value.isNotEmpty).join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (percent != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        context.l10n.tr('chargeAtReport'),
                        style: theme.textTheme.bodySmall,
                      ),
                      Text('$percent%', style: theme.textTheme.headlineSmall),
                    ],
                  ),
              ],
            ),
            if (health != null) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: health / 100,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(8),
                      color: color,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    context.l10n.tr('batteryHealthValue', {
                      'percent': health.toStringAsFixed(1),
                    }),
                    style: theme.textTheme.titleSmall?.copyWith(color: color),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Text(
              context.l10n.tr('reportTime', {
                'time': _formatDateTime(context, report.reportTime),
              }),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CapacityCard extends StatelessWidget {
  final PowerSnapshot report;
  const _CapacityCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final health = report.healthPercent;
    final items = [
      (
        context.l10n.tr('designCapacity'),
        _capacity(context, report.designCapacityMwh),
        Icons.factory_outlined,
      ),
      (
        context.l10n.tr('fullChargeCapacity'),
        _capacity(context, report.fullChargeCapacityMwh),
        Icons.battery_saver,
      ),
      (
        context.l10n.tr('remainingCapacity'),
        _capacity(context, report.currentCapacityMwh),
        Icons.battery_5_bar,
      ),
      (
        context.l10n.tr('batteryHealth'),
        health == null
            ? context.l10n.tr('notProvided')
            : '${health.toStringAsFixed(1)}%',
        Icons.favorite_outline,
      ),
      (
        context.l10n.tr('cycleCount'),
        report.cycleCount == null
            ? context.l10n.tr('notProvided')
            : context.l10n.tr('times', {'count': report.cycleCount}),
        Icons.loop,
      ),
      (
        context.l10n.tr('serialNumber'),
        report.serialNumber.isEmpty
            ? context.l10n.tr('notProvided')
            : report.serialNumber,
        Icons.numbers,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.tr('batteryDetails'),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items
                  .map(
                    (item) => Container(
                      width: 215,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(item.$3, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.$1, style: theme.textTheme.bodySmall),
                                const SizedBox(height: 3),
                                Text(
                                  item.$2,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageHistoryCard extends StatelessWidget {
  final List<BatteryUsagePoint> points;
  const _UsageHistoryCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final chartPoints = points
        .map((point) => _ChartPoint(time: point.time, value: point.percent))
        .toList(growable: false);
    return _HistoryChartCard(
      icon: Icons.battery_alert,
      title: context.l10n.tr('batteryUsageHistory'),
      subtitle: context.l10n.tr('batteryUsageSubtitle'),
      emptyText: context.l10n.tr('noBatteryUsage'),
      points: chartPoints,
      suffix: '%',
      minY: 0,
      maxY: 100,
    );
  }
}

class _CapacityHistoryCard extends StatelessWidget {
  final List<BatteryCapacityPoint> points;
  const _CapacityHistoryCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final chartPoints = points
        .map(
          (point) => _ChartPoint(time: point.time, value: point.healthPercent),
        )
        .toList(growable: false);
    return _HistoryChartCard(
      icon: Icons.timeline,
      title: context.l10n.tr('capacityHistory'),
      subtitle: context.l10n.tr('capacityHistorySubtitle'),
      emptyText: context.l10n.tr('noCapacityHistory'),
      points: chartPoints,
      suffix: '%',
      minY: chartPoints.isEmpty
          ? 0
          : (chartPoints
                        .map((point) => point.value)
                        .reduce((a, b) => a < b ? a : b) -
                    5)
                .clamp(0, 100)
                .toDouble(),
      maxY: 100,
    );
  }
}

class _HistoryChartCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String emptyText;
  final List<_ChartPoint> points;
  final String suffix;
  final double minY;
  final double maxY;

  const _HistoryChartCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.points,
    required this.suffix,
    required this.minY,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            SizedBox(
              height: 230,
              width: double.infinity,
              child: points.length < 2
                  ? Center(
                      child: Text(emptyText, style: theme.textTheme.bodyMedium),
                    )
                  : CustomPaint(
                      painter: _HistoryChartPainter(
                        points: points,
                        minY: minY,
                        maxY: maxY,
                        suffix: suffix,
                        lineColor: theme.colorScheme.primary,
                        gridColor: theme.colorScheme.outlineVariant,
                        labelColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryChartPainter extends CustomPainter {
  final List<_ChartPoint> points;
  final double minY;
  final double maxY;
  final String suffix;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;

  const _HistoryChartPainter({
    required this.points,
    required this.minY,
    required this.maxY,
    required this.suffix,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 48.0;
    const top = 10.0;
    const bottom = 26.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - 8,
      size.height - bottom,
    );
    final range = maxY - minY;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: labelColor, fontSize: 10);

    for (var index = 0; index <= 4; index++) {
      final value = minY + range * index / 4;
      final y = chart.bottom - chart.height * index / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _paintLabel(
        canvas,
        '${value.toStringAsFixed(0)}$suffix',
        Offset(2, y - 7),
        labelStyle,
      );
    }

    final firstTime = points.first.time.millisecondsSinceEpoch.toDouble();
    final lastTime = points.last.time.millisecondsSinceEpoch.toDouble();
    final timeRange = lastTime - firstTime;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = timeRange <= 0
          ? chart.left
          : chart.left +
                chart.width *
                    (point.time.millisecondsSinceEpoch - firstTime) /
                    timeRange;
      final y =
          chart.bottom -
          chart.height * ((point.value - minY) / range).clamp(0, 1);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _paintTime(canvas, chart.left, chart.bottom + 7, points.first.time, false);
    _paintTime(canvas, chart.right, chart.bottom + 7, points.last.time, true);
  }

  void _paintLabel(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _paintTime(
    Canvas canvas,
    double x,
    double y,
    DateTime time,
    bool alignRight,
  ) {
    final text =
        '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(alignRight ? x - painter.width : x, y));
  }

  @override
  bool shouldRepaint(covariant _HistoryChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _PerformanceSettingsCard extends StatelessWidget {
  const _PerformanceSettingsCard();

  static const _items = [
    (Icons.power_settings_new, 'powerAndBattery', 'powerAndBatteryDesc', '电源'),
    (Icons.eco_outlined, 'energyTips', 'energyTipsDesc', '节能建议'),
    (Icons.monitor, 'graphicsSettings', 'graphicsSettingsDesc', '图形设置'),
    (
      Icons.rocket_launch_outlined,
      'startupApplications',
      'startupApplicationsDesc',
      '启动项',
    ),
    (Icons.sports_esports_outlined, 'gameMode', 'gameModeDesc', '游戏模式'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.tr('usefulPerformanceSettings'),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760
                    ? 3
                    : constraints.maxWidth >= 460
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _items
                      .map(
                        (item) => SizedBox(
                          width: width,
                          height: 88,
                          child: OutlinedButton(
                            onPressed: () => QuickJump.launch(item.$4),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              alignment: Alignment.centerLeft,
                            ),
                            child: Row(
                              children: [
                                Icon(item.$1),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        context.l10n.tr(item.$2),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        context.l10n.tr(item.$3),
                                        style: theme.textTheme.bodySmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.open_in_new, size: 16),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NoBatteryCard extends StatelessWidget {
  const _NoBatteryCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(
              Icons.battery_unknown,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(context.l10n.tr('noBattery'))),
          ],
        ),
      ),
    );
  }
}

class _ChartPoint {
  final DateTime time;
  final double value;

  const _ChartPoint({required this.time, required this.value});
}

String _capacity(BuildContext context, int? mwh) {
  return mwh == null
      ? context.l10n.tr('notProvided')
      : '${(mwh / 1000).toStringAsFixed(2)} Wh';
}

String _formatDateTime(BuildContext context, DateTime? time) {
  if (time == null) return context.l10n.tr('unknown');
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')} '
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}
