import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/disk_health_monitor.dart';
import '../services/quick_jump.dart';
import '../services/system_monitor.dart';

/// 主页仪表板：展示 CPU/GPU 占用率、内存、磁盘、系统信息、运行状态。
class HomeDashboardPage extends StatefulWidget {
  final AppSettings settings;
  const HomeDashboardPage({super.key, required this.settings});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  SystemSnapshot _snapshot = SystemSnapshot.empty();
  List<DiskHealthInfo> _disks = [];
  Timer? _timer;
  int _lastInterval = 0;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
    _setupTimer();
    _refresh();
  }

  void _onSettingsChanged() {
    if (widget.settings.refreshIntervalSec != _lastInterval) {
      _setupTimer();
    }
  }

  void _setupTimer() {
    _timer?.cancel();
    _lastInterval = widget.settings.refreshIntervalSec;
    _timer = Timer.periodic(
      Duration(seconds: widget.settings.refreshIntervalSec),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final results = await Future.wait([
        SystemMonitor.collect(),
        DiskHealthMonitor.collect(),
      ]);
      if (mounted) {
        setState(() {
          _snapshot = results[0] as SystemSnapshot;
          _disks = results[1] as List<DiskHealthInfo>;
        });
      }
    } catch (_) {
      // 静默失败，保留上一次数据
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _snapshot;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _DeviceOverviewCard(snapshot: s, disks: _disks),
        const SizedBox(height: 16),
        if (s.message != null) ...[
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(context.l10n.tr('waitingForMetrics')),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _UsageCard(
                title: 'CPU',
                subtitle: _systemName(context, s.cpuModel, 'unknownProcessor'),
                usage: s.cpuUsage,
                icon: Icons.memory,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _UsageCard(
                title: 'GPU',
                subtitle: _systemName(context, s.gpuName, 'noGpu'),
                usage: s.gpuUsage ?? 0,
                hasUsage: s.gpuUsage != null,
                icon: Icons.developer_board,
                color: Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _UsageCard(
                title: context.l10n.tr('memory'),
                subtitle:
                    '${s.memUsedGb.toStringAsFixed(1)} / ${s.memTotalGb.toStringAsFixed(1)} GB',
                usage: s.memUsage,
                icon: Icons.sd_storage,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _UsageCard(
                title: context.l10n.tr('systemDisk'),
                subtitle: context.l10n.tr('usedPercent', {
                  'percent': s.diskUsage.toStringAsFixed(1),
                }),
                usage: s.diskUsage,
                icon: Icons.storage,
                color: Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _RunStatusCard(snapshot: s),
        const SizedBox(height: 16),
        _QuickJumpCard(),
      ],
    );
  }
}

// ═══════════════════ 设备概览卡 ═══════════════════

class _DeviceOverviewCard extends StatelessWidget {
  final SystemSnapshot snapshot;
  final List<DiskHealthInfo> disks;
  const _DeviceOverviewCard({required this.snapshot, required this.disks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = snapshot;
    // 汇总磁盘信息
    final totalDiskGb = disks.fold<int>(0, (sum, d) => sum + d.sizeGb);
    final worstHealth = disks.isEmpty
        ? 0
        : disks.map((d) => d.healthLevel).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.tr('deviceOverview'),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _OverviewChip(
                    icon: Icons.memory,
                    label: context.l10n.tr('processor'),
                    value: _systemName(context, s.cpuModel, 'unknownProcessor'),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OverviewChip(
                    icon: Icons.sd_storage,
                    label: context.l10n.tr('memory'),
                    value: '${s.memTotalGb.toStringAsFixed(0)} GB',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _OverviewChip(
                    icon: Icons.developer_board,
                    label: context.l10n.tr('graphics'),
                    value: _systemName(context, s.gpuName, 'noGpu'),
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OverviewChip(
                    icon: Icons.storage,
                    label: context.l10n.tr('disk'),
                    value: disks.isEmpty
                        ? context.l10n.tr('loading')
                        : context.l10n.tr('diskCount', {
                            'size': totalDiskGb,
                            'count': disks.length,
                          }),
                    color: _diskHealthColor(worstHealth),
                    trailing: disks.isNotEmpty
                        ? _DiskHealthDot(level: worstHealth)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _diskHealthColor(int level) {
    switch (level) {
      case 0:
        return Colors.green;
      case 1:
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
}

/// 磁盘健康状态指示灯
class _DiskHealthDot extends StatelessWidget {
  final int level;
  const _DiskHealthDot({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = level == 0
        ? Colors.green
        : level == 1
        ? Colors.orange
        : Colors.red;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
        ],
      ),
    );
  }
}

class _OverviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Widget? trailing;
  const _OverviewChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

// ═══════════════════ 占用率环形卡片 ═══════════════════

class _UsageCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double usage;
  final bool hasUsage;
  final IconData icon;
  final Color color;

  const _UsageCard({
    required this.title,
    required this.subtitle,
    required this.usage,
    required this.icon,
    required this.color,
    this.hasUsage = true,
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
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 88,
                height: 88,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: usage / 100,
                    color: color,
                    trackColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Center(
                    child: hasUsage
                        ? Text(
                            '${usage.toStringAsFixed(0)}%',
                            style: theme.textTheme.titleSmall,
                          )
                        : Text('N/A', style: theme.textTheme.bodySmall),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════ 运行状态卡 ═══════════════════

class _RunStatusCard extends StatelessWidget {
  final SystemSnapshot snapshot;
  const _RunStatusCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cpuHigh = snapshot.cpuUsage > 85;
    final memHigh = snapshot.memUsage > 85;
    final diskHigh = snapshot.diskUsage > 90;
    final unavailable = snapshot.message != null || snapshot.memTotalGb <= 0;

    final healthy = !unavailable && !cpuHigh && !memHigh && !diskHigh;
    final statusText = unavailable
        ? context.l10n.tr('cannotEvaluate')
        : healthy
        ? context.l10n.tr('runningNormally')
        : context.l10n.tr('needsAttention');
    final statusColor = unavailable
        ? Colors.grey
        : healthy
        ? Colors.green
        : Colors.orange;
    final statusIcon = unavailable
        ? Icons.help
        : healthy
        ? Icons.check_circle
        : Icons.warning;

    final warnings = <String>[];
    if (cpuHigh) {
      warnings.add(
        context.l10n.tr('cpuHigh', {
          'percent': snapshot.cpuUsage.toStringAsFixed(0),
        }),
      );
    }
    if (memHigh) {
      warnings.add(
        context.l10n.tr('memoryHigh', {
          'percent': snapshot.memUsage.toStringAsFixed(0),
        }),
      );
    }
    if (diskHigh) {
      warnings.add(
        context.l10n.tr('diskSpaceLow', {
          'percent': snapshot.diskUsage.toStringAsFixed(0),
        }),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_heart, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.tr('systemStatus'),
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (unavailable)
              Text(
                context.l10n.tr('waitingForMetrics'),
                style: theme.textTheme.bodyMedium,
              )
            else if (warnings.isEmpty)
              Text(
                context.l10n.tr('allNormal'),
                style: theme.textTheme.bodyMedium,
              )
            else
              ...warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(w, style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════ 环形进度画笔 ═══════════════════

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = trackColor,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}

// ═══════════════════ 快捷跳转卡 ═══════════════════

class _QuickJumpCard extends StatelessWidget {
  static const _items =
      <({IconData icon, String key, String target, Color color})>[
        (
          icon: Icons.info_outline,
          key: 'systemVersion',
          target: '系统版本',
          color: Colors.teal,
        ),
        (
          icon: Icons.system_update,
          key: 'windowsUpdate',
          target: 'Windows 更新',
          color: Colors.blue,
        ),
        (
          icon: Icons.security,
          key: 'windowsSecurity',
          target: 'Windows 安全中心',
          color: Colors.green,
        ),
        (icon: Icons.storage, key: 'storage', target: '存储', color: Colors.teal),
        (
          icon: Icons.battery_charging_full,
          key: 'power',
          target: '电源',
          color: Colors.amber,
        ),
        (icon: Icons.apps, key: 'apps', target: '应用', color: Colors.purple),
        (
          icon: Icons.play_circle,
          key: 'startupApps',
          target: '启动项',
          color: Colors.indigo,
        ),
        (
          icon: Icons.privacy_tip,
          key: 'privacy',
          target: '隐私',
          color: Colors.blueGrey,
        ),
      ];

  const _QuickJumpCard();

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
                Icon(Icons.open_in_new, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.tr('quickLinks'),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _items
                  .map(
                    (e) => _JumpChip(
                      icon: e.icon,
                      label: context.l10n.tr(e.key),
                      target: e.target,
                      color: e.color,
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

class _JumpChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String target;
  final Color color;
  const _JumpChip({
    required this.icon,
    required this.label,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      onPressed: () => QuickJump.launch(target),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.withValues(alpha: 0.4)),
    );
  }
}

String _systemName(BuildContext context, String value, String fallbackKey) {
  if (value == '正在获取…') return context.l10n.tr('loading');
  if (value == '未知处理器' || value == '未检测到 GPU' || value.isEmpty) {
    return context.l10n.tr(fallbackKey);
  }
  return value;
}
