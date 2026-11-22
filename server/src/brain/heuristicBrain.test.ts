import { describe, expect, it } from "vitest";
import type { ApprovalRequest, ApprovalStatus, CallTask, TranscriptEntry } from "../domain/types.js";
import { HeuristicBrain } from "./heuristicBrain.js";
import { maskPhoneNumbers } from "../domain/intake.js";

const AT = "2026-11-21T10:00:00.000Z";

function line(id: string, speaker: TranscriptEntry["speaker"], text: string): TranscriptEntry {
  return { id, speaker, text, at: AT };
}

const SPOKEN: TranscriptEntry[] = [
  line("t1", "callee", "네, 라 파스타입니다."),
  line("t2", "agent", "금요일 저녁 7시 2명 예약 문의드립니다."),
  line("t3", "callee", "그 시간엔 자리가 없습니다."),
];

function approval(status: ApprovalStatus): ApprovalRequest {
  return {
    id: "a-1",
    question: "예약금 1만 원 결제가 필요합니다. 진행할까요?",
    status,
    requestedAt: AT,
    resolvedAt: AT,
    expiresAt: AT,
  };
}

function makeTask(overrides: Partial<CallTask> = {}): CallTask {
  return {
    id: "t-1",
    version: 1,
    targetName: "라 파스타",
    phoneNumber: "+8221234567",
    goal: "금요일 저녁 7시 2명 예약",
    language: "ko",
    requesterName: "김민수",
    status: "summarizing",
    transcript: SPOKEN,
    approvals: [],
    provider: "simulated",
    createdAt: AT,
    updatedAt: AT,
    connectedAt: AT,
    ...overrides,
  };
}

describe("HeuristicBrain.summarize (SPEC-OUTCOME-001)", () => {
  const brain = new HeuristicBrain();

  // AC-001 / REQ-001
  it("every heuristic outcome declares its source", async () => {
    const spoken = await brain.summarize(makeTask());
    const silent = await brain.summarize(makeTask({ transcript: [] }));
    expect(spoken.source).toBe("heuristic");
    expect(silent.source).toBe("heuristic");
  });

  // AC-002 / REQ-002, REQ-003
  it.each([
    { name: "no approvals", approvals: [] as ApprovalRequest[], followUps: 0 },
    { name: "a rejected approval", approvals: [approval("rejected")], followUps: 1 },
    { name: "an expired approval", approvals: [approval("expired")], followUps: 1 },
  ])("never claims success without LLM verification ($name)", async ({ approvals, followUps }) => {
    const outcome = await brain.summarize(makeTask({ approvals }));
    expect(outcome.result).not.toBe("success");
    expect(outcome.result).toBe("unverified");
    expect(outcome.source).toBe("heuristic");
    expect(outcome.followUps).toHaveLength(followUps);
    if (followUps > 0) {
      expect(outcome.followUps[0]).toBe("미승인 항목 재검토: 예약금 1만 원 결제가 필요합니다. 진행할까요?");
    }
  });

  // AC-003 / REQ-004
  it.each([
    { name: "never connected", connectedAt: undefined, summary: "상대방과 연결되지 않았습니다." },
    {
      name: "answered but silent",
      connectedAt: AT,
      summary: "상대가 전화를 받았지만 대화가 기록되지 않았습니다. 음성 스트림/AI 연결을 확인해 주세요.",
    },
  ])("keeps a verified failure when the callee never spoke ($name)", async ({ connectedAt, summary }) => {
    const outcome = await brain.summarize(makeTask({ transcript: [line("t2", "agent", "여보세요?")], connectedAt }));
    expect(outcome.result).toBe("failed");
    expect(outcome.source).toBe("heuristic");
    expect(outcome.summary).toBe(summary);
  });

  // AC-004 / REQ-005
  it("labels the heuristic summary as unverified", async () => {
    const ko = await brain.summarize(makeTask());
    expect(ko.summary.startsWith("자동 요약(검증되지 않음):")).toBe(true);
    expect(ko.summary).not.toContain("요청한 내용을 확인했습니다.");

    const en = await brain.summarize(
      makeTask({
        language: "en",
        targetName: "La Pasta",
        transcript: [line("t1", "callee", "La Pasta, how can I help?"), line("t3", "callee", "We are fully booked.")],
      }),
    );
    expect(en.summary.startsWith("Automatic summary (unverified):")).toBe(true);
    expect(en.summary).not.toContain("The request was handled.");
  });
});

describe("HeuristicBrain intake (SPEC-INTAKE-001)", () => {
  // AC-010 / REQ-010 — design.md §3.4 deterministic name table, fed the masked text as the service does
  it.each([
    { text: "라 파스타에 전화해서 금요일 7시 2명 예약해줘", targetName: "라 파스타", goal: "라 파스타에 전화해서 금요일 7시 2명 예약해줘" },
    { text: "동네 세탁소에게 연락해 영업시간 물어봐", targetName: "동네 세탁소", goal: "동네 세탁소에게 연락해 영업시간 물어봐" },
    { text: "엄마한테 전화해 줘", targetName: "엄마", goal: "엄마한테 전화해 줘" },
    { text: "금요일 7시 예약", targetName: null, goal: "금요일 7시 예약" },
    { text: "010-1234-5678에 전화해서 예약", targetName: null, goal: "에 전화해서 예약" },
    { text: "라 파스타에   전화해서\n7시", targetName: "라 파스타", goal: "라 파스타에 전화해서 7시" },
  ])("drafts intake content without an LLM: $text", async ({ text, targetName, goal }) => {
    const draft = await new HeuristicBrain().draftIntake(maskPhoneNumbers(text), "ko");
    expect(draft).toEqual({ targetName, goal, conditions: [], context: null, source: "heuristic" });
  });
});
