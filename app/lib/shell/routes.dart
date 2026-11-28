/// Route names; features navigate by these names, never by path literals (SPEC-SHELL-001 REQ-004).
abstract final class RouteNames {
  static const today = 'today';
  static const newCall = 'new-call';
  static const plan = 'plan';
  static const inbox = 'inbox';
  static const task = 'task';
  static const history = 'history';
  static const me = 'me';
  static const settings = 'settings';
  static const assistant = 'assistant';

  // SPEC-ASSIST-001 REQ-009: screens opened from the assistant are its child routes (research R1-G3).
  static const assistantPlan = 'assistant-plan';
  static const assistantSettings = 'assistant-settings';
  static const assistantNew = 'assistant-new';

  /// SPEC-ASSIST-001 REQ-011: the live call screen, outside the tab shell.
  static const liveCall = 'live-call';
}

/// The four tabs, in branch order; the centre assistant button is not a tab (design.md D1.1).
enum AppTab {
  today('/'),
  tasks('/inbox'),
  history('/history'),
  me('/me');

  const AppTab(this.path);

  /// The tab's first screen.
  final String path;
}
