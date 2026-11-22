import 'dart:async';

import 'package:callmate/core/network/api_client.dart';
import 'package:callmate/core/network/live_channel.dart';
import 'package:callmate/features/calls/data/calls_repository.dart';
import 'package:callmate/features/calls/domain/call_models.dart';

Map<String, dynamic> taskJson({
  String id = 'task-1',
  int version = 1,
  String status = 'in_progress',
  List<Map<String, dynamic>> approvals = const [],
  Map<String, dynamic>? outcome,
}) {
  final now = DateTime.now().toUtc();
  return {
    'id': id,
    'version': version,
    'targetName': '라 파스타',
    'phoneNumber': '+8221234567',
    'goal': '금요일 저녁 7시 2명 예약',
    'language': 'ko',
    'requesterName': '김민수',
    'status': status,
    'provider': 'simulated',
    'plan': {
      'openingLine': '안녕하세요, 김민수님을 대신해 전화드린 AI 비서입니다.',
      'steps': ['용건 전달', '예약 확인'],
      'questionsToAsk': ['7시에 가능한가요?'],
      'approvalPoints': ['예약금이 필요한 경우'],
      'fallback': '대안 시간 확인',
    },
    'transcript': [
      {'id': 't1', 'speaker': 'callee', 'text': '네, 라 파스타입니다.', 'at': now.toIso8601String()},
      {'id': 't2', 'speaker': 'agent', 'text': '예약 문의드립니다.', 'at': now.toIso8601String()},
    ],
    'approvals': approvals,
    'outcome': ?outcome,
    'createdAt': now.toIso8601String(),
    'updatedAt': now.toIso8601String(),
    'connectedAt': now.toIso8601String(),
  };
}

Map<String, dynamic> approvalJson({String status = 'pending', String? userComment}) {
  final now = DateTime.now().toUtc();
  return {
    'id': 'approval-1',
    'question': '예약금 1만 원 결제가 필요합니다. 진행할까요?',
    'status': status,
    'requestedAt': now.toIso8601String(),
    'expiresAt': now.add(const Duration(seconds: 90)).toIso8601String(),
    if (userComment != null) 'userComment': userComment,
  };
}

class FakeLiveConnection implements LiveConnection {
  void emit(Map<String, dynamic> message) => _messages.add(message);

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _status = StreamController<LiveStatus>.broadcast();

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;
  @override
  Stream<LiveStatus> get status => _status.stream;
  @override
  void connect() => _status.add(LiveStatus.connected);
  @override
  Future<void> close() async {
    await _messages.close();
    await _status.close();
  }
}

class FakeCallsRepository extends CallsRepository {
  FakeCallsRepository(this.tasks) : super(ApiClient(baseUrl: 'http://fake.invalid', token: ''));

  List<CallTask> tasks;
  final decisions = <({String approvalId, bool approve, String? comment})>[];
  final live = FakeLiveConnection();
  CallTask? nextCreated;

  /// When set, `decide` throws this instead of recording the decision.
  Object? decideError;

  @override
  Future<CallTask> create(NewCallRequest request) async => nextCreated!;

  @override
  Future<List<CallTask>> list() async => tasks;

  @override
  Future<ServerInfo> serverInfo() async => const ServerInfo(realCalls: false, brain: 'heuristic');

  @override
  Future<CallTask> decide(String taskId, String approvalId, {required bool approve, String? comment}) async {
    if (decideError case final error?) throw error;
    decisions.add((approvalId: approvalId, approve: approve, comment: comment));
    return CallTask.fromJson(
      taskJson(
        approvals: [
          approvalJson(status: approve ? 'approved' : 'rejected', userComment: comment),
        ],
      ),
    );
  }

  @override
  LiveConnection openLiveChannel() => live;
}
