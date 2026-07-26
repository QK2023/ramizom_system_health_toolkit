import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/power_monitor.dart';
import '../services/quick_jump.dart';
import '../services/security_monitor.dart';
import '../services/system_maintenance.dart';
import '../services/system_monitor.dart';

/// 推荐的设置页面：综合系统状态给出真实、可操作的优化建议
class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  List<_Recommendation> _recs = [];
  bool _loading = true;
  bool _refreshing = false;
  int _requestId = 0;
  Timer? _loadingTimer;
  String? _maintenanceBusy;
  UpdatePauseState _updatePauseState = const UpdatePauseState(active: false);

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
    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && requestId == _requestId && _loading) {
        setState(() => _loading = false);
      }
    });
    try {
      final recs = <_Recommendation>[];
      final futures = await Future.wait([
        SystemMonitor.collect(force: force),
        SecurityMonitor.collect(force: force),
        SystemMaintenance.getUpdatePauseState(),
      ]);
      if (!mounted || requestId != _requestId) return;

      // Access inherited localization only after initState has completed.
      final l = context.l10n;
      final sys = futures[0] as SystemSnapshot;
      final sec = futures[1] as SecuritySnapshot;
      final updatePauseState = futures[2] as UpdatePauseState;

      // A battery report is comparatively expensive to generate and parse.
      // Recommendations use it only when the Battery page already has a fresh
      // cached report, so opening this page never starts powercfg itself.
      final pwr = PowerMonitor.cached;
      final batteryHealth = pwr?.healthPercent;

      // 基于真实数据生成建议
      if (sec.realtimeProtection == false) {
        recs.add(
          _Recommendation(
            icon: Icons.shield,
            severity: _Severity.high,
            title: l.tr('turnOnDefender'),
            desc: l.tr('turnOnDefenderDesc'),
            action: 'openWindowsSecurity',
          ),
        );
      }
      if (sec.firewallEnabled == false) {
        recs.add(
          _Recommendation(
            icon: Icons.local_fire_department,
            severity: _Severity.high,
            title: l.tr('turnOnFirewall'),
            desc: l.tr('turnOnFirewallDesc'),
            action: 'openFirewall',
          ),
        );
      }
      if (sec.pendingUpdates != null && sec.pendingUpdates! > 0) {
        recs.add(
          _Recommendation(
            icon: Icons.system_update,
            severity: _Severity.medium,
            title: l.tr('installUpdates'),
            desc: l.tr('installUpdatesDesc', {'count': sec.pendingUpdates!}),
            action: 'openWindowsUpdate',
          ),
        );
      }
      if (sys.diskUsage > 90) {
        recs.add(
          _Recommendation(
            icon: Icons.storage,
            severity: _Severity.high,
            title: l.tr('cleanSystemDisk'),
            desc: l.tr('cleanSystemDiskDesc', {
              'percent': sys.diskUsage.toStringAsFixed(0),
            }),
            action: 'openStorage',
          ),
        );
      } else if (sys.diskUsage > 80) {
        recs.add(
          _Recommendation(
            icon: Icons.storage,
            severity: _Severity.low,
            title: l.tr('watchDiskSpace'),
            desc: l.tr('watchDiskSpaceDesc', {
              'percent': sys.diskUsage.toStringAsFixed(0),
            }),
            action: null,
          ),
        );
      }
      if (sys.memUsage > 85) {
        recs.add(
          _Recommendation(
            icon: Icons.memory,
            severity: _Severity.medium,
            title: l.tr('reduceMemory'),
            desc: l.tr('reduceMemoryDesc', {
              'percent': sys.memUsage.toStringAsFixed(0),
            }),
            action: null,
          ),
        );
      }
      if (batteryHealth != null && batteryHealth < 80) {
        recs.add(
          _Recommendation(
            icon: Icons.battery_alert,
            severity: _Severity.medium,
            title: l.tr('watchBattery'),
            desc: l.tr('watchBatteryDesc', {
              'percent': batteryHealth.toStringAsFixed(0),
            }),
            action: 'viewBatteryUsage',
          ),
        );
      }
      if (sys.cpuUsage > 85) {
        recs.add(
          _Recommendation(
            icon: Icons.memory,
            severity: _Severity.medium,
            title: l.tr('reduceCpu'),
            desc: l.tr('reduceCpuDesc', {
              'percent': sys.cpuUsage.toStringAsFixed(0),
            }),
            action: null,
          ),
        );
      }
      if (sec.bitlockerStatus == '未加密') {
        recs.add(
          _Recommendation(
            icon: Icons.lock_open,
            severity: _Severity.low,
            title: l.tr('considerBitLocker'),
            desc: l.tr('considerBitLockerDesc'),
            action: null,
          ),
        );
      }

      if (recs.isEmpty) {
        recs.add(
          _Recommendation(
            icon: Icons.check_circle,
            severity: _Severity.info,
            title: l.tr('systemLooksGood'),
            desc: l.tr('noActionNeeded'),
            action: null,
          ),
        );
      }

      if (mounted && requestId == _requestId) {
        _loadingTimer?.cancel();
        _loadingTimer = null;
        setState(() {
          _recs = recs;
          _loading = false;
          _refreshing = false;
          _updatePauseState = updatePauseState;
        });
      }
    } catch (_) {
      if (mounted && requestId == _requestId) {
        _loadingTimer?.cancel();
        _loadingTimer = null;
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  Future<bool> _confirmMaintenance({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _repairNetwork() async {
    final confirmed = await _confirmMaintenance(
      title: context.l10n.tr('networkRepair'),
      message: context.l10n.tr('networkRepairConfirm'),
      confirmLabel: context.l10n.tr('continueRepair'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _maintenanceBusy = 'network');
    final result = await SystemMaintenance.repairNetwork();
    if (!mounted) return;
    setState(() => _maintenanceBusy = null);
    _showMaintenanceResult(result);
  }

  Future<void> _pauseWindowsUpdates() async {
    final reapply = _updatePauseState.active;
    final confirmed = await _confirmMaintenance(
      title: context.l10n.tr(reapply ? 'reapplyPause' : 'pauseUpdates'),
      message: reapply
          ? context.l10n.tr('reapplyPauseConfirm')
          : context.l10n.tr('pauseUpdatesConfirm'),
      confirmLabel: context.l10n.tr(reapply ? 'reapply' : 'confirmPause'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _maintenanceBusy = 'updates');
    final result = await SystemMaintenance.pauseWindowsUpdates();
    final state = await SystemMaintenance.getUpdatePauseState();
    if (!mounted) return;
    setState(() {
      _maintenanceBusy = null;
      _updatePauseState = state;
    });
    _showMaintenanceResult(result);
  }

  Future<void> _repairShellIcons() async {
    final confirmed = await _confirmMaintenance(
      title: context.l10n.tr('repairShell'),
      message: context.l10n.tr('repairShellConfirm'),
      confirmLabel: context.l10n.tr('refreshAndRestart'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _maintenanceBusy = 'shell');
    final result = await SystemMaintenance.repairShellIcons();
    if (!mounted) return;
    setState(() => _maintenanceBusy = null);
    _showMaintenanceResult(result);
  }

  Future<void> _resumeWindowsUpdates() async {
    final confirmed = await _confirmMaintenance(
      title: context.l10n.tr('resumeUpdatesTitle'),
      message: context.l10n.tr('resumeUpdatesConfirm'),
      confirmLabel: context.l10n.tr('resumeUpdates'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _maintenanceBusy = 'updates');
    final result = await SystemMaintenance.resumeWindowsUpdates();
    final state = await SystemMaintenance.getUpdatePauseState();
    if (!mounted) return;
    setState(() {
      _maintenanceBusy = null;
      _updatePauseState = state;
    });
    _showMaintenanceResult(result);
  }

  void _showMaintenanceResult(MaintenanceResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.tr(result.success ? 'actionCompleted' : 'actionFailed'),
        ),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_refreshing) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            context.l10n.tr('stillChecking'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Icon(Icons.lightbulb, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              context.l10n.tr('recommendedForYou'),
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _refresh(force: true),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.l10n.tr('checkAgain')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._recs.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RecommendationCard(rec: r),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.build_circle_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              context.l10n.tr('maintenanceTools'),
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MaintenanceToolsCard(
          busy: _maintenanceBusy,
          updatePauseState: _updatePauseState,
          onPauseUpdates: _pauseWindowsUpdates,
          onResumeUpdates: _resumeWindowsUpdates,
          onRepairNetwork: _repairNetwork,
          onRepairShell: _repairShellIcons,
        ),
      ],
    );
  }
}

class _MaintenanceToolsCard extends StatelessWidget {
  final String? busy;
  final UpdatePauseState updatePauseState;
  final VoidCallback onPauseUpdates;
  final VoidCallback onResumeUpdates;
  final VoidCallback onRepairNetwork;
  final VoidCallback onRepairShell;

  const _MaintenanceToolsCard({
    required this.busy,
    required this.updatePauseState,
    required this.onPauseUpdates,
    required this.onResumeUpdates,
    required this.onRepairNetwork,
    required this.onRepairShell,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              updatePauseState.active
                  ? Icons.pause_circle
                  : Icons.pause_circle_outline,
              color: updatePauseState.active ? Colors.orange : null,
            ),
            title: Text(context.l10n.tr('pauseUpdates')),
            subtitle: Text(
              updatePauseState.active
                  ? context.l10n.tr('updatesPausedUntil')
                  : context.l10n.tr('pauseUntil'),
            ),
            trailing: busy == 'updates'
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : updatePauseState.active
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: busy == null ? onPauseUpdates : null,
                        child: Text(context.l10n.tr('reapply')),
                      ),
                      const SizedBox(width: 4),
                      OutlinedButton(
                        onPressed: busy == null ? onResumeUpdates : null,
                        child: Text(context.l10n.tr('resumeUpdates')),
                      ),
                    ],
                  )
                : OutlinedButton(
                    onPressed: busy == null ? onPauseUpdates : null,
                    child: Text(context.l10n.tr('pauseUpdates')),
                  ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.wifi_find),
            title: Text(context.l10n.tr('networkRepair')),
            trailing: busy == 'network'
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : OutlinedButton(
                    onPressed: busy == null ? onRepairNetwork : null,
                    child: Text(context.l10n.tr('repair')),
                  ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.desktop_windows_outlined),
            title: Text(context.l10n.tr('repairShell')),
            trailing: busy == 'shell'
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : OutlinedButton(
                    onPressed: busy == null ? onRepairShell : null,
                    child: Text(context.l10n.tr('repair')),
                  ),
          ),
        ],
      ),
    );
  }
}

enum _Severity { info, low, medium, high }

class _Recommendation {
  final IconData icon;
  final _Severity severity;
  final String title;
  final String desc;
  final String? action;
  const _Recommendation({
    required this.icon,
    required this.severity,
    required this.title,
    required this.desc,
    required this.action,
  });
}

class _RecommendationCard extends StatelessWidget {
  final _Recommendation rec;
  const _RecommendationCard({required this.rec});

  /// 映射推荐项 action 文本 → QuickJump 键名
  static const _actionMap = <String, String>{
    'openWindowsSecurity': 'Windows 安全中心',
    'openFirewall': '防火墙',
    'openWindowsUpdate': 'Windows 更新',
    'openStorage': '存储',
    'viewBatteryUsage': '电池使用情况',
  };

  static String _actionTarget(String action) => _actionMap[action] ?? action;

  Color _color() {
    switch (rec.severity) {
      case _Severity.high:
        return Colors.red;
      case _Severity.medium:
        return Colors.orange;
      case _Severity.low:
        return Colors.blue;
      case _Severity.info:
        return Colors.green;
    }
  }

  String _tag(BuildContext context) {
    switch (rec.severity) {
      case _Severity.high:
        return context.l10n.tr('highPriority');
      case _Severity.medium:
        return context.l10n.tr('recommended');
      case _Severity.low:
        return context.l10n.tr('optional');
      case _Severity.info:
        return context.l10n.tr('statusFine');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(rec.icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          rec.title,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _tag(context),
                          style: TextStyle(color: color, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(rec.desc, style: theme.textTheme.bodyMedium),
                  if (rec.action != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () =>
                          QuickJump.launch(_actionTarget(rec.action!)),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(context.l10n.tr(rec.action!)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: color.withValues(alpha: 0.5)),
                        foregroundColor: color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
