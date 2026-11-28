import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:material_ui/material_ui.dart';

/// SCR-H02 place selection, `/assistant/places` (SPEC-PLACE-001 REQ-011).
class PlaceSearchScreen extends ConsumerStatefulWidget {
  const PlaceSearchScreen({super.key, required this.start});

  final PlaceSearchStart start;

  @override
  ConsumerState<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends ConsumerState<PlaceSearchScreen> {
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('장소 선택')));
}
