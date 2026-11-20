import type { CallOutcome, CallPlan, CallTask, CallTaskInput } from "../domain/types.js";
import { openingLine } from "./prompts.js";
import { detectScenario, SCENARIO_TEMPLATES } from "./scenario.js";
import type { CallBrain } from "./types.js";

const FILLER =
  /^(네|예|아|yes|yeah|ok|okay|sure|hello|hi)?[\s,.!]*(말씀하세요|말씀해\s?주세요|알겠습니다|감사합니다|go ahead|understood|thank you|thanks|bye)?[\s,.!]*(bye)?[\s,.!]*$/i;

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

  async summarize(task: CallTask): Promise<CallOutcome> {
    const ko = task.language === "ko";
    const calleeLines = task.transcript.filter((t) => t.speaker === "callee").map((t) => t.text);
    const rejected = task.approvals.filter((a) => a.status === "rejected" || a.status === "expired");

    if (calleeLines.length === 0) {
      const answeredButSilent = Boolean(task.connectedAt);
      return {
        result: "failed",
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

    const result = rejected.length > 0 ? "partial" : "success";
    const summary = ko
      ? `${task.targetName}과(와) 통화했습니다. ${result === "success" ? "요청한 내용을 확인했습니다." : "일부 조건은 승인하지 않아 진행하지 않았습니다."}`
      : `Spoke with ${task.targetName}. ${result === "success" ? "The request was handled." : "Some terms were declined, so they were not accepted."}`;

    return {
      result,
      summary,
      keyFacts: calleeLines.slice(1).filter((line) => !isFiller(line)),
      followUps: rejected.map((a) => (ko ? `미승인 항목 재검토: ${a.question}` : `Revisit declined item: ${a.question}`)),
    };
  }
}
