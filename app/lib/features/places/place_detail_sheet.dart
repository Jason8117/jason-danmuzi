import 'package:flutter/services.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'place_card.dart';

/// SCR-H03 / CMP-06 (SPEC-PLACE-001 REQ-014). Pops with `true` when the user asks to call this place.
class PlaceDetailSheet extends StatefulWidget {
  const PlaceDetailSheet({super.key, required this.place});

  final Place place;

  /// Shows the sheet; resolves to true for [여기에 물어보기].
  static Future<bool> show(BuildContext context, Place place) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => PlaceDetailSheet(place: place),
      ) ??
      false;

  @override
  State<PlaceDetailSheet> createState() => _PlaceDetailSheetState();
}

class _PlaceDetailSheetState extends State<PlaceDetailSheet> {
  final _title = FocusNode(debugLabel: 'place-detail-title');

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final place = widget.place;
    final summary = [
      ?place.category,
      if (place.distanceM case final metres?) formatDistance(metres),
    ].join(' · ');
    final reason = placeBlockedReason(place);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          0,
          AppSpace.xl,
          AppSpace.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Focus(
              focusNode: _title,
              autofocus: true,
              child: Semantics(
                header: true,
                child: Text(place.name, style: theme.textTheme.titleLarge),
              ),
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: AppSpace.xs),
              Text(summary, style: muted),
            ],
            if (place.address case final address?) ...[
              const SizedBox(height: AppSpace.md),
              Text(address, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: AppSpace.md),
            if (place.phone case final phone?)
              Row(
                children: [
                  Expanded(
                    child: Text(phone, style: theme.textTheme.bodyLarge),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: phone));
                      if (context.mounted) {
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          const SnackBar(content: Text('번호를 복사했어요')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('번호 복사'),
                  ),
                ],
              )
            else
              Text(placeStatus(place), style: muted),
            if (reason != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(reason, style: muted),
            ],
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              key: const Key('place-ask'),
              onPressed: place.callable
                  ? () => Navigator.of(context).pop(true)
                  : null,
              child: const Text('여기에 물어보기'),
            ),
            const SizedBox(height: AppSpace.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }
}
