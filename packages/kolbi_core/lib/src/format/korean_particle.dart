/// [name] followed by 이 or 가, chosen by its last syllable's final consonant (design.md D5).
/// A name that does not end in a Hangul syllable gets "(이)가".
String withSubjectParticle(String name) {
  if (name.isEmpty) return name;
  final last = name.runes.last;
  if (last < 0xAC00 || last > 0xD7A3) return '$name(이)가';
  return (last - 0xAC00) % 28 == 0 ? '$name가' : '$name이';
}
