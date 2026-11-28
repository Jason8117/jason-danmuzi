import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../shell/navigation.dart';
import '../../shell/place_search.dart';
import 'location_consent_sheet.dart';
import 'place_card.dart';
import 'place_detail_sheet.dart';
import 'place_search_controller.dart';

/// [word] followed by 을 or 를, by its last syllable's final consonant; "(을)를" otherwise.
String withObjectParticle(String word) {
  if (word.isEmpty) return word;
  final last = word.runes.last;
  if (last < 0xAC00 || last > 0xD7A3) return '$word을(를)';
  return (last - 0xAC00) % 28 == 0 ? '$word를' : '$word을';
}

/// SCR-H02 place selection, `/assistant/places` (SPEC-PLACE-001 REQ-011, REQ-012). It sits over the
/// assistant; the plan card it opens sits over it, so back returns here with the same candidates.
class PlaceSearchScreen extends ConsumerStatefulWidget {
  const PlaceSearchScreen({super.key, required this.start});

  final PlaceSearchStart start;

  @override
  ConsumerState<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends ConsumerState<PlaceSearchScreen> {
  late final _keyword = TextEditingController(text: widget.start.keyword);
  final _area = TextEditingController();
  final _keywordFocus = FocusNode(debugLabel: 'place-search-field');
  final _detailFocus = <String, FocusNode>{};
  late final PlaceSearchController _controller;
  PlaceSearchState? _announced;

  @override
  void initState() {
    super.initState();
    _controller = PlaceSearchController(
      repository: ref.read(placesRepositoryProvider),
      location: ref.read(locationReaderProvider),
      start: widget.start,
    )..addListener(_onState);
    _controller.begin();
    if (widget.start.keyword.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _keywordFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onState)
      ..dispose();
    _keyword.dispose();
    _area.dispose();
    _keywordFocus.dispose();
    for (final node in _detailFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onState() {
    final state = _controller.value;
    // REQ-021: the result sentence is announced once per finished search, politely.
    if (state is PlaceResults && !identical(state, _announced) && mounted) {
      _announced = state;
      SemanticsService.sendAnnouncement(
        View.of(context),
        _resultSentence(state),
        TextDirection.ltr,
        assertiveness: Assertiveness.polite,
      );
    }
  }

  String _resultSentence(PlaceResults state) =>
      '${state.keyword} ${state.places.length}곳을 찾았어요';

  void _searchAgain() {
    FocusScope.of(context).unfocus();
    _controller.search(_keyword.text);
  }

  void _choose(Place place) {
    final draft = _controller.draftFor(place);
    if (draft != null) openAssistantPlan(GoRouter.of(context), draft);
  }

  Future<void> _openDetail(Place place) async {
    final ask = await PlaceDetailSheet.show(context, place);
    if (!mounted) return;
    if (ask) {
      _choose(place);
    } else {
      // REQ-014: focus returns to the [상세] button that opened the sheet.
      _detailFocus[place.id]?.requestFocus();
    }
  }

  FocusNode _detailNode(String id) => _detailFocus.putIfAbsent(
    id,
    () => FocusNode(debugLabel: 'place-detail-button-$id'),
  );

  List<Widget> _content(ThemeData theme, PlaceSearchState state) {
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    switch (state) {
      case PlaceIdle():
        return const [];
      case PlaceNeedLocation():
        return [LocationConsentSheet(onContinue: _controller.acceptLocation)];
      case PlaceAskArea(:final foreverDenied):
        void searchArea() {
          if (_area.text.trim().isEmpty) return;
          FocusScope.of(context).unfocus();
          _controller.searchArea(_area.text, _keyword.text);
        }
        return [
          Text('동네 이름을 알려 주세요', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('place-area-field'),
                  controller: _area,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(hintText: '예: 망원동'),
                  onSubmitted: (_) => searchArea(),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              FilledButton(
                key: const Key('place-area-search'),
                onPressed: searchArea,
                child: const Text('찾기'),
              ),
            ],
          ),
          if (foreverDenied) ...[
            const SizedBox(height: AppSpace.md),
            Text('설정에서 위치 권한을 켜면 근처를 찾을 수 있어요', style: muted),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('location-open-settings'),
                onPressed: _controller.openSettings,
                child: const Text('설정 열기'),
              ),
            ),
          ],
        ];
      case PlaceLoading(:final keyword):
        return [
          Text(
            '${withObjectParticle(keyword)} 찾는 중이에요',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpace.md),
          for (var i = 0; i < 3; i++) const PlaceSkeletonCard(),
        ];
      case PlaceFailed(:final unavailable):
        return [
          Text(
            unavailable ? '지금은 장소 찾기를 쓸 수 없어요' : '장소를 찾지 못했어요. 잠시 뒤 다시 시도해 주세요',
            style: theme.textTheme.bodyLarge,
          ),
          if (!unavailable) ...[
            const SizedBox(height: AppSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: _controller.retry,
                child: const Text('다시 시도'),
              ),
            ),
          ],
        ];
      case PlaceResults(:final places) when places.isEmpty:
        return [Text('조건에 맞는 곳을 찾지 못했어요', style: theme.textTheme.bodyLarge)];
      case PlaceResults(:final places, :final source):
        final firstCallable = places.where((p) => p.callable).firstOrNull;
        return [
          Text(_resultSentence(state), style: theme.textTheme.titleSmall),
          if (!state.anyCallable) ...[
            const SizedBox(height: AppSpace.xs),
            Text('전화할 수 있는 곳이 없어요', style: theme.textTheme.bodyLarge),
          ],
          const SizedBox(height: AppSpace.md),
          for (final (index, place) in places.indexed)
            PlaceCard(
              place: place,
              highlighted: identical(place, firstCallable),
              nearest: index == 0 && place.distanceM != null,
              detailFocusNode: _detailNode(place.id),
              onDetail: () => _openDetail(place),
              onCall: place.callable ? () => _choose(place) : null,
            ),
          if (switch (source) {
                PlaceSearchSource.kakao => '장소 정보는 카카오 로컬 검색 결과예요',
                PlaceSearchSource.simulated => '연습용 장소예요. 실제 가게가 아니에요',
                PlaceSearchSource.unknown => null,
              }
              case final line?)
            Text(line, style: muted),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final router = GoRouter.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('장소 선택')),
      body: ResponsiveBody(
        child: ValueListenableBuilder<PlaceSearchState>(
          valueListenable: _controller,
          builder: (context, state, _) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.sm,
              AppSpace.xl,
              AppSpace.xxl,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '✦ ${widget.start.requestText}',
                      key: const Key('place-request-line'),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => router.pop(),
                    child: const Text('고치기'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('place-search-field'),
                      controller: _keyword,
                      focusNode: _keywordFocus,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(hintText: '어디에 전화할까요?'),
                      onSubmitted: (_) => _searchAgain(),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  FilledButton.tonal(
                    key: const Key('place-search-again'),
                    onPressed: _searchAgain,
                    child: const Text('다시 찾기'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              ..._content(theme, state),
              const SizedBox(height: AppSpace.lg),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('찾는 곳이 없나요?', style: theme.textTheme.bodyMedium),
                  TextButton(
                    key: const Key('place-manual'),
                    onPressed: () =>
                        openAssistantPlan(router, widget.start.draft),
                    child: const Text('번호 직접 입력'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
