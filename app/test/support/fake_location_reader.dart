import 'dart:async';

import 'package:callmate/features/places/location/location_reader.dart';

/// A scripted device position: the permission state, what the OS dialog answers, and the position (or
/// none). Every call is counted; nothing touches a real plugin.
class FakeLocationReader implements LocationReader {
  FakeLocationReader({
    this.state = LocationAccess.notDetermined,
    this.answer = LocationAccess.granted,
    this.position = (lat: 37.55, lng: 126.91),
    this.delay,
  });

  LocationAccess state;

  /// What `request` (the OS dialog) returns; it also becomes the new [state].
  LocationAccess answer;

  /// Null makes `readOnce` fail.
  ({double lat, double lng})? position;

  /// When set, `readOnce` answers only after this much (fake) time.
  Duration? delay;

  int accessCalls = 0;
  int requestCalls = 0;
  int readCalls = 0;
  int settingsCalls = 0;

  @override
  Future<LocationAccess> access() async {
    accessCalls++;
    return state;
  }

  @override
  Future<LocationAccess> request() async {
    requestCalls++;
    return state = answer;
  }

  @override
  Future<({double lat, double lng})?> readOnce({
    Duration timeLimit = const Duration(seconds: 10),
  }) async {
    readCalls++;
    if (delay case final wait?) await Future<void>.delayed(wait);
    return position;
  }

  @override
  Future<void> openSettings() async {
    settingsCalls++;
  }
}
