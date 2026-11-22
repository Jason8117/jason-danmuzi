import type { CallOutcome, CallPlan, CallTask, CallTaskInput, IntakeContent, Language } from "../domain/types.js";
import { openingLine } from "./prompts.js";
import { PHONE_PLACEHOLDER } from "../domain/intake.js";
import { detectScenario, SCENARIO_TEMPLATES } from "../domain/scenario.js";
import type { CallBrain } from "./types.js";

/** design.md §3.4: the leading name before a particle and "전화"/"연락", at most 40 characters. */
const INTAKE_NAME = /^\s*(.{1,40}?)\s*(?:에|에게|한테|께)\s*(?:전화|연락)/;

const FILLER =
  /^(네|예|아|yes|yeah|ok|okay|sure|hello|hi)?[\s,.!]*(말씀하세요|말씀해\s?주세요|알겠습니다|감사합니다|go ahead|understood|thank you|thanks|bye)?[\s,.!]*(bye)?[\s,.!]*$/i;

/** Leads every heuristic summary so a reader never mistakes it for a verified result (OD-2 default wording). */
const UNVERIFIED_PREFIX = { ko: "자동 요약(검증되지 않음):", en: "Automatic summary (unverified):" } as const;

/** Acknowledgements like "네, 알겠습니다" carry no information worth reporting. */
export function isFiller(text: string): boolean {
  return FILLER.test(text.trim());
}

/** Rule-based brain used when no LLM key is configured. Deterministic, so it also backs tests. */
export class HeuristicBrain implements CallBrain {
  readonly name = "heuristic" as const;

  async createPlan(input: CallTaskInput): Promise<CallPlan> {
    const template = SCENARIO_TEMPLATES[input.language][detectScenario(input.goal)];
    return {
      openingLine: openingLine(input),
      steps: template.steps,
      questionsToAsk: template.questions,
      approvalPoints: template.approvalPoints,
      fallback:
        input.language === "ko"
          ? "목표를 달성할 수 없으면 이유와 가능한 대안을 확인하고 정중히 마무리합니다."
          : "If the goal can't be met, note the reason and any alternative, then close politely.",
    };
  }

  /** SPEC-INTAKE-001 REQ-010: the goal is the request itself; a name only from "<이름>에/에게/한테/께 전화/연락". */
  async draftIntake(maskedText: string, _language: Language): Promise<IntakeContent> {
    const goal = maskedText.split(PHONE_PLACEHOLDER).join(" ").replace(/\s+/g, " ").trim();
    const name = INTAKE_NAME.exec(goal)?.[1]?.trim();
    return { targetName: name ? name : null, goal, conditions: [], context: null, source: "heuristic" };
  }

  async summarize(task: CallTask): Promise<CallOutcome> {
    const ko = task.language === "ko";
    const calleeLines = task.transcript.filter((t) => t.speaker === "callee").map((t) => t.text);
    const rejected = task.approvals.filter((a) => a.status === "rejected" || a.status === "expired");

    if (calleeLines.length === 0) {
      // A missing callee transcript is itself evidence, so this is a verified failure.
      const answeredButSilent = Boolean(task.connectedAt);
      return {
        result: "failed",
        source: "heuristic",
        summary: ko
          ? answeredButSilent
            ? "상대가 전화를 받았지만 대화가 기록되지 않았습니다. 음성 스트림/AI 연결을 확인해 주세요."
            : "상대방과 연결되지 않았습니다."
          : answeredButSilent
            ? "The callee answered but no conversation was recorded. Check the media/AI bridge."
            : "The call did not connect.",
        keyFacts: [],
        followUps: [ko ? "잠시 후 다시 시도해 보세요." : "Try again later."],
      };
    }

    // @MX:NOTE: [AUTO] Nothing here checks the transcript against task.goal, so the heuristic may report what
    // happened (who answered, which terms were declined) but never whether the goal was met.
    // @MX:SPEC: SPEC-OUTCOME-001 REQ-002, REQ-003, REQ-005
    const declined = rejected.length > 0;
    const summary = ko
      ? `${UNVERIFIED_PREFIX.ko} ${task.targetName}과(와) 통화했습니다.${declined ? " 일부 조건은 승인하지 않아 진행하지 않았습니다." : ""}`
      : `${UNVERIFIED_PREFIX.en} Spoke with ${task.targetName}.${declined ? " Some terms were declined, so they were not accepted." : ""}`;

    return {
      result: "unverified",
      source: "heuristic",
      summary,
      keyFacts: calleeLines.slice(1).filter((line) => !isFiller(line)),
      followUps: rejected.map((a) => (ko ? `미승인 항목 재검토: ${a.question}` : `Revisit declined item: ${a.question}`)),
    };
  }
}
