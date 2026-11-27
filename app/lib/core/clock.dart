import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time; tests inject a fixed one (SPEC-SHELL-001: today's greeting and date, history days).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
