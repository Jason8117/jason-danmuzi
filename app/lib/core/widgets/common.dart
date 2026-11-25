import 'package:material_ui/material_ui.dart';

import '../network/api_client.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Keeps content readable on tablets and the web without changing phone layouts.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 720, this.shrinkHeight = false});

  final Widget child;
  final double maxWidth;

  /// Use for bars (e.g. `bottomNavigationBar`) that must only be as tall as their content.
  final bool shrinkHeight;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: shrinkHeight ? 1 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// The one card every screen uses (SPEC-UX-001 REQ-004): an optional header row (icon, title, trailing),
/// the body, an optional action row, and a [tone] that sets background, border and header-icon colors.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.actions,
    this.tone = CardTone.neutral,
    this.color,
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  /// Shown under the body, separated by [AppSpace.lg].
  final Widget? actions;
  final CardTone tone;

  /// Overrides the tone's background; kept for older call sites.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme.tone(tone);
    final attention = tone == CardTone.attention;
    return Card(
      color: color ?? (tone == CardTone.neutral ? null : colors.background),
      shape: attention
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: BorderSide(color: colors.accent),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null || icon != null || trailing != null) ...[
              Row(
                children: [
                  if (icon != null) ...[Icon(icon, size: 18, color: colors.accent), const SizedBox(width: AppSpace.sm)],
                  Expanded(
                    child: title == null
                        ? const SizedBox.shrink()
                        : Text(
                            title!,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: tone == CardTone.neutral ? null : colors.foreground,
                            ),
                          ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: AppSpace.md),
            ],
            child,
            if (actions != null) ...[const SizedBox(height: AppSpace.lg), actions!],
          ],
        ),
      ),
    );
  }
}

/// Older name for [AppCard]; takes the same arguments so existing call sites keep compiling.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.color,
    this.tone = CardTone.neutral,
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final Color? color;
  final CardTone tone;

  @override
  Widget build(BuildContext context) =>
      AppCard(title: title, icon: icon, trailing: trailing, color: color, tone: tone, child: child);
}

class BulletList extends StatelessWidget {
  const BulletList(this.items, {super.key, this.numbered = false});

  final List<String> items;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, item) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AppSpace.xxl,
                  child: Text(
                    numbered ? '${i + 1}.' : '•',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// The one empty-state widget (REQ-008): icon, one-line title, description, at most two actions.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.xl),
              decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: AppSpace.xl),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpace.xxl),
              Wrap(spacing: AppSpace.md, runSpacing: AppSpace.md, alignment: WrapAlignment.center, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

/// A softly pulsing dot used for "live" indicators.
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: AppMotion.pulse);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // REQ-006: reduced motion stops the pulse and keeps the dot fully visible.
    if (motionDuration(context, AppMotion.pulse) == Duration.zero) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_controller),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Runs a user-triggered action and reports a failure as a snackbar. Returns whether it succeeded.
Future<bool> runWithFeedback(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(describeError(error))));
    return false;
  }
}

String describeError(Object error) => error is ApiException ? error.userMessage : '문제가 생겼어요. 잠시 후 다시 시도해 주세요.';
