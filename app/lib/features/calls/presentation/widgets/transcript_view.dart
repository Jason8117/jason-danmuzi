import 'package:material_ui/material_ui.dart';

import '../../domain/call_models.dart';

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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(entry.text, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      );
    }

    final isAgent = entry.speaker == Speaker.agent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: isAgent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              isAgent ? 'AI 비서' : calleeName,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isAgent ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isAgent ? 18 : 4),
                  bottomRight: Radius.circular(isAgent ? 4 : 18),
                ),
              ),
              child: Text(
                entry.text,
                style: theme.textTheme.bodyMedium?.copyWith(color: isAgent ? scheme.onPrimary : scheme.onSurface, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
