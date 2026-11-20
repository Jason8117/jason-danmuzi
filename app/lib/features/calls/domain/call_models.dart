import 'package:flutter/foundation.dart';

enum CallLanguage {
  ko('한국어'),
  en('English');

  const CallLanguage(this.label);
  final String label;

  static CallLanguage parse(String? value) =>
      CallLanguage.values.firstWhere((l) => l.name == value, orElse: () => CallLanguage.ko);
}

enum TaskStatus {
  planning('계획 중'),
  awaitingApproval('확인 필요'),
  dialing('연결 중'),
  ringing('신호 가는 중'),
  inProgress('통화 중'),
  summarizing('정리 중'),
  completed('완료'),
  failed('실패'),
  canceled('취소됨');

  const TaskStatus(this.label);
  final String label;

  static const _wire = {
    'planning': planning,
    'awaiting_approval': awaitingApproval,
    'dialing': dialing,
    'ringing': ringing,
    'in_progress': inProgress,
    'summarizing': summarizing,
    'completed': completed,
    'failed': failed,
    'canceled': canceled,
  };

  static TaskStatus parse(String? value) => _wire[value] ?? failed;

  bool get isLiveCall => this == dialing || this == ringing || this == inProgress;
  bool get isTerminal => this == completed || this == failed || this == canceled;
  bool get isOngoing => !isTerminal && this != awaitingApproval;
}

enum Speaker { agent, callee, system }

enum ApprovalStatus { pending, approved, rejected, expired }

enum OutcomeResult {
  success('목표 달성'),
  partial('일부 달성'),
  failed('달성 못 함');

  const OutcomeResult(this.label);
  final String label;
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

List<String> _strings(Object? value) => (value as List<dynamic>? ?? const []).cast<String>();

DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

@immutable
class TranscriptEntry {
  const TranscriptEntry({required this.id, required this.speaker, required this.text, required this.at});

  factory TranscriptEntry.fromJson(Map<String, dynamic> json) => TranscriptEntry(
        id: json['id'] as String,
        speaker: _enumByName(Speaker.values, json['speaker'], Speaker.system),
        text: json['text'] as String,
        at: _date(json['at']) ?? DateTime.now(),
      );

  final String id;
  final Speaker speaker;
  final String text;
  final DateTime at;
}

@immutable
class CallPlan {
  const CallPlan({
    required this.openingLine,
    required this.steps,
    required this.questionsToAsk,
    required this.approvalPoints,
    required this.fallback,
  });

  factory CallPlan.fromJson(Map<String, dynamic> json) => CallPlan(
        openingLine: json['openingLine'] as String? ?? '',
        steps: _strings(json['steps']),
        questionsToAsk: _strings(json['questionsToAsk']),
        approvalPoints: _strings(json['approvalPoints']),
        fallback: json['fallback'] as String? ?? '',
      );

  final String openingLine;
  final List<String> steps;
  final List<String> questionsToAsk;
  final List<String> approvalPoints;
  final String fallback;
}

@immutable
class ApprovalRequest {
  const ApprovalRequest({
    required this.id,
    required this.question,
    required this.status,
    required this.requestedAt,
    required this.expiresAt,
  });

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) => ApprovalRequest(
        id: json['id'] as String,
        question: json['question'] as String,
        status: _enumByName(ApprovalStatus.values, json['status'], ApprovalStatus.expired),
        requestedAt: _date(json['requestedAt']) ?? DateTime.now(),
        expiresAt: _date(json['expiresAt']) ?? DateTime.now(),
      );

  final String id;
  final String question;
  final ApprovalStatus status;
  final DateTime requestedAt;
  final DateTime expiresAt;

  bool get isPending => status == ApprovalStatus.pending;
}

@immutable
class CallOutcome {
  const CallOutcome({required this.result, required this.summary, required this.keyFacts, required this.followUps});

  factory CallOutcome.fromJson(Map<String, dynamic> json) => CallOutcome(
        result: _enumByName(OutcomeResult.values, json['result'], OutcomeResult.failed),
        summary: json['summary'] as String? ?? '',
        keyFacts: _strings(json['keyFacts']),
        followUps: _strings(json['followUps']),
      );

  final OutcomeResult result;
  final String summary;
  final List<String> keyFacts;
  final List<String> followUps;
}

@immutable
class CallTask {
  const CallTask({
    required this.id,
    required this.targetName,
    required this.phoneNumber,
    required this.goal,
    required this.language,
    required this.requesterName,
    required this.status,
    required this.transcript,
    required this.approvals,
    required this.isSimulated,
    required this.createdAt,
    required this.updatedAt,
    this.context,
    this.callbackNumber,
    this.plan,
    this.outcome,
    this.error,
    this.connectedAt,
    this.endedAt,
  });

  factory CallTask.fromJson(Map<String, dynamic> json) => CallTask(
        id: json['id'] as String,
        targetName: json['targetName'] as String,
        phoneNumber: json['phoneNumber'] as String,
        goal: json['goal'] as String,
        context: json['context'] as String?,
        language: CallLanguage.parse(json['language'] as String?),
        requesterName: json['requesterName'] as String? ?? '',
        callbackNumber: json['callbackNumber'] as String?,
        status: TaskStatus.parse(json['status'] as String?),
        plan: json['plan'] == null ? null : CallPlan.fromJson(json['plan'] as Map<String, dynamic>),
        transcript: (json['transcript'] as List<dynamic>? ?? const [])
            .map((e) => TranscriptEntry.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        approvals: (json['approvals'] as List<dynamic>? ?? const [])
            .map((e) => ApprovalRequest.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        outcome: json['outcome'] == null ? null : CallOutcome.fromJson(json['outcome'] as Map<String, dynamic>),
        error: json['error'] as String?,
        isSimulated: json['provider'] != 'twilio',
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
        updatedAt: _date(json['updatedAt']) ?? DateTime.now(),
        connectedAt: _date(json['connectedAt']),
        endedAt: _date(json['endedAt']),
      );

  final String id;
  final String targetName;
  final String phoneNumber;
  final String goal;
  final String? context;
  final CallLanguage language;
  final String requesterName;
  final String? callbackNumber;
  final TaskStatus status;
  final CallPlan? plan;
  final List<TranscriptEntry> transcript;
  final List<ApprovalRequest> approvals;
  final CallOutcome? outcome;
  final String? error;
  final bool isSimulated;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;

  ApprovalRequest? get pendingApproval {
    for (final approval in approvals) {
      if (approval.isPending) return approval;
    }
    return null;
  }
}

@immutable
class NewCallRequest {
  const NewCallRequest({
    required this.targetName,
    required this.phoneNumber,
    required this.goal,
    required this.language,
    required this.requesterName,
    this.context,
    this.callbackNumber,
  });

  final String targetName;
  final String phoneNumber;
  final String goal;
  final String? context;
  final CallLanguage language;
  final String requesterName;
  final String? callbackNumber;

  Map<String, dynamic> toJson() => {
        'targetName': targetName,
        'phoneNumber': phoneNumber,
        'goal': goal,
        if (context != null && context!.trim().isNotEmpty) 'context': context,
        'language': language.name,
        'requesterName': requesterName,
        if (callbackNumber != null && callbackNumber!.trim().isNotEmpty) 'callbackNumber': callbackNumber,
      };
}

@immutable
class ServerInfo {
  const ServerInfo({required this.realCalls, required this.brain});

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
        realCalls: json['realCalls'] as bool? ?? false,
        brain: json['brain'] as String? ?? 'heuristic',
      );

  final bool realCalls;
  final String brain;
}
