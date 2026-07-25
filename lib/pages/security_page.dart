import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/privacy_protection.dart';
import '../services/quick_jump.dart';

/// 可交互的 Windows 隐私保护套件。
class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  PrivacyProtectionState _state = PrivacyProtectionState.empty();
  bool _loading = true;
  bool _masterBusy = false;
  PrivacyFeature? _busyFeature;

  bool get _busy => _masterBusy || _busyFeature != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await PrivacyProtection.collect();
    if (!mounted) return;
    setState(() {
      _state = state;
      _loading = false;
    });
  }

  Future<void> _setFeature(PrivacyFeature feature, bool enabled) async {
    if (_busy) return;
    setState(() => _busyFeature = feature);
    final result = await PrivacyProtection.setFeature(feature, enabled);
    if (!mounted) return;
    setState(() {
      _state = result.state;
      _busyFeature = null;
    });
    _showResult(result);
  }

  Future<void> _setAll(bool enabled) async {
    if (_busy) return;
    setState(() => _masterBusy = true);
    final result = await PrivacyProtection.apply(
      microphone: enabled,
      camera: enabled,
      screenCapture: enabled,
    );
    if (!mounted) return;
    setState(() {
      _state = result.state;
      _masterBusy = false;
    });
    _showResult(result);
  }

  void _showResult(PrivacyApplyResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.tr(result.success ? 'privacySaved' : 'privacyFailed'),
        ),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    final enabledCount = [
      _state.microphoneProtected,
      _state.screenCaptureProtected,
      _state.cameraProtected,
    ].where((enabled) => enabled).length;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_state.allProtected ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _state.allProtected
                        ? Icons.privacy_tip
                        : Icons.privacy_tip_outlined,
                    size: 36,
                    color: _state.allProtected ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.tr('privacyProtection'),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _state.allProtected
                            ? context.l10n.tr('allProtectionsOn')
                            : context.l10n.tr('protectionCount', {
                                'count': enabledCount,
                              }),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (_masterBusy)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                else
                  Switch(
                    value: _state.allProtected,
                    onChanged: _busy ? null : _setAll,
                  ),
              ],
            ),
          ),
        ),
        if (_state.message != null) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(context.l10n.tr('privacyFailed')),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _ProtectionCard(
          icon: Icons.mic_off_outlined,
          title: context.l10n.tr('microphoneProtection'),
          description: context.l10n.tr('microphoneProtectionDesc'),
          impact: context.l10n.tr('microphoneProtectionImpact'),
          enabled: _state.microphoneProtected,
          busy: _busyFeature == PrivacyFeature.microphone,
          onChanged: _busy
              ? null
              : (value) => _setFeature(PrivacyFeature.microphone, value),
        ),
        const SizedBox(height: 12),
        _ProtectionCard(
          icon: Icons.screen_lock_landscape_outlined,
          title: context.l10n.tr('screenProtection'),
          description: context.l10n.tr('screenProtectionDesc'),
          impact: context.l10n.tr('screenProtectionImpact'),
          enabled: _state.screenCaptureProtected,
          busy: _busyFeature == PrivacyFeature.screenCapture,
          onChanged: _busy
              ? null
              : (value) => _setFeature(PrivacyFeature.screenCapture, value),
        ),
        const SizedBox(height: 12),
        _ProtectionCard(
          icon: Icons.videocam_off_outlined,
          title: context.l10n.tr('cameraProtection'),
          description: context.l10n.tr('cameraProtectionDesc'),
          impact: context.l10n.tr('cameraProtectionImpact'),
          enabled: _state.cameraProtected,
          busy: _busyFeature == PrivacyFeature.camera,
          onChanged: _busy
              ? null
              : (value) => _setFeature(PrivacyFeature.camera, value),
        ),
        const SizedBox(height: 16),
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 12),
                Expanded(child: Text(context.l10n.tr('privacyAdminNote'))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _PrivacySettingsCard(),
      ],
    );
  }
}

class _ProtectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String impact;
  final bool enabled;
  final bool busy;
  final ValueChanged<bool>? onChanged;

  const _ProtectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.impact,
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = enabled ? Colors.green : theme.colorScheme.outline;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 5),
                  Text(description, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Text(
                    impact,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Switch(value: enabled, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _PrivacySettingsCard extends StatelessWidget {
  static const _items = [
    (Icons.location_on, 'location', '定位', Colors.red),
    (Icons.camera_alt, 'camera', '相机', Colors.purple),
    (Icons.mic, 'microphone', '麦克风', Colors.indigo),
    (Icons.lock, 'driveEncryption', '磁盘加密', Colors.teal),
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
                  context.l10n.tr('windowsPrivacySettings'),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _items
                  .map(
                    (item) => ActionChip(
                      avatar: Icon(item.$1, size: 18, color: item.$4),
                      label: Text(context.l10n.tr(item.$2)),
                      onPressed: () => QuickJump.launch(item.$3),
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
