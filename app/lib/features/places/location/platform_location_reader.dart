import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

import 'location_reader.dart';

/// [LocationReader] over `geolocator` (OD-8): rough accuracy, one reading, foreground only. It runs on iOS
/// and Android only (the platforms with location declarations). Anywhere else — web, desktop and the
/// widget-test host, where a plugin call never answers — it reports [LocationAccess.unavailable] without
/// touching the plugin; so does a missing plugin or switched-off location services.
// @MX:NOTE: [AUTO] The only file that imports geolocator (architecture_test AC-017); the position is returned, never kept.
// @MX:SPEC: SPEC-PLACE-001
class PlatformLocationReader implements LocationReader {
  PlatformLocationReader({bool? supported})
    : _supported =
          supported ?? (!kIsWeb && (Platform.isIOS || Platform.isAndroid));

  final bool _supported;

  // `denied` from checkPermission also means "not asked yet" (Android cannot tell them apart), so the
  // purpose notice is shown again; the OS decides whether its dialog still appears.
  static LocationAccess _fromCheck(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse => LocationAccess.granted,
        LocationPermission.denied => LocationAccess.notDetermined,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        LocationPermission.unableToDetermine => LocationAccess.unavailable,
      };

  static LocationAccess _fromRequest(LocationPermission permission) =>
      permission == LocationPermission.denied
      ? LocationAccess.denied
      : _fromCheck(permission);

  @override
  Future<LocationAccess> access() async {
    if (!_supported) return LocationAccess.unavailable;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationAccess.unavailable;
      }
      return _fromCheck(await Geolocator.checkPermission());
    } catch (_) {
      return LocationAccess.unavailable;
    }
  }

  @override
  Future<LocationAccess> request() async {
    if (!_supported) return LocationAccess.unavailable;
    try {
      return _fromRequest(await Geolocator.requestPermission());
    } catch (_) {
      return LocationAccess.unavailable;
    }
  }

  @override
  Future<({double lat, double lng})?> readOnce({
    Duration timeLimit = const Duration(seconds: 10),
  }) async {
    if (!_supported) return null;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: timeLimit,
        ),
      );
      return (lat: position.latitude, lng: position.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> openSettings() async {
    if (!_supported) return;
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }
}
