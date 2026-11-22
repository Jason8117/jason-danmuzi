import { randomUUID } from "node:crypto";
import { HeuristicBrain } from "../brain/heuristicBrain.js";
import { buildAgentInstructions, openingLine } from "../brain/prompts.js";
import type { CallBrain } from "../brain/types.js";
import { sanitizeApprovalComment } from "../domain/approvalComment.js";
import {
  answeredHistory,
  findHistoryNumber,
  findKnownName,
  findPhoneNumberInText,
  maskPhoneNumbers,
  normalizeName,
  stripPhoneNumbers,
} from "../domain/intake.js";
import { checkTargetNumber } from "../domain/phone.js";
import { assertTransition } from "../domain/stateMachine.js";
import {
  type ApprovalDecision,
  type ApprovalDecisionReason,
  type ApprovalRequest,
  type ApprovalStatus,
  type CallPlan,
  type CallTask,
  type CallTaskInput,
  type CreateTaskOptions,
  type IntakeMissingField,
  type IntakeResult,
  type Language,
  type Speaker,
  type TaskStatus,
  isActiveCall,
  isTerminal,
} from "../domain/types.js";
import type { EventBus } from "../events/eventBus.js";
import { logger as defaultLogger, type Logger } from "../logger.js";
import type { CallProvider, CallSession, EndOptions } from "../providers/types.js";
import type { TaskStore } from "../store/taskStore.js";

export class ServiceError extends Error {
  constructor(
    readonly statusCode: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

export interface CallServiceOptions {
  maxConcurrentCalls: number;
  maxCallsPerDay: number;
  approvalTimeoutMs: number;
  maxCallDurationMs: number;
  logger?: Logger;
}

interface PendingApproval {
  taskId: string;
  resolve: (decision: ApprovalDecision) => void;
  timer: NodeJS.Timeout;
}

export interface ApprovalResponseInput {
  approve: boolean;
  comment?: string;
}

interface RunningSession {
  controller: AbortController;
  durationTimer: NodeJS.Timeout;
  ending: boolean;
}

const now = () => new Date().toISOString();

export const SHUTDOWN_CALL_ERROR = "서버가 종료되어 통화를 끊었습니다.";
const INVALID_PHONE_MESSAGE = "전화번호 형식이 올바르지 않습니다.";
const BLOCKED_NUMBER_MESSAGE = "긴급·특수번호에는 전화할 수 없습니다.";
/** Recorded when an auto start fails outside the ServiceError checks (SPEC-INTAKE-001 design.md §5). */
const AUTO_START_FAILED_MESSAGE = "자동으로 통화를 시작하지 못했어요.";
/** Deterministic intake for brains that do not implement draftIntake (REQ-010). */
const INTAKE_RULES = new HeuristicBrain();
/** Upper bound on how long startup waits for restart-recovery hang-ups. */
const RECOVERY_DEADLINE_MS = 10_000;
/** Prefix of the transcript line that records a user's approval comment (SPEC-APPROVAL-001 OD-3). */
const GUIDANCE_PREFIX: Record<Language, string> = { ko: "사용자 안내:", en: "User guidance:" };

export interface TerminateActiveCallsOptions {
  /** The termination step's share of the shutdown budget; unfinished hang-ups are abandoned after it. */
  deadlineMs: number;
}

export class CallService {
  private readonly pendingApprovals = new Map<string, PendingApproval>();
  private readonly sessions = new Map<string, RunningSession>();
  private readonly log: Logger;
  private shuttingDown = false;

  constructor(
    private readonly store: TaskStore,
    private readonly bus: EventBus,
    private readonly brain: CallBrain,
    private readonly provider: CallProvider,
    private readonly options: CallServiceOptions,
  ) {
    this.log = options.logger ?? defaultLogger;
  }

  /**
   * Calls interrupted by a server restart cannot be resumed; mark them so the user is not left waiting.
   * A call that may still be ringing or talking at the provider is hung up first (bounded by `deadlineMs`),
   * so nobody is left on a line without an agent.
   */
  // @MX:WARN: [AUTO] Hangs up live provider calls found in DATA_FILE; assumes one server process per DATA_FILE.
  // @MX:REASON: Two instances sharing a DATA_FILE (e.g. blue/green) would cut the other's healthy calls (SPEC-LIFECYCLE-001 §4).
  // @MX:SPEC: SPEC-LIFECYCLE-001
  async recoverInterruptedTasks({ deadlineMs = RECOVERY_DEADLINE_MS }: { deadlineMs?: number } = {}): Promise<void> {
    const toHangUp: CallTask[] = [];
    for (const task of this.store.list()) {
      if (isTerminal(task.status) || task.status === "awaiting_approval") continue;
      if (!isActiveCall(task.status)) {
        this.markInterrupted(task);
      } else if (!task.providerCallId) {
        this.log.warn({ taskId: task.id, reason: "no_provider_call_id" }, "Recovery cannot hang up the call");
        this.markInterrupted(task);
      } else if (task.provider !== this.provider.name || !this.provider.terminateByProviderCallId) {
        this.log.warn(
          { taskId: task.id, reason: "provider_mismatch", taskProvider: task.provider, activeProvider: this.provider.name },
          "Recovery cannot hang up the call",
        );
        this.markInterrupted(task);
      } else {
        toHangUp.push(task);
      }
    }

    const pending = new Set(toHangUp.map((task) => task.id));
    const hangups = toHangUp.map((task) =>
      Promise.resolve()
        .then(() => this.provider.terminateByProviderCallId!(task.providerCallId!))
        .catch((error: unknown) =>
          this.log.warn({ taskId: task.id, err: (error as Error).message }, "Recovery hangup failed"),
        )
        .finally(() => pending.delete(task.id)),
    );
    let timer: NodeJS.Timeout | undefined;
    const deadline = new Promise<void>((resolve) => {
      timer = setTimeout(resolve, deadlineMs);
    });
    try {
      if (hangups.length > 0) await Promise.race([Promise.all(hangups), deadline]);
    } finally {
      clearTimeout(timer);
    }
    if (pending.size > 0) {
      this.log.warn({ taskIds: [...pending], deadlineMs }, "Recovery hangup did not finish in time");
    }

    // Marked failed whether or not the hang-up went through.
    for (const task of toHangUp) this.markInterrupted(task);
  }

  private markInterrupted(task: CallTask): void {
    task.status = "failed";
    task.error = "서버가 재시작되어 작업이 중단되었습니다.";
    task.endedAt ??= now();
    for (const approval of task.approvals) if (approval.status === "pending") approval.status = "expired";
    this.persist(task);
  }

  /** Shutdown step 0: from now on no new task, no new call and no new mid-call approval. */
  beginShutdown(): void {
    this.shuttingDown = true;
  }

  /**
   * Shutdown step 1: asks the provider to hang up every live call, waits at most `deadlineMs`,
   * then closes each call as failed without a summary. Must run before the HTTP server closes,
   * because app.close() also closes the provider's media sockets.
   */
  // @MX:WARN: [AUTO] Races provider hang-ups against a timer; abandoned hang-ups keep running in the background.
  // @MX:REASON: The shutdown budget (SPEC-LIFECYCLE-001 REQ-003) must hold even when the provider never answers.
  // @MX:SPEC: SPEC-LIFECYCLE-001
  async terminateActiveCalls({ deadlineMs }: TerminateActiveCallsOptions): Promise<void> {
    const tasks = this.store.list().filter((task) => isActiveCall(task.status));
    if (tasks.length === 0) return;

    for (const task of tasks) {
      const session = this.sessions.get(task.id);
      if (!session) continue;
      // Ignore provider callbacks that would end the call normally and summarize it meanwhile.
      session.ending = true;
      clearTimeout(session.durationTimer);
    }

    const pending = new Set(tasks.map((task) => task.id));
    const hangups = tasks.map((task) => {
      if (this.provider.terminateByProviderCallId && !task.providerCallId) {
        this.log.warn({ taskId: task.id, status: task.status }, "Shutdown hangup without a provider call id");
      }
      return this.provider
        .hangup(task.id)
        .catch((error: unknown) => this.log.warn({ taskId: task.id, err: (error as Error).message }, "Shutdown hangup failed"))
        .finally(() => pending.delete(task.id));
    });

    let timer: NodeJS.Timeout | undefined;
    const deadline = new Promise<void>((resolve) => {
      timer = setTimeout(resolve, deadlineMs);
    });
    try {
      await Promise.race([Promise.all(hangups), deadline]);
    } finally {
      clearTimeout(timer);
    }
    if (pending.size > 0) {
      this.log.warn({ taskIds: [...pending], deadlineMs }, "Shutdown hangup did not finish in time");
    }

    for (const task of tasks) {
      const current = this.store.get(task.id);
      if (!current || !isActiveCall(current.status)) continue;
      for (const approval of current.approvals) if (approval.status === "pending") approval.status = "expired";
      current.error = SHUTDOWN_CALL_ERROR;
      this.finishWithoutCall(current, "failed");
    }
  }

  list(): CallTask[] {
    return this.store.list();
  }

  get(id: string): CallTask {
    const task = this.store.get(id);
    if (!task) throw new ServiceError(404, "not_found", "Task not found");
    return task;
  }

  create(input: CallTaskInput, options: CreateTaskOptions = {}): CallTask {
    this.assertNotShuttingDown();
    // Nothing is stored, published or planned before the number passes the policy (SPEC-POLICY-001 REQ-001..003).
    const checked: CallTaskInput = {
      ...input,
      phoneNumber: this.requireDialableNumber(input.phoneNumber),
      callbackNumber: this.allowedCallbackNumber(input.callbackNumber),
    };
    const timestamp = now();
    const task: CallTask = {
      ...checked,
      id: randomUUID(),
      version: 0,
      status: "planning",
      transcript: [],
      approvals: [],
      provider: this.provider.name,
      createdAt: timestamp,
      updatedAt: timestamp,
      ...(options.autoStart === true && { autoStart: true }),
    };
    this.persist(task);
    void this.plan(task.id, checked);
    return task;
  }

  /**
   * Turns a one-line request into a plan-card draft. Creates nothing: no task, no event, no provider call, and
   * nothing about the request is logged (SPEC-INTAKE-001 REQ-001..012). Numbers come only from the request text or
   * from a counterparty who answered before, and every one passes checkTargetNumber.
   */
  // @MX:ANCHOR: [AUTO] Sole owner of intake post-processing: masking before the brain, invented-number removal and
  // the name-containment check after it. Both brains and the HTTP route rely on this being the only place.
  // @MX:REASON: REQ-007/REQ-008 put masking and post-processing in one service layer; a second copy would drift.
  // @MX:SPEC: SPEC-INTAKE-001
  async draftIntake(text: string, language: Language = "ko"): Promise<IntakeResult> {
    this.assertNotShuttingDown();
    const fromText = findPhoneNumberInText(text);
    const masked = maskPhoneNumbers(text);
    const content = this.brain.draftIntake
      ? await this.brain.draftIntake(masked, language)
      : await INTAKE_RULES.draftIntake(masked, language);

    const cleanName = content.targetName === null ? "" : stripPhoneNumbers(content.targetName);
    const mentioned = cleanName !== "" && normalizeName(text).includes(normalizeName(cleanName));
    const history = answeredHistory(this.store.list());
    const targetName = mentioned ? cleanName : findKnownName(history, text);

    let phoneNumber = fromText.phoneNumber;
    let phoneSource: IntakeResult["phoneSource"] = phoneNumber ? "text" : null;
    if (!phoneNumber && !fromText.numberIssue && targetName) {
      phoneNumber = findHistoryNumber(history, targetName);
      if (phoneNumber) phoneSource = "history";
    }

    const goal = stripPhoneNumbers(content.goal);
    const context = content.context === null ? "" : stripPhoneNumbers(content.context);
    const missing: IntakeMissingField[] = [];
    if (!targetName) missing.push("targetName");
    if (!phoneNumber) missing.push("phoneNumber");
    if (!goal) missing.push("goal");

    return {
      draft: {
        targetName: targetName || null,
        phoneNumber,
        goal,
        conditions: content.conditions.map(stripPhoneNumbers).filter((condition) => condition !== ""),
        context: context || null,
        language,
      },
      missing,
      phoneSource,
      numberIssue: fromText.numberIssue,
      source: content.source,
    };
  }

  /** User reviewed the plan (optionally edited it) and wants the call placed now. */
  async approvePlan(id: string, planOverride?: Partial<CallPlan>): Promise<CallTask> {
    // Check order is fixed: 503 shutting_down -> 404 -> 409 -> 400 number -> 429
    // (SPEC-LIFECYCLE-001 REQ-001 (d), SPEC-POLICY-001 REQ-007).
    this.assertNotShuttingDown();
    const task = this.get(id);
    if (task.status !== "awaiting_approval" || !task.plan) {
      throw new ServiceError(409, "invalid_state", "The plan is not waiting for approval");
    }
    // Tasks loaded from the data file never went through create(), so the stored number is re-checked here.
    this.requireDialableNumber(task.phoneNumber);
    this.assertWithinLimits();

    task.plan = { ...task.plan, ...planOverride };
    // A successful start, manual or automatic, supersedes an earlier blocked auto start (SPEC-INTAKE-001 REQ-015).
    delete task.autoStartBlocked;
    task.startedAt = now();
    this.transition(task, "dialing");

    const session = this.openSession(task.id);
    try {
      await this.provider.start(session);
    } catch (error) {
      session.end({ error: `전화 연결에 실패했습니다: ${(error as Error).message}` });
    }
    return this.get(id);
  }

  async cancel(id: string): Promise<CallTask> {
    const task = this.get(id);
    if (isTerminal(task.status) || task.status === "summarizing") return task;

    if (isActiveCall(task.status)) {
      const connected = task.status === "in_progress";
      await this.provider.hangup(id);
      // A connected call already produced something worth summarizing.
      if (connected) this.endSession(id, {});
      else this.finishWithoutCall(task, "canceled");
    } else {
      this.finishWithoutCall(task, "canceled");
    }
    return this.get(id);
  }

  respondToApproval(taskId: string, approvalId: string, input: ApprovalResponseInput): CallTask {
    const task = this.get(taskId);
    const approval = task.approvals.find((a) => a.id === approvalId);
    const pending = this.pendingApprovals.get(approvalId);
    if (!approval || !pending || approval.status !== "pending") {
      throw new ServiceError(409, "approval_closed", "This approval is no longer pending");
    }
    // Sanitized after the 409 check, so a closed approval is left untouched (SPEC-APPROVAL-001 REQ-002, REQ-010).
    this.resolveApproval(approvalId, {
      status: input.approve ? "approved" : "rejected",
      reason: input.approve ? "user_approved" : "user_rejected",
      comment: input.comment === undefined ? undefined : sanitizeApprovalComment(input.comment),
    });
    return this.get(taskId);
  }

  delete(id: string): void {
    const task = this.get(id);
    if (!isTerminal(task.status) && task.status !== "awaiting_approval") {
      throw new ServiceError(409, "invalid_state", "Finish or cancel the call before deleting it");
    }
    this.store.delete(id);
    this.bus.publish({ type: "task.deleted", taskId: id });
  }

  private async plan(id: string, input: CallTaskInput): Promise<void> {
    let planned: CallTask | undefined;
    try {
      const plan = await this.brain.createPlan(input);
      const task = this.store.get(id);
      if (!task || task.status !== "planning") return;
      task.plan = plan;
      this.transition(task, "awaiting_approval");
      planned = task;
    } catch (error) {
      const task = this.store.get(id);
      if (!task || task.status !== "planning") return;
      task.error = `통화 계획을 세우지 못했습니다: ${(error as Error).message}`;
      this.transition(task, "failed");
    }
    // Outside the try: an auto-start error must never reach the catch above, which would swallow it silently.
    // This is the only auto-start trigger, so loaded, canceled or failed tasks never start (SPEC-INTAKE-001 REQ-016).
    if (planned?.autoStart) await this.autoStart(planned);
  }

  /**
   * Places the call the user already confirmed on the plan card, through the same checks as a manual approval.
   * Never throws: any failure is recorded on the task as autoStartBlocked and the task stays awaiting_approval.
   */
  // @MX:WARN: [AUTO] Runs unawaited from create() (via plan()); a throw here would be an unhandled rejection.
  // @MX:REASON: SPEC-INTAKE-001 REQ-015 requires every auto-start failure to be recorded, never propagated (design.md §5).
  // @MX:SPEC: SPEC-INTAKE-001
  private async autoStart(task: CallTask): Promise<void> {
    try {
      // The template greeting always discloses the AI; the user never saw the plan body (OD-7, REQ-014).
      await this.approvePlan(task.id, { openingLine: openingLine(task) });
    } catch (error) {
      try {
        const current = this.store.get(task.id);
        if (!current || current.status !== "awaiting_approval") return;
        current.autoStartBlocked =
          error instanceof ServiceError
            ? { code: error.code, message: error.message }
            : { code: "auto_start_failed", message: AUTO_START_FAILED_MESSAGE };
        this.persist(current);
      } catch {
        this.log.warn({ taskId: task.id, reason: "auto_start_not_recorded" }, "Auto start failure could not be recorded");
      }
    }
  }

  private assertNotShuttingDown(): void {
    if (this.shuttingDown) {
      throw new ServiceError(503, "shutting_down", "서버가 종료 중입니다. 잠시 후 다시 시도해 주세요.");
    }
  }

  /** Maps the domain number rule to a ServiceError; returns the E.164 value to dial. */
  private requireDialableNumber(phoneNumber: string): string {
    const check = checkTargetNumber(phoneNumber);
    if (check.kind === "invalid") throw new ServiceError(400, "invalid_phone", INVALID_PHONE_MESSAGE);
    if (check.kind === "blocked") throw new ServiceError(400, "blocked_number", BLOCKED_NUMBER_MESSAGE);
    return check.e164;
  }

  /**
   * Same number rule as the target, but never an error: invalid or blocked callback numbers are
   * dropped (stored as undefined) so the task is still created (SPEC-POLICY-001 REQ-004, owner decision).
   */
  private allowedCallbackNumber(raw: string | undefined): string | undefined {
    if (!raw) return undefined;
    const check = checkTargetNumber(raw);
    return check.kind === "ok" ? check.e164 : undefined;
  }

  private assertWithinLimits(): void {
    const tasks = this.store.list();
    if (tasks.filter((t) => isActiveCall(t.status)).length >= this.options.maxConcurrentCalls) {
      throw new ServiceError(429, "too_many_active_calls", "Too many calls are in progress");
    }
    const since = Date.now() - 24 * 60 * 60 * 1000;
    const recent = tasks.filter((t) => t.startedAt && Date.parse(t.startedAt) >= since).length;
    if (recent >= this.options.maxCallsPerDay) {
      throw new ServiceError(429, "daily_limit", "Daily call limit reached");
    }
  }

  private openSession(taskId: string): CallSession {
    const controller = new AbortController();
    const durationTimer = setTimeout(() => {
      void this.provider.hangup(taskId);
      this.endSession(taskId, {});
    }, this.options.maxCallDurationMs);
    this.sessions.set(taskId, { controller, durationTimer, ending: false });

    const updateActive = (fn: (task: CallTask) => void) => {
      const task = this.store.get(taskId);
      if (task && isActiveCall(task.status)) fn(task);
    };

    return {
      taskId,
      signal: controller.signal,
      task: () => this.get(taskId),
      agentInstructions: () => buildAgentInstructions(this.get(taskId)),
      markRinging: () =>
        updateActive((task) => {
          if (task.status === "dialing") this.transition(task, "ringing");
        }),
      markConnected: () =>
        updateActive((task) => {
          if (task.status === "in_progress") return;
          task.connectedAt = now();
          this.transition(task, "in_progress");
        }),
      appendTranscript: (speaker: Speaker, text: string) =>
        updateActive((task) => {
          const trimmed = text.trim();
          if (!trimmed) return;
          task.transcript.push({ id: randomUUID(), speaker, text: trimmed, at: now() });
          this.persist(task);
        }),
      requestApproval: (question: string) => this.requestApproval(taskId, question, controller.signal),
      recordProviderCallId: (providerCallId: string) =>
        updateActive((task) => {
          if (!providerCallId || task.providerCallId === providerCallId) return;
          task.providerCallId = providerCallId;
          this.persist(task);
        }),
      end: (options?: EndOptions) => this.endSession(taskId, options ?? {}),
    };
  }

  private requestApproval(taskId: string, question: string, signal: AbortSignal): Promise<ApprovalDecision> {
    const declined: ApprovalDecision = { approved: false, reason: "canceled" };
    const task = this.store.get(taskId);
    if (!task || !isActiveCall(task.status) || signal.aborted || this.shuttingDown) return Promise.resolve(declined);

    const requestedAt = new Date();
    const approval: ApprovalRequest = {
      id: randomUUID(),
      question,
      status: "pending",
      requestedAt: requestedAt.toISOString(),
      expiresAt: new Date(requestedAt.getTime() + this.options.approvalTimeoutMs).toISOString(),
    };
    task.approvals.push(approval);
    this.persist(task);

    return new Promise<ApprovalDecision>((resolve) => {
      const timer = setTimeout(
        () => this.resolveApproval(approval.id, { status: "expired", reason: "expired" }),
        this.options.approvalTimeoutMs,
      );
      this.pendingApprovals.set(approval.id, { taskId, resolve, timer });
      signal.addEventListener(
        "abort",
        () => this.resolveApproval(approval.id, { status: "expired", reason: "canceled" }),
        { once: true },
      );
    });
  }

  private resolveApproval(
    approvalId: string,
    input: { status: Extract<ApprovalStatus, "approved" | "rejected" | "expired">; reason: ApprovalDecisionReason; comment?: string },
  ): void {
    const pending = this.pendingApprovals.get(approvalId);
    if (!pending) return;
    this.pendingApprovals.delete(approvalId);
    clearTimeout(pending.timer);

    const task = this.store.get(pending.taskId);
    const approval = task?.approvals.find((a) => a.id === approvalId);
    if (task && approval && approval.status === "pending") {
      approval.status = input.status;
      approval.resolvedAt = now();
      if (input.comment) {
        approval.userComment = input.comment;
        // Written by the service for every provider, and before resolve() wakes the provider,
        // so the guidance precedes the agent's next line (SPEC-APPROVAL-001 REQ-006).
        if (isActiveCall(task.status)) {
          const text = `${GUIDANCE_PREFIX[task.language]} ${input.comment}`;
          task.transcript.push({ id: randomUUID(), speaker: "system", text, at: now() });
        }
      }
      this.persist(task);
    }
    pending.resolve({
      approved: input.status === "approved",
      comment: input.comment,
      reason: input.reason,
    });
  }

  private endSession(taskId: string, options: EndOptions): void {
    const session = this.sessions.get(taskId);
    if (!session || session.ending) return;
    session.ending = true;
    clearTimeout(session.durationTimer);
    session.controller.abort();
    this.sessions.delete(taskId);

    const task = this.store.get(taskId);
    if (!task || !isActiveCall(task.status)) return;
    task.endedAt = now();
    if (options.error) task.error = options.error;
    this.transition(task, "summarizing");
    void this.summarize(taskId);
  }

  private async summarize(taskId: string): Promise<void> {
    const task = this.store.get(taskId);
    if (!task) return;
    const hadSpeech = task.transcript.some((t) => t.speaker === "callee" || t.speaker === "agent");
    // Answered-but-silent (no media / Realtime) used to become status=completed with empty transcript.
    if (!hadSpeech && !task.error) {
      task.error = task.connectedAt
        ? "상대가 전화를 받았지만 대화가 기록되지 않았습니다. 음성 AI/미디어 스트림 연결을 확인해 주세요."
        : "통화가 연결되지 않았습니다.";
    }
    try {
      task.outcome = await this.brain.summarize(task);
    } catch (error) {
      task.error ??= `요약에 실패했습니다: ${(error as Error).message}`;
    }
    this.transition(task, task.error && !hadSpeech ? "failed" : "completed");
  }

  private finishWithoutCall(task: CallTask, status: "canceled" | "failed"): void {
    const session = this.sessions.get(task.id);
    if (session) {
      session.ending = true;
      clearTimeout(session.durationTimer);
      session.controller.abort();
      this.sessions.delete(task.id);
    }
    task.endedAt = now();
    this.transition(task, status);
  }

  private transition(task: CallTask, to: TaskStatus): void {
    assertTransition(task.status, to);
    task.status = to;
    this.persist(task);
  }

  private persist(task: CallTask): void {
    task.version += 1;
    task.updatedAt = now();
    this.store.save(task);
    this.bus.publish({ type: "task.updated", task });
  }
}
