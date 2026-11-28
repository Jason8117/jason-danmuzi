import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolbi_core/kolbi_core.dart';

import '../features/calls/data/calls_repository.dart';

// SPEC-PLACE-001 design.md D5: the places feature reaches the server through the shell, like request_intake.

/// `POST /v1/places/search` over the app's API client. Tests override it with a fake.
final placesRepositoryProvider = Provider<PlacesRepository>(
  (ref) => PlacesRepository(ref.watch(apiClientProvider)),
);
