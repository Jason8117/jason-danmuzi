import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/app_settings.dart';
import '../../shell/routes.dart';
import '../../shell/tab_scaffold.dart';

/// "010-1234-5678" → "010-****-5678": the first three and last four digits, the middle hidden.
String maskCallbackNumber(String number) {
  final digits = number.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8) return digits.isEmpty ? '' : '*' * digits.length;
  final middle = digits.length - 7;
  return '${digits.substring(0, 3)}-${'*' * middle}-${digits.substring(digits.length - 4)}';
}

/// SCR-M01: profile card, then the design.md D6 groups (SPEC-SHELL-001 REQ-017). Only the profile card and
/// "서버 연결(개발용)" open settings; every other item is shown, disabled, as "곧 쓸 수 있어요".
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  static const _groups = [
    ('비서', ['연결 앱 · 스킬', '연락처', '기억', '맡기는 방식']),
    ('권한과 안전', ['권한 설정', '알림', '안전하게 쓰는 법']),
    ('앱', ['화면 · 언어', _server, '문의 · 신고', '계정']),
  ];
  static const _server = '서버 연결(개발용)';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    void openSettings() => context.pushNamed(RouteNames.settings);
    return Scaffold(
      key: const Key('me-screen'),
      appBar: AppBar(title: const Text('내 정보')),
      body: ResponsiveBody(
        child: ListView(
          controller: TabScrollScope.rootControllerOf(context, AppTab.me),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.xs,
            AppSpace.lg,
            AppSpace.xxl,
          ),
          children: [
            _ProfileCard(settings: settings, onTap: openSettings),
            for (final (title, items) in _groups) ...[
              _GroupTitle(title),
              AppCard(
                child: Column(
                  children: [
                    for (final item in items)
                      _MeItem(
                        key: Key('me-item-$item'),
                        label: item,
                        onTap: item == _server ? openSettings : null,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.settings, required this.onTap});

  final AppSettings settings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final number = maskCallbackNumber(settings.callbackNumber);
    return Card(
      key: const Key('me-profile'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.person_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: settings.hasProfile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settings.requesterName,
                            style: theme.textTheme.titleMedium,
                          ),
                          if (number.isNotEmpty)
                            Text(
                              number,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      )
                    : Text('내 정보를 입력해 주세요', style: theme.textTheme.titleMedium),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xs,
        AppSpace.xl,
        AppSpace.xs,
        AppSpace.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _MeItem extends StatelessWidget {
  const _MeItem({super.key, required this.label, this.onTap});

  final String label;

  /// Null: shown but not available yet.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    // Disabled items keep readable colors (not the faded disabled style), so they pass the contrast check.
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: enabled ? label : '$label, 곧 쓸 수 있어요',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
            child: Row(
              children: [
                Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
                if (enabled)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  )
                else
                  Text(
                    '곧 쓸 수 있어요',
                    style: theme.textTheme.labelSmall?.copyWith(
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
