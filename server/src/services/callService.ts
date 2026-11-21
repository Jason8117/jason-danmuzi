import { randomUUID } from "node:crypto";
import type { CallBrain } from "../brain/types.js";
import { assertTransition } from "../domain/stateMachine.js";
import {
  type ApprovalDecision,
  type ApprovalDecisionReason,
  type ApprovalRequest,
  type ApprovalStatus,
  type CallPlan,
  type CallTask,
  type CallTaskInput,
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
/** Upper bound on how long startup waits for restart-recovery hang-ups. */
const RECOVERY_DEADLINE_MS = 10_000;

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

  create(input: CallTaskInput): CallTask {
    this.assertNotShuttingDown();
    const timestamp = now();
    const task: CallTask = {
      ...input,
      id: randomUUID(),
      version: 0,
      status: "planning",
      transcript: [],
      approvals: [],
      provider: this.provider.name,
      createdAt: timestamp,
      updatedAt: timestamp,
    };
    this.persist(task);
    void this.plan(task.id, input);
    return task;
  }

  /** User reviewed the plan (optionally edited it) and wants the call placed now. */
  async approvePlan(id: string, planOverride?: Partial<CallPlan>): Promise<CallTask> {
    // Check order is fixed: 503 shutting_down -> 404 -> 409 -> 429 (SPEC-LIFECYCLE-001 REQ-001 (d)).
    this.assertNotShuttingDown();
    const task = this.get(id);
    if (task.status !== "awaiting_approval" || !task.plan) {
      throw new ServiceError(409, "invalid_state", "The plan is not waiting for approval");
    }
    this.assertWithinLimits();

    task.plan = { ...task.plan, ...planOverride };
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
    this.resolveApproval(approvalId, {
      status: input.approve ? "approved" : "rejected",
      reason: input.approve ? "user_approved" : "user_rejected",
      comment: input.comment,
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
    try {
      const plan = await this.brain.createPlan(input);
      const task = this.store.get(id);
      if (!task || task.status !== "planning") return;
      task.plan = plan;
      this.transition(task, "awaiting_approval");
    } catch (error) {
      const task = this.store.get(id);
      if (!task || task.status !== "planning") return;
      task.error = `통화 계획을 세우지 못했습니다: ${(error as Error).message}`;
      this.transition(task, "failed");
    }
  }

  private assertNotShuttingDown(): void {
    if (this.shuttingDown) {
      throw new ServiceError(503, "shutting_down", "서버가 종료 중입니다. 잠시 후 다시 시도해 주세요.");
    }
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
      if (input.comment) approval.userComment = input.comment;
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
