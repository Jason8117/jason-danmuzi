import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

// SPEC-PLACE-001 CMP-05 and the wording of design.md D7.

/// `350m` under a kilometre, `1.2km` above.
String formatDistance(int metres) =>
    metres < 1000 ? '${metres}m' : '${(metres / 1000).toStringAsFixed(1)}km';

/// What a screen reader says for [formatDistance].
String spokenDistance(int metres) =>
    metres < 1000 ? '$metres미터' : '${(metres / 1000).toStringAsFixed(1)}킬로미터';

/// The status word on the card (REQ-013).
String placeStatus(Place place) => switch (place.phoneCheck) {
  _ when place.callable => '걸 수 있음',
  PlacePhoneCheck.missing => '번호 없음',
  _ => '걸 수 없는 번호',
};

/// Why [여기로 전화] is disabled, or null when it is enabled (REQ-013).
String? placeBlockedReason(Place place) => place.callable
    ? null
    : place.phoneCheck == PlacePhoneCheck.missing
    ? '번호가 없어 전화할 수 없어요'
    : '걸 수 없는 번호예요';

/// "{이름}, {분류}, {거리}, {상태 글자}", leaving out what is missing (REQ-021).
String placeReadLabel(Place place) => [
  place.name,
  ?place.category,
  if (place.distanceM case final metres?) spokenDistance(metres),
  placeStatus(place),
].join(', ');

/// One candidate. The first callable one is highlighted and has the filled [여기로 전화].
class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.place,
    required this.highlighted,
    required this.nearest,
    required this.onDetail,
    required this.onCall,
    this.detailFocusNode,
  });

  final Place place;
  final bool highlighted;

  /// Only from the response: the first candidate when distances are known (design.md D7).
  final bool nearest;
  final VoidCallback onDetail;

  /// Null leaves [여기로 전화] disabled.
  final VoidCallback? onCall;
  final FocusNode? detailFocusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final reason = placeBlockedReason(place);
    final callLabel = const Text('여기로 전화');
    return Card(
      key: Key('place-card-${place.id}'),
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: highlighted
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              label: placeReadLabel(place),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(place.name, style: theme.textTheme.titleMedium),
                        if (nearest)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              '가장 가까워요',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Wrap(
                      spacing: AppSpace.sm,
                      children: [
                        if (place.category case final category?)
                          Text(category, style: muted),
                        if (place.distanceM case final metres?)
                          Text(formatDistance(metres), style: muted),
                        Text(
                          placeStatus(place),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: place.callable
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (place.address case final address?) ...[
                      const SizedBox(height: AppSpace.xs),
                      Text(address, style: muted),
                    ],
                    if (place.phone case final phone?) ...[
                      const SizedBox(height: AppSpace.xs),
                      Text(phone, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
            ),
            if (reason != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                reason,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  key: Key('place-detail-${place.id}'),
                  focusNode: detailFocusNode,
                  onPressed: onDetail,
                  child: const Text('상세'),
                ),
                if (highlighted)
                  FilledButton(
                    key: Key('place-call-${place.id}'),
                    onPressed: onCall,
                    child: callLabel,
                  )
                else
                  OutlinedButton(
                    key: Key('place-call-${place.id}'),
                    onPressed: onCall,
                    child: callLabel,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The grey card shown three times while searching.
class PlaceSkeletonCard extends StatelessWidget {
  const PlaceSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double width) => Container(
      width: width,
      height: 14,
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
    return ExcludeSemantics(
      child: Card(
        key: const Key('place-skeleton'),
        margin: const EdgeInsets.only(bottom: AppSpace.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [bar(160), bar(220), bar(120)],
          ),
        ),
      ),
    );
  }
}
