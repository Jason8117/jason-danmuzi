import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

import 'package:kolbi_core/kolbi_core.dart';

/// Chat-style rendering of a call: the AI on the right, the other party on the left.
class TranscriptView extends StatelessWidget {
  const TranscriptView({super.key, required this.entries, required this.calleeName});

  final List<TranscriptEntry> entries;
  final String calleeName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [for (final entry in entries) _Bubble(entry: entry, calleeName: calleeName)],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.entry, required this.calleeName});

  final TranscriptEntry entry;
  final String calleeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (entry.speaker == Speaker.system) {
      // SPEC-UX-001 §8: the user's guidance lines read as a small centered pill; other system lines stay plain.
      final guidance = entry.text.startsWith('사용자 안내:') || entry.text.startsWith('User guidance:');
      if (guidance) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.record_voice_over_outlined, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpace.xs),
                  Flexible(
                    child: Text(entry.text, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface)),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Text(entry.text, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      );
    }

    final isAgent = entry.speaker == Speaker.agent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Column(
        crossAxisAlignment: isAgent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
            child: Text(
              isAgent ? 'AI 비서' : calleeName,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
              decoration: BoxDecoration(
                color: isAgent ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.lg),
                  topRight: const Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(isAgent ? AppRadius.lg : AppSpace.xs),
                  bottomRight: Radius.circular(isAgent ? AppSpace.xs : AppRadius.lg),
                ),
              ),
              child: Text(
                entry.text,
                style: theme.textTheme.bodyMedium?.copyWith(color: isAgent ? scheme.onPrimary : scheme.onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
