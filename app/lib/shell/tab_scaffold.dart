import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'navigation.dart';
import 'routes.dart';
import 'task_feed.dart';

/// Gives each tab's first screen the scroll controller the tab bar scrolls to the top (REQ-002).
class TabScrollScope extends InheritedWidget {
  const TabScrollScope({
    super.key,
    required this.controllers,
    required super.child,
  });

  final List<ScrollController> controllers;

  /// The controller for [tab], only when [context] is that tab's first screen (not a screen pushed on top).
  static ScrollController? rootControllerOf(BuildContext context, AppTab tab) {
    if (!(ModalRoute.of(context)?.isFirst ?? false)) return null;
    return context
        .dependOnInheritedWidgetOfExactType<TabScrollScope>()
        ?.controllers[tab.index];
  }

  @override
  bool updateShouldNotify(TabScrollScope oldWidget) =>
      controllers != oldWidget.controllers;
}

/// The four branch navigators, like `StatefulShellRoute.indexedStack`, plus [HeroMode] off in hidden
/// branches: each tab screen is a root Scaffold, so a snack bar's hero would otherwise exist once per branch.
class BranchStack extends StatelessWidget {
  const BranchStack({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: currentIndex,
    children: [
      for (final (index, child) in children.indexed)
        Offstage(
          offstage: index != currentIndex,
          child: TickerMode(
            enabled: index == currentIndex,
            child: HeroMode(enabled: index == currentIndex, child: child),
          ),
        ),
    ],
  );
}

/// The shell around the four tabs: CMP-01 (revised) with the centre assistant button, CMP-36.
class TabScaffold extends ConsumerStatefulWidget {
  const TabScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<TabScaffold> createState() => _TabScaffoldState();
}

class _TabScaffoldState extends ConsumerState<TabScaffold> {
  final _controllers = [for (final _ in AppTab.values) ScrollController()];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// design.md D1.2: another tab keeps its screens; the current tab goes to its first screen, and on the
  /// first screen scrolls to the top.
  void _onTab(AppTab tab) {
    final shell = widget.navigationShell;
    if (tab.index != shell.currentIndex) {
      shell.goBranch(tab.index);
      return;
    }
    if (GoRouter.of(context).state.uri.path != tab.path) {
      shell.goBranch(tab.index, initialLocation: true);
      return;
    }
    scrollToOffset(
      _controllers[tab.index],
      0,
      motionDuration(context, AppMotion.medium),
    );
  }

  @override
  Widget build(BuildContext context) {
    registerTabShell(GoRouter.of(context), widget.navigationShell);
    final badge = ref.watch(taskGroupsProvider.select((g) => g.badgeCount));
    // Not a Scaffold: each tab screen's own Scaffold stays the root one, so snack bars (the approval alert)
    // float above that screen's pinned area instead of over it.
    return Material(
      child: Column(
        children: [
          Expanded(
            // The screens above the tab bar see the height they actually get, so size-relative limits
            // (the pinned approval area, SPEC-UX-001 REQ-011) are measured against it.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final media = MediaQuery.of(context);
                return MediaQuery(
                  data: media
                      .copyWith(
                        size: Size(media.size.width, constraints.maxHeight),
                      )
                      .removePadding(removeBottom: true),
                  child: TabScrollScope(
                    controllers: _controllers,
                    child: widget.navigationShell,
                  ),
                );
              },
            ),
          ),
          _TabBar(
            current: AppTab.values[widget.navigationShell.currentIndex],
            badge: badge,
            onTab: _onTab,
            onAssistant: () => openAssistant(GoRouter.of(context)),
          ),
        ],
      ),
    );
  }
}

/// Ceiling for the tab labels' text scale (04 DOD-9 allows at most 1.5).
const _maxLabelScale = 1.3;

/// Every cell's icon area, so the centre button is no taller than a tab.
const double _iconBox = 28;

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.current,
    required this.badge,
    required this.onTab,
    required this.onAssistant,
  });

  final AppTab current;
  final int badge;
  final ValueChanged<AppTab> onTab;
  final VoidCallback onAssistant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    _TabItem item(
      AppTab tab,
      String label,
      IconData icon,
      IconData selectedIcon, {
      int badge = 0,
      String? semantics,
    }) => _TabItem(
      key: Key('tab-${tab.name}'),
      label: label,
      semanticsLabel: semantics ?? label,
      icon: icon,
      selectedIcon: selectedIcon,
      selected: tab == current,
      badge: badge,
      onTap: () => onTab(tab),
    );
    return Material(
      color: scheme.surfaceContainerLowest,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          // DOD-9: tab labels stop growing well inside the 1.5x ceiling, so they never wrap and the bar stays
          // short enough for a pinned approval card and its alert above it on a small phone.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: _maxLabelScale,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: item(
                    AppTab.today,
                    '오늘',
                    Icons.home_outlined,
                    Icons.home_rounded,
                  ),
                ),
                Expanded(
                  child: item(
                    AppTab.tasks,
                    '업무',
                    Icons.assignment_outlined,
                    Icons.assignment_rounded,
                    badge: badge,
                    semantics: badge > 0 ? '업무, 승인 대기 $badge개' : '업무',
                  ),
                ),
                Expanded(child: _AssistantButton(onTap: onAssistant)),
                Expanded(
                  child: item(
                    AppTab.history,
                    '기록',
                    Icons.history_rounded,
                    Icons.manage_history_rounded,
                  ),
                ),
                Expanded(
                  child: item(
                    AppTab.me,
                    '내 정보',
                    Icons.person_outline_rounded,
                    Icons.person_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: _iconBox,
                  child: Center(
                    child: KolbiTabBadge(
                      count: badge,
                      child: Icon(selected ? selectedIcon : icon, color: color),
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// CMP-36: not a tab, so it never has a selected state.
class _AssistantButton extends StatelessWidget {
  const _AssistantButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      key: const Key('assistant-button'),
      container: true,
      button: true,
      label: '비서 부르기',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: _iconBox,
                  height: _iconBox,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: scheme.onPrimary,
                    size: 18,
                  ),
                ),
                Text(
                  '비서',
                  maxLines: 1,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
