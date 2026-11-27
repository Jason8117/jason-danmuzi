import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the Pretendard SIL Open Font License 1.1 to the app's licence page (SPEC-DESIGN-001 REQ-005).
/// Call once at start-up; the app calls it from `main.dart` (SPEC-SHELL-001).
void registerKolbiFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'packages/kolbi_ui/assets/fonts/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const ['Pretendard'], text);
  });
}
