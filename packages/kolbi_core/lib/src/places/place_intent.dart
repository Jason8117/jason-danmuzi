import 'package:characters/characters.dart';

import '../models/intake_models.dart';
import '../models/place_models.dart';

// SPEC-PLACE-001 design.md D6: the first search term and "근처", from the sentence and the intake draft.
// The user can always correct the term in the search field, so the rules stay small and predictable.
// The server's intake gives `placeQuery` first (D10); the sentence rule below is the fallback for older servers and
// mirrors server/src/domain/placeQuery.ts with the same example table. Change both together.

const _nearWords = ['근처', '주변'];
const _nearPrefixes = ['내', '여기', '이'];
const _timeWords = [
  '오늘',
  '내일',
  '모레',
  '이번',
  '다음',
  '오전',
  '오후',
  '아침',
  '점심',
  '저녁',
  '밤',
  '새벽',
  '주말',
  '평일',
  '이따',
  '이따가',
  '지금',
  '주',
  '이번주',
  '다음주',
];
const _whenParticles = ['에서', '에게', '에는', '에', '엔', '은', '는', '까지', '부터', '쯤'];
const _requestPrefixes = [
  '예약',
  '문의',
  '확인',
  '물어봐',
  '알아봐',
  '전화',
  '찾아',
  '부탁',
  '가능',
];
const _requestWords = [
  '해', '해줘', '해주세요', '중에', '있는', '몇',
  // Questions and availability ("자리 있어?", "되나요") end the term, and so does what is asked about the place.
  '있어',
  '있어요',
  '있나',
  '있나요',
  '있을까',
  '있을까요',
  '되나',
  '되나요',
  '돼',
  '돼요',
  '될까',
  '될까요',
  '하나요',
  '해요',
  '자리', '좌석', '가격', '메뉴', '영업시간', '문',
];
// Quoted speech ("늦는다고", "가자고") is the message, not the place: it ends the term.
const _requestSuffixes = [
  '까지',
  '하는지',
  '있는지',
  '줘',
  '주세요',
  '다고',
  '라고',
  '냐고',
  '자고',
];

/// Endings that only count on a longer word, so "한지 공방" keeps its name while "가능한지" stops.
const _longRequestSuffixes = ['한지', '나요'];

/// A reason clause ("엄마 생신이라") comes before the place; what was kept so far is dropped.
const _reasonEndings = ['이라서', '이라', '라서', '니까'];

// Place and person particles ("꽃집에", "엄마한테", "대리님께"); longest first.
const _placeParticles = ['한테서', '께서', '에서', '에게', '한테', '에', '께'];
const _trailingParticles = ['의', '을', '를'];
const _maxKeyword = 30;

final _countWord = RegExp(r'^\d+(시|분|명|일|월|주)');

/// Who comes along ("가족과 함께", "친구랑 같이") is not the place.
const _companionWords = ['함께', '같이'];
const _companionEndings = ['하고', '과', '와', '랑'];

/// Adnominal verbs that lead into the place ("함께 갈 근처 고깃집", "같이 먹을 초밥집").
const _adnominalVerbs = ['갈', '올', '먹을', '마실', '모일', '놀', '묵을', '다닐'];

/// "부모님 모시고", "아이 데리고": the word before them is who comes along.
const _escortWords = ['모시고', '데리고'];

/// "24시 약국" is a category, not a time.
const _allDay = '24시';

/// An hour ("3시") that a spaced "반" ("3시 반에") belongs to.
final _hourWord = RegExp(r'^\d+시$');

bool _isNear(String word) => _nearWords.any(word.startsWith);

/// A date, time or head count ("금요일", "오전", "3시반에", "2명"), with or without one trailing particle.
bool _isWhen(String word) =>
    word != _allDay &&
    (_timeWords.contains(word) ||
        _timeWords.contains(_strip(word, _whenParticles)) ||
        _countWord.hasMatch(word) ||
        _stripPlace(word).endsWith('요일'));

/// A time word at [i], including a spaced half hour ("3시 반에", "10시 반쯤") right after an hour.
bool _isWhenAt(List<String> words, int i) =>
    _isWhen(words[i]) ||
    (i > 0 &&
        _hourWord.hasMatch(words[i - 1]) &&
        _strip(words[i], _whenParticles) == '반');

/// A companion phrase ("함께", "같이", or "가족과"/"친구랑" right before one) or an adnominal verb ("갈", "먹을").
bool _isCompanionAt(List<String> words, int i) =>
    _companionWords.contains(words[i]) ||
    _adnominalVerbs.contains(words[i]) ||
    _escortWords.contains(words[i]) ||
    (i + 1 < words.length && _escortWords.contains(words[i + 1])) ||
    (i + 1 < words.length &&
        (_companionWords.contains(words[i + 1]) ||
            _adnominalVerbs.contains(words[i + 1])) &&
        _companionEndings.any(
          (e) => words[i].length > e.length && words[i].endsWith(e),
        ));

/// Words that sit between "근처" or the place and the rest: time words and companion phrases.
bool _isFillerAt(List<String> words, int i) =>
    _isWhenAt(words, i) || _isCompanionAt(words, i);

bool _isRequest(String word) =>
    _requestPrefixes.any(word.startsWith) ||
    _requestWords.contains(word) ||
    _requestSuffixes.any(word.endsWith) ||
    _longRequestSuffixes.any((s) => word.length > s.length && word.endsWith(s));

String _strip(String word, List<String> particles) {
  for (final particle in particles) {
    if (word.length > particle.length && word.endsWith(particle)) {
      return word.substring(0, word.length - particle.length);
    }
  }
  return word;
}

String _stripPlace(String word) => _strip(word, _placeParticles);

String _stripTrailing(String word) => _strip(word, _trailingParticles);

/// Words without trailing "?", ".", "!" or "~" ("있어?" → "있어").
List<String> _words(String text) => text
    .trim()
    .split(RegExp(r'\s+'))
    .map((w) => w.replaceAll(RegExp(r'[?.!~]+$'), ''))
    .where((w) => w.isNotEmpty)
    .toList();

bool _nearby(List<String> words) {
  for (var i = 0; i < words.length; i++) {
    if (words[i].startsWith('가까운')) return true;
    if (!_isNear(words[i])) continue;
    // Only time words before "근처" ("내일 저녁에 근처 …") still mean "near me"; a place name does not.
    var before = i - 1;
    while (before >= 0 && _isFillerAt(words, before)) {
      before--;
    }
    if (before < 0 || _nearPrefixes.contains(words[before])) return true;
  }
  return false;
}

String _keywordFromSentence(String text) {
  final comma = text.indexOf(',');
  final head = comma == -1 ? text : text.substring(0, comma);
  final kept = <String>[];
  final words = _words(head);
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    if (_isNear(word) ||
        word.startsWith('가까운') ||
        word == '내' ||
        word == '여기' ||
        _isFillerAt(words, i)) {
      continue;
    }
    if (_isRequest(word)) break;
    if (_reasonEndings.any((e) => word.length > e.length && word.endsWith(e))) {
      kept.clear();
      continue;
    }
    final stripped = _stripPlace(word);
    if (stripped != word) {
      kept.add(stripped);
      break;
    }
    kept.add(word);
  }
  return kept.map(_stripTrailing).join(' ');
}

String _cap(String keyword) {
  final chars = keyword.characters;
  return chars.length > _maxKeyword
      ? chars.take(_maxKeyword).toString()
      : keyword;
}

/// Where the assistant goes after intake: place selection when the number is missing and not blocked
/// (SPEC-PLACE-001 REQ-009, OD-6), otherwise null and the plan card opens as before.
// @MX:NOTE: [AUTO] Person names ("엄마") also become Kakao search terms; the owner accepted this risk (OD-6, plan.md §D).
// @MX:SPEC: SPEC-PLACE-001
PlaceSearchStart? placeSearchStartFor(String requestText, IntakeResult result) {
  if (!result.missing.contains('phoneNumber') || result.draft.numberBlocked) {
    return null;
  }
  final words = _words(requestText);
  final served = result.placeQuery?.trim();
  final name = result.draft.targetName?.trim();
  final keyword = served != null && served.isNotEmpty
      ? served
      : name != null && name.isNotEmpty
      ? _words(name).where((w) => !_isNear(w)).join(' ')
      : _keywordFromSentence(requestText);
  return PlaceSearchStart(
    draft: result.draft,
    requestText: requestText,
    keyword: _cap(keyword),
    nearby: _nearby(words),
  );
}
