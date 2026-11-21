import { setTimeout as sleep } from "node:timers/promises";
import { detectScenario, SCENARIO_TEMPLATES } from "../domain/scenario.js";
import type { ProviderId } from "../domain/types.js";
import type { CallSession, CallProvider } from "./types.js";

export const SIMULATED_PROVIDER_ID = "simulated" satisfies ProviderId;

const LINES = {
  ko: {
    greeting: (name: string) => `네, ${name}입니다. 무엇을 도와드릴까요?`,
    okay: "네, 말씀하세요.",
    hold: "잠시만요, 요청하신 분께 확인하고 바로 말씀드릴게요.",
    approved: "확인했습니다. 그 조건으로 진행해 주세요.",
    rejected: "요청하신 분이 그 조건은 원하지 않으셔서, 이번에는 진행하지 않겠습니다.",
    acknowledge: "네, 알겠습니다.",
    closing: "말씀해 주신 내용 잘 전달하겠습니다. 감사합니다, 좋은 하루 보내세요.",
    bye: "네, 감사합니다.",
  },
  en: {
    greeting: (name: string) => `Hello, ${name}. How can I help?`,
    okay: "Sure, go ahead.",
    hold: "One moment, let me check with the person I'm calling for.",
    approved: "Thanks for waiting. Please go ahead with that.",
    rejected: "They'd rather not accept that, so we'll leave it for now.",
    acknowledge: "Okay, understood.",
    closing: "I'll pass that along. Thank you, have a great day.",
    bye: "Thank you, bye.",
  },
} as const;

/**
 * Plays a scripted but realistic call so the full flow (ringing, live
 * transcript, mid-call approval, summary) works without telephony credentials.
 */
export class SimulatedCallProvider implements CallProvider {
  readonly name: ProviderId = SIMULATED_PROVIDER_ID;

  constructor(private readonly speed = 1) {}

  async start(session: CallSession): Promise<void> {
    void this.run(session).catch((error: unknown) => {
      if (!session.signal.aborted) session.end({ error: (error as Error).message });
    });
  }

  async hangup(): Promise<void> {
    // The session's AbortSignal stops the script; nothing else to release.
  }

  private async run(session: CallSession): Promise<void> {
    const { signal } = session;
    const task = session.task();
    const lines = LINES[task.language];
    const template = SCENARIO_TEMPLATES[task.language][detectScenario(task.goal)];
    const plan = task.plan;
    const pause = (ms: number) => sleep(ms / this.speed, undefined, { signal });

    await pause(1200);
    session.markRinging();
    await pause(2500);
    session.markConnected();

    await pause(800);
    session.appendTranscript("callee", lines.greeting(task.targetName));
    await pause(1500);
    session.appendTranscript("agent", plan?.openingLine ?? "");
    await pause(1500);
    session.appendTranscript("callee", lines.okay);

    const questions = plan?.questionsToAsk.length ? plan.questionsToAsk : template.questions;
    for (const [index, question] of questions.entries()) {
      await pause(1600);
      session.appendTranscript("agent", question);
      await pause(1800);
      session.appendTranscript("callee", template.calleeAnswers[index] ?? lines.acknowledge);

      if (index === 1 && template.approvalAsk) {
        await pause(1000);
        session.appendTranscript("agent", lines.hold);
        const decision = await session.requestApproval(template.approvalAsk);
        if (signal.aborted) return;
        session.appendTranscript("agent", decision.approved ? lines.approved : lines.rejected);
        if (decision.comment) {
          session.appendTranscript("system", `사용자 안내: ${decision.comment}`);
        }
        await pause(1200);
        session.appendTranscript("callee", lines.acknowledge);
        if (!decision.approved) break;
      }
    }

    await pause(1500);
    session.appendTranscript("agent", lines.closing);
    await pause(1000);
    session.appendTranscript("callee", lines.bye);
    await pause(600);
    session.end();
  }
}
