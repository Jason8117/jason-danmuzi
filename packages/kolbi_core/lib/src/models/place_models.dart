import 'package:meta/meta.dart';

import 'intake_models.dart';

/// The server's number check for a candidate (SPEC-PLACE-001 design.md D1). Unknown values read as [invalid].
enum PlacePhoneCheck { ok, invalid, blocked, missing }

/// Where the candidates came from; [unknown] hides the source line (future providers).
enum PlaceSearchSource { kakao, simulated, unknown }

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// One candidate of `POST /v1/places/search`. Kept only in memory, for one screen (REQ-004).
@immutable
class Place {
  const Place({
    required this.id,
    required this.name,
    this.category,
    this.address,
    this.distanceM,
    this.phone,
    this.phoneNumber,
    this.phoneCheck = PlacePhoneCheck.missing,
  });

  /// Null when [json] has no id or name (the candidate is skipped).
  static Place? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = _string(json['id']);
    final name = _string(json['name']);
    if (id == null || name == null) return null;
    final distance = json['distanceM'];
    return Place(
      id: id,
      name: name,
      category: _string(json['category']),
      address: _string(json['address']),
      distanceM: distance is num ? distance.round() : null,
      phone: _string(json['phone']),
      phoneNumber: _string(json['phoneNumber']),
      phoneCheck:
          PlacePhoneCheck.values
              .where((c) => c.name == json['phoneCheck'])
              .firstOrNull ??
          PlacePhoneCheck.invalid,
    );
  }

  /// Provider id; a screen key only, never stored.
  final String id;
  final String name;
  final String? category;
  final String? address;

  /// Whole metres; null without a position.
  final int? distanceM;

  /// The provider's text, for display.
  final String? phone;

  /// E.164 when [phoneCheck] is ok.
  final String? phoneNumber;
  final PlacePhoneCheck phoneCheck;

  /// Only a checked number may be chosen (REQ-013).
  bool get callable => phoneCheck == PlacePhoneCheck.ok && phoneNumber != null;
}

@immutable
class PlaceSearchResult {
  const PlaceSearchResult({required this.source, this.places = const []});

  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    final places = json['places'];
    return PlaceSearchResult(
      source:
          PlaceSearchSource.values
              .where(
                (s) =>
                    s != PlaceSearchSource.unknown && s.name == json['source'],
              )
              .firstOrNull ??
          PlaceSearchSource.unknown,
      places: places is List
          ? places.map(Place.tryParse).nonNulls.toList(growable: false)
          : const [],
    );
  }

  final PlaceSearchSource source;
  final List<Place> places;
}

/// What the assistant hands to place selection: the intake draft, the sentence and the first search.
@immutable
class PlaceSearchStart {
  const PlaceSearchStart({
    required this.draft,
    required this.requestText,
    required this.keyword,
    required this.nearby,
  });

  final PlanDraft draft;
  final String requestText;

  /// May be empty: the screen then waits for the user to type (REQ-010).
  final String keyword;

  /// "근처" request: the device position is asked for (REQ-016).
  final bool nearby;
}
