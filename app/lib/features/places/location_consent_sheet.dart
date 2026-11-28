import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

// SPEC-PLACE-001 CMP-23 for location (REQ-016). The assistant's microphone notice has the same shape, but
// features never import each other, so this one lives here.

const locationPurpose =
    '근처 가게를 찾으려면 지금 위치가 필요해요. 가까운 가게를 찾는 데만 써요. 콜비는 위치를 저장하지 않아요.';

/// The purpose notice; the OS dialog appears only after [계속] (OD-1).
class LocationConsentSheet extends StatelessWidget {
  const LocationConsentSheet({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.near_me_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(locationPurpose, style: theme.textTheme.bodyLarge),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('location-consent-continue'),
              onPressed: onContinue,
              child: const Text('계속'),
            ),
          ),
        ],
      ),
    );
  }
}
