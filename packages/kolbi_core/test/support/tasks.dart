import 'package:kolbi_core/kolbi_core.dart';

/// A task as the server would list it; every field the SHELL-001 functions read can be set.
CallTask task({
  String id = 't',
  String name = '라 파스타',
  String status = 'in_progress',
  List<Map<String, dynamic>> approvals = const [],
  bool transcript = true,
  Map<String, dynamic>? outcome,
  String updatedAt = '2026-11-26T03:00:00Z',
  Object? kind,
}) => CallTask.fromJson({
  'id': id,
  'version': 1,
  'targetName': name,
  'phoneNumber': '+8221234567',
  'goal': '금요일 저녁 7시 2명 예약',
  'language': 'ko',
  'requesterName': '김민수',
  'status': status,
  'provider': 'simulated',
  'transcript': [
    if (transcript)
      {'id': 'l1', 'speaker': 'callee', 'text': '네, 여보세요.', 'at': updatedAt},
  ],
  'approvals': approvals,
  'outcome': ?outcome,
  'kind': ?kind,
  'createdAt': updatedAt,
  'updatedAt': updatedAt,
});

/// An approval in [status]; pending ones expire [expiresIn] after 2026-11-26 03:00 UTC.
Map<String, dynamic> approval({
  String id = 'a1',
  String status = 'pending',
  Duration expiresIn = const Duration(seconds: 60),
}) => {
  'id': id,
  'question': '예약금 1만 원 결제가 필요합니다. 진행할까요?',
  'status': status,
  'requestedAt': '2026-11-26T03:00:00Z',
  'expiresAt': DateTime.utc(2026, 11, 26, 3).add(expiresIn).toIso8601String(),
};

Map<String, dynamic> outcome([
  String result = 'success',
  String summary = '예약을 확정했어요.',
]) => {
  'result': result,
  'source': 'llm',
  'summary': summary,
  'keyFacts': <String>[],
  'followUps': <String>[],
};
