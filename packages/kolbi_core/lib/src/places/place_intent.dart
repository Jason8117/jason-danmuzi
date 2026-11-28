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
const _requestPrefixes = ['예약', '문의', '확인', '물어봐', '알아봐', '전화', '찾아', '부탁'];
const _requestWords = ['해', '해줘', '해주세요', '중에', '있는', '몇'];
const _requestSuffixes = ['까지', '하는지', '있는지', '줘', '주세요'];
const _placeParticles = ['에서', '에게', '에'];
const _trailingParticles = ['의', '을', '를'];
const _maxKeyword = 30;

final _countWord = RegExp(r'^\d+(시|분|명|일|월|주)');

/// An hour ("3시") that a spaced "반" ("3시 반에") belongs to.
final _hourWord = RegExp(r'^\d+시$');

bool _isNear(String word) => _nearWords.any(word.startsWith);

/// A date, time or head count ("금요일", "오전", "3시반에", "2명"), with or without one trailing particle.
bool _isWhen(String word) =>
    _timeWords.contains(word) ||
    _timeWords.contains(_strip(word, _whenParticles)) ||
    _countWord.hasMatch(word) ||
    _stripPlace(word).endsWith('요일');

/// A time word at [i], including a spaced half hour ("3시 반에", "10시 반쯤") right after an hour.
bool _isWhenAt(List<String> words, int i) =>
    _isWhen(words[i]) ||
    (i > 0 &&
        _hourWord.hasMatch(words[i - 1]) &&
        _strip(words[i], _whenParticles) == '반');

bool _isRequest(String word) =>
    _requestPrefixes.any(word.startsWith) ||
    _requestWords.contains(word) ||
    _requestSuffixes.any(word.endsWith);

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

List<String> _words(String text) =>
    text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

bool _nearby(List<String> words) {
  for (var i = 0; i < words.length; i++) {
    if (words[i].startsWith('가까운')) return true;
    if (!_isNear(words[i])) continue;
    // Only time words before "근처" ("내일 저녁에 근처 …") still mean "near me"; a place name does not.
    var before = i - 1;
    while (before >= 0 && _isWhenAt(words, before)) {
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
        _isWhenAt(words, i)) {
      continue;
    }
    if (_isRequest(word)) break;
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
