import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/quick_jump.dart';

/// Responsive Windows privacy setting shortcuts used by Recommend.
class PrivacySettingsSection extends StatelessWidget {
  const PrivacySettingsSection({super.key});

  static const _items = [
    (Icons.location_on_outlined, 'location', 'locationDesc', '定位', Colors.red),
    (Icons.camera_alt_outlined, 'camera', 'cameraDesc', '相机', Colors.purple),
    (
      Icons.mic_none_outlined,
      'microphone',
      'microphoneDesc',
      '麦克风',
      Colors.indigo,
    ),
    (
      Icons.lock_outline,
      'driveEncryption',
      'driveEncryptionDesc',
      '磁盘加密',
      Colors.teal,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final columns = switch (availableWidth) {
          >= 1000 => 4,
          >= 560 => 2,
          _ => 1,
        };
        const spacing = 16.0;
        final cardWidth = (availableWidth - spacing * (columns - 1)) / columns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.tr('windowsPrivacySettings'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final item in _items)
                  SizedBox(
                    width: cardWidth,
                    child: _SettingsShortcutCard(
                      icon: item.$1,
                      title: context.l10n.tr(item.$2),
                      description: context.l10n.tr(item.$3),
                      color: item.$5,
                      onTap: () => QuickJump.launch(item.$4),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SettingsShortcutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _SettingsShortcutCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 124),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
