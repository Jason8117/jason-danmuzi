import 'package:characters/characters.dart';

import '../models/intake_models.dart';
import '../models/place_models.dart';

// SPEC-PLACE-001 design.md D6: the first search term and "근처", from the sentence and the intake draft.
// The user can always correct the term in the search field, so the rules stay small and predictable.

const _nearWords = ['근처', '주변'];
const _nearPrefixes = ['내', '여기', '이'];
const _timeWords = ['오늘', '내일', '모레', '이번', '다음'];
const _requestPrefixes = ['예약', '문의', '확인', '물어봐', '알아봐', '전화', '찾아', '부탁'];
const _requestWords = ['해', '해줘', '해주세요', '중에', '있는', '몇'];
const _requestSuffixes = ['까지', '하는지', '있는지', '줘', '주세요'];
const _placeParticles = ['에서', '에게', '에'];
const _trailingParticles = ['의', '을', '를'];
const _maxKeyword = 30;

final _countWord = RegExp(r'^\d+(시|분|명)');

bool _isNear(String word) => _nearWords.any(word.startsWith);

/// A date, time or head count ("금요일", "7시", "2명"), with or without a trailing particle.
bool _isWhen(String word) =>
    _timeWords.contains(word) ||
    _countWord.hasMatch(word) ||
    _stripPlace(word).endsWith('요일');

bool _isRequest(String word) =>
    _requestPrefixes.any(word.startsWith) ||
    _requestWords.contains(word) ||
    _requestSuffixes.any(word.endsWith);

String _stripPlace(String word) {
  for (final particle in _placeParticles) {
    if (word.length > particle.length && word.endsWith(particle)) {
      return word.substring(0, word.length - particle.length);
    }
  }
  return word;
}

String _stripTrailing(String word) {
  for (final particle in _trailingParticles) {
    if (word.length > particle.length && word.endsWith(particle)) {
      return word.substring(0, word.length - particle.length);
    }
  }
  return word;
}

List<String> _words(String text) =>
    text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

bool _nearby(List<String> words) {
  for (var i = 0; i < words.length; i++) {
    if (words[i].startsWith('가까운')) return true;
    if (_isNear(words[i]) && (i == 0 || _nearPrefixes.contains(words[i - 1]))) {
      return true;
    }
  }
  return false;
}

String _keywordFromSentence(String text) {
  final comma = text.indexOf(',');
  final head = comma == -1 ? text : text.substring(0, comma);
  final kept = <String>[];
  for (final word in _words(head)) {
    if (_isNear(word) ||
        word.startsWith('가까운') ||
        word == '내' ||
        word == '여기' ||
        _isWhen(word)) {
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
  final name = result.draft.targetName?.trim();
  final keyword = name != null && name.isNotEmpty
      ? _words(name).where((w) => !_isNear(w)).join(' ')
      : _keywordFromSentence(requestText);
  return PlaceSearchStart(
    draft: result.draft,
    requestText: requestText,
    keyword: _cap(keyword),
    nearby: _nearby(words),
  );
}
