import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'common.dart';

/// CMP-37: today's briefing — a count headline, one sentence and a link (SPEC-SHELL-001 REQ-015).
class KolbiBriefingCard extends StatelessWidget {
  const KolbiBriefingCard({
    super.key,
    required this.title,
    required this.message,
    required this.linkLabel,
    required this.onLink,
  });

  final String title;
  final String message;
  final String linkLabel;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpace.xs),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(onPressed: onLink, child: Text(linkLabel)),
          ),
        ],
      ),
    );
  }
}
