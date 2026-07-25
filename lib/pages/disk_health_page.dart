import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/disk_health_monitor.dart';

/// 磁盘健康详情页
class DiskHealthPage extends StatefulWidget {
  const DiskHealthPage({super.key});

  @override
  State<DiskHealthPage> createState() => _DiskHealthPageState();
}

class _DiskHealthPageState extends State<DiskHealthPage> {
  List<DiskHealthInfo> _disks = [];
  bool _loading = true;
  bool _refreshing = false;
  String? _message;
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
      final report = await DiskHealthMonitor.collectReport(force: force);
      if (mounted && requestId == _requestId) {
        setState(() {
          _disks = report.disks;
          _message = report.message;
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

    if (_disks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storage, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              _refreshing
                  ? context.l10n.tr('diskSlow')
                  : context.l10n.tr('noDiskInfo'),
              style: theme.textTheme.bodyLarge,
            ),
            if (_refreshing) ...[
              const SizedBox(height: 16),
              const SizedBox(width: 240, child: LinearProgressIndicator()),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _refreshing ? null : () => _refresh(force: true),
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.tr('retry')),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Icon(Icons.storage, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              context.l10n.tr('diskHealth'),
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _refresh(force: true),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.l10n.tr('refresh')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_refreshing) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
        ],
        if (_message != null) ...[
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(context.l10n.tr('diskSlow')),
            ),
          ),
          const SizedBox(height: 12),
        ],
        ..._disks.map(
          (d) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _DiskDetailCard(disk: d),
          ),
        ),
      ],
    );
  }
}

class _DiskDetailCard extends StatelessWidget {
  final DiskHealthInfo disk;
  const _DiskDetailCard({required this.disk});

  Color _healthColor() {
    switch (disk.healthLevel) {
      case 0:
        return Colors.green;
      case 1:
        return Colors.orange;
      case -1:
        return Colors.grey;
      default:
        return Colors.red;
    }
  }

  String _healthLabel(BuildContext context) {
    switch (disk.healthLevel) {
      case 0:
        return context.l10n.tr('good');
      case 1:
        return context.l10n.tr('warning');
      case -1:
        return context.l10n.tr('unknown');
      default:
        return context.l10n.tr('abnormal');
    }
  }

  IconData _healthIcon() {
    switch (disk.healthLevel) {
      case 0:
        return Icons.check_circle;
      case 1:
        return Icons.warning;
      case -1:
        return Icons.help;
      default:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _healthColor();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.storage, color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(disk.name, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        '${disk.mediaType} · ${disk.sizeGb} GB',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_healthIcon(), color: color, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _healthLabel(context),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 健康数据网格
            _buildGrid(context, theme),
            if (!disk.hasReliabilityData) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.tr('limitedDiskData'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, ThemeData theme) {
    final items = <_DetailItem>[
      _DetailItem(
        icon: Icons.favorite,
        label: context.l10n.tr('healthPercent'),
        value: disk.healthPercent == null
            ? context.l10n.tr('notProvided')
            : '${disk.healthPercent}%',
        color: _healthPercentColor(),
      ),
      _DetailItem(
        icon: Icons.monitor_heart_outlined,
        label: context.l10n.tr('healthAssessment'),
        value: _lifeLabel(context),
        color: _lifeColor(),
      ),
      if (disk.lifetimeBytesRead != null)
        _DetailItem(
          icon: Icons.download,
          label: context.l10n.tr('lifetimeRead'),
          value: _formatBytes(disk.lifetimeBytesRead!),
          color: Colors.blue,
        )
      else if (disk.bytesReadSinceBoot != null)
        _DetailItem(
          icon: Icons.download,
          label: context.l10n.tr('bootRead'),
          value: _formatBytes(disk.bytesReadSinceBoot!),
          color: Colors.blue,
        ),
      if (disk.lifetimeBytesWritten != null)
        _DetailItem(
          icon: Icons.upload,
          label: context.l10n.tr('lifetimeWrite'),
          value: _formatBytes(disk.lifetimeBytesWritten!),
          color: Colors.deepPurple,
        )
      else if (disk.bytesWrittenSinceBoot != null)
        _DetailItem(
          icon: Icons.upload,
          label: context.l10n.tr('bootWrite'),
          value: _formatBytes(disk.bytesWrittenSinceBoot!),
          color: Colors.deepPurple,
        ),
      if (disk.temperatureC != null)
        _DetailItem(
          icon: Icons.thermostat,
          label: context.l10n.tr('currentTemperature'),
          value: '${disk.temperatureC!.toStringAsFixed(0)} °C',
          color: _tempColor(),
        ),
      if (disk.temperatureMaxC != null)
        _DetailItem(
          icon: Icons.device_thermostat,
          label: context.l10n.tr('maxTemperature'),
          value: '${disk.temperatureMaxC!.toStringAsFixed(0)} °C',
          color: Colors.orange,
        ),
      if (disk.powerOnHours != null)
        _DetailItem(
          icon: Icons.timer,
          label: context.l10n.tr('powerOnTime'),
          value: _formatHours(context, disk.powerOnHours!),
          color: Colors.blueGrey,
        ),
      if (disk.wearPercent != null)
        _DetailItem(
          icon: Icons.trending_up,
          label: context.l10n.tr('lifeUsed'),
          value: '${disk.wearPercent!}%',
          color: _wearColor(disk.wearPercent!),
        ),
      if (disk.readErrors != null)
        _DetailItem(
          icon: Icons.error_outline,
          label: context.l10n.tr('readErrors'),
          value: context.l10n.tr('times', {'count': disk.readErrors!}),
          color: disk.readErrors! > 0 ? Colors.orange : Colors.green,
        ),
      if (disk.writeErrors != null)
        _DetailItem(
          icon: Icons.warning_amber,
          label: context.l10n.tr('writeErrors'),
          value: context.l10n.tr('times', {'count': disk.writeErrors!}),
          color: disk.writeErrors! > 0 ? Colors.orange : Colors.green,
        ),
      if (disk.readErrorsUncorrected != null)
        _DetailItem(
          icon: Icons.report_problem_outlined,
          label: context.l10n.tr('uncorrectedReadErrors'),
          value: context.l10n.tr('times', {
            'count': disk.readErrorsUncorrected!,
          }),
          color: disk.readErrorsUncorrected! > 0 ? Colors.red : Colors.green,
        ),
      if (disk.writeErrorsUncorrected != null)
        _DetailItem(
          icon: Icons.report_problem,
          label: context.l10n.tr('uncorrectedWriteErrors'),
          value: context.l10n.tr('times', {
            'count': disk.writeErrorsUncorrected!,
          }),
          color: disk.writeErrorsUncorrected! > 0 ? Colors.red : Colors.green,
        ),
      if (disk.readLatencyMaxMs != null)
        _DetailItem(
          icon: Icons.speed,
          label: context.l10n.tr('maxReadLatency'),
          value: '${disk.readLatencyMaxMs!} ms',
          color: _latencyColor(disk.readLatencyMaxMs!),
        ),
      if (disk.writeLatencyMaxMs != null)
        _DetailItem(
          icon: Icons.speed_outlined,
          label: context.l10n.tr('maxWriteLatency'),
          value: '${disk.writeLatencyMaxMs!} ms',
          color: _latencyColor(disk.writeLatencyMaxMs!),
        ),
      if (disk.startStopCycles != null)
        _DetailItem(
          icon: Icons.power_settings_new,
          label: context.l10n.tr('startStopCount'),
          value: context.l10n.tr('times', {'count': disk.startStopCycles!}),
          color: Colors.blueGrey,
        ),
      if (disk.loadUnloadCycles != null)
        _DetailItem(
          icon: Icons.repeat,
          label: context.l10n.tr('headLoadCount'),
          value: context.l10n.tr('times', {'count': disk.loadUnloadCycles!}),
          color: Colors.blueGrey,
        ),
      if (disk.powerCycles != null)
        _DetailItem(
          icon: Icons.power,
          label: context.l10n.tr('powerCycleCount'),
          value: context.l10n.tr('times', {'count': disk.powerCycles!}),
          color: Colors.blueGrey,
        ),
      if (disk.unsafeShutdowns != null)
        _DetailItem(
          icon: Icons.power_off,
          label: context.l10n.tr('unsafeShutdownCount'),
          value: context.l10n.tr('times', {'count': disk.unsafeShutdowns!}),
          color: disk.unsafeShutdowns! > 0 ? Colors.orange : Colors.green,
        ),
      if (disk.mediaErrors != null)
        _DetailItem(
          icon: Icons.broken_image_outlined,
          label: context.l10n.tr('mediaErrors'),
          value: context.l10n.tr('times', {'count': disk.mediaErrors!}),
          color: disk.mediaErrors! > 0 ? Colors.red : Colors.green,
        ),
      _DetailItem(
        icon: Icons.memory,
        label: context.l10n.tr('mediaType'),
        value: disk.mediaType == '未知'
            ? context.l10n.tr('unknown')
            : disk.mediaType,
        color: disk.isSsd ? Colors.blue : Colors.brown,
      ),
      _DetailItem(
        icon: Icons.info_outline,
        label: context.l10n.tr('operationalStatus'),
        value: _statusLabel(context),
        color: Colors.grey,
      ),
      if (disk.busType.isNotEmpty)
        _DetailItem(
          icon: Icons.cable,
          label: context.l10n.tr('busType'),
          value: disk.busType,
          color: Colors.teal,
        ),
      if (disk.firmwareVersion.isNotEmpty)
        _DetailItem(
          icon: Icons.developer_board,
          label: context.l10n.tr('firmwareVersion'),
          value: disk.firmwareVersion,
          color: Colors.indigo,
        ),
      if (disk.logicalSectorSize != null)
        _DetailItem(
          icon: Icons.view_module_outlined,
          label: context.l10n.tr('logicalSector'),
          value: '${disk.logicalSectorSize} B',
          color: Colors.cyan,
        ),
      if (disk.physicalSectorSize != null)
        _DetailItem(
          icon: Icons.grid_view,
          label: context.l10n.tr('physicalSector'),
          value: '${disk.physicalSectorSize} B',
          color: Colors.cyan,
        ),
      if (disk.spindleSpeed != null)
        _DetailItem(
          icon: Icons.rotate_right,
          label: context.l10n.tr('spindleSpeed'),
          value: '${disk.spindleSpeed} RPM',
          color: Colors.brown,
        ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((e) => _detailChip(theme, e)).toList(),
    );
  }

  Widget _detailChip(ThemeData theme, _DetailItem item) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(item.icon, size: 18, color: item.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _lifeLabel(BuildContext context) {
    if (disk.healthLevel == 2) return context.l10n.tr('replaceSoon');
    if (disk.healthLevel == 1) return context.l10n.tr('checkDisk');
    if (disk.healthLevel == -1) return context.l10n.tr('cannotAssess');
    if ((disk.wearPercent ?? 0) >= 90) {
      return context.l10n.tr('nearLifeLimit');
    }
    if ((disk.wearPercent ?? 0) >= 50) {
      return context.l10n.tr('halfLifeUsed');
    }
    if ((disk.powerOnHours ?? 0) > 43800) {
      return context.l10n.tr('usedForLongTime');
    }
    return context.l10n.tr('statusGood');
  }

  String _statusLabel(BuildContext context) {
    final value = disk.operationalStatus.toLowerCase();
    if (value == '正常' || value == 'healthy' || value == 'ok') {
      return context.l10n.tr('good');
    }
    if (value == '未知' || value == 'unknown') {
      return context.l10n.tr('unknown');
    }
    return disk.operationalStatus;
  }

  Color _lifeColor() {
    if (disk.healthLevel == 2) return Colors.red;
    if (disk.healthLevel == 1 || disk.healthLevel == -1) return Colors.orange;
    if ((disk.wearPercent ?? 0) >= 50 || (disk.powerOnHours ?? 0) > 43800) {
      return Colors.orange;
    }
    return Colors.green;
  }

  Color _healthPercentColor() {
    final value = disk.healthPercent;
    if (value == null) return Colors.grey;
    if (value < 20) return Colors.red;
    if (value < 50) return Colors.orange;
    return Colors.green;
  }

  Color _tempColor() {
    final t = disk.temperatureC;
    if (t == null) return Colors.grey;
    if (t >= 60) return Colors.red;
    if (t >= 45) return Colors.orange;
    return Colors.green;
  }

  Color _wearColor(int wear) {
    if (wear >= 80) return Colors.red;
    if (wear >= 50) return Colors.orange;
    if (wear >= 20) return Colors.lime;
    return Colors.green;
  }

  Color _latencyColor(int milliseconds) {
    if (milliseconds >= 10000) return Colors.red;
    if (milliseconds >= 1000) return Colors.orange;
    return Colors.green;
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = value >= 100 || unit == 0
        ? 0
        : value >= 10
        ? 1
        : 2;
    return '${value.toStringAsFixed(digits)} ${units[unit]}';
  }

  String _formatHours(BuildContext context, int hours) {
    final days = hours ~/ 24;
    final years = days ~/ 365;
    final remainDays = days % 365;
    if (years > 0) {
      return context.l10n.tr('yearsDays', {'years': years, 'days': remainDays});
    }
    return context.l10n.tr('days', {'count': days});
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}
