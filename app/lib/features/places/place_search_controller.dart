import 'package:flutter/foundation.dart';
import 'package:kolbi_core/kolbi_core.dart';

/// What place selection shows (SPEC-PLACE-001 plan.md A.3). Positions are never part of a state (REQ-017).
sealed class PlaceSearchState {
  const PlaceSearchState();
}

/// No search yet: the search term is empty and the field waits for the user.
class PlaceIdle extends PlaceSearchState {
  const PlaceIdle();
}

class PlaceLoading extends PlaceSearchState {
  const PlaceLoading(this.keyword);
  final String keyword;
}

/// Candidates arrived (possibly none).
class PlaceResults extends PlaceSearchState {
  const PlaceResults(this.keyword, this.source, this.places);
  final String keyword;
  final PlaceSearchSource source;
  final List<Place> places;

  bool get anyCallable => places.any((place) => place.callable);
}

/// The search failed; [unavailable] is the server's 503 (place search switched off, OD-2).
class PlaceFailed extends PlaceSearchState {
  const PlaceFailed(this.keyword, {this.unavailable = false});
  final String keyword;
  final bool unavailable;
}

/// Runs the searches of one place selection screen. Results live only in this object (REQ-004).
class PlaceSearchController extends ValueNotifier<PlaceSearchState> {
  PlaceSearchController({required this.repository, required this.start})
    : super(const PlaceIdle());

  final PlacesRepository repository;
  final PlaceSearchStart start;

  /// Bumped on every search, so a late answer for an older search (or after dispose) is ignored.
  int _generation = 0;
  bool _disposed = false;
  String _lastKeyword = '';

  /// The first search, from the request (REQ-010). An empty term searches nothing.
  void begin() {
    if (start.keyword.trim().isNotEmpty) search(start.keyword);
  }

  /// [다시 시도]: the last search again.
  void retry() => search(_lastKeyword);

  Future<void> search(
    String keyword, {
    ({double lat, double lng})? near,
  }) async {
    final query = keyword.trim();
    if (query.isEmpty) return;
    _lastKeyword = query;
    final generation = ++_generation;
    value = PlaceLoading(query);
    PlaceSearchState next;
    try {
      final result = await repository.search(query, near: near);
      next = PlaceResults(query, result.source, result.places);
    } on ApiException catch (error) {
      next = PlaceFailed(query, unavailable: error.statusCode == 503);
    } catch (_) {
      next = PlaceFailed(query);
    }
    if (_disposed || generation != _generation) return;
    value = next;
  }

  /// The plan card draft for [place]: the intake draft with only the target, number and source replaced
  /// (design.md D5). Null for a place that cannot be called (REQ-013).
  PlanDraft? draftFor(Place place) {
    if (!place.callable) return null;
    final draft = start.draft;
    return PlanDraft(
      goal: draft.goal,
      targetName: place.name,
      phoneNumber: place.phoneNumber,
      conditions: draft.conditions,
      context: draft.context,
      language: draft.language,
      phoneSource: PhoneSource.search,
      source: draft.source,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
