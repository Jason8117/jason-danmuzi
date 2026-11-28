/// The device location as place selection needs it (SPEC-PLACE-001 design.md D8).
enum LocationAccess {
  notDetermined,
  granted,
  denied,
  deniedForever,
  unavailable,
}

/// The port between place selection and the location plugin; tests use a fake.
abstract interface class LocationReader {
  /// The current permission state, without asking.
  Future<LocationAccess> access();

  /// Shows the OS dialog.
  Future<LocationAccess> request();

  /// One rough position, or null when it fails or takes longer than [timeLimit].
  Future<({double lat, double lng})?> readOnce({
    Duration timeLimit = const Duration(seconds: 10),
  });

  Future<void> openSettings();
}
