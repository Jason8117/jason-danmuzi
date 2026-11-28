export type Language = "ko" | "en";

export type TaskStatus =
  | "planning"
  | "awaiting_approval"
  | "dialing"
  | "ringing"
  | "in_progress"
  | "summarizing"
  | "completed"
  | "failed"
  | "canceled";

export type Speaker = "agent" | "callee" | "system";

export interface TranscriptEntry {
  id: string;
  speaker: Speaker;
  text: string;
  at: string;
}

export interface CallPlan {
  openingLine: string;
  steps: string[];
  questionsToAsk: string[];
  /** Decisions the agent must not make alone; it pauses the call and asks the user. */
  approvalPoints: string[];
  fallback: string;
}

export type ApprovalStatus = "pending" | "approved" | "rejected" | "expired";

export type ApprovalDecisionReason = "user_approved" | "user_rejected" | "expired" | "canceled";

/** Result of a mid-call approval pause (user decision or timeout). */
export interface ApprovalDecision {
  approved: boolean;
  comment?: string;
  reason: ApprovalDecisionReason;
}

export interface ApprovalRequest {
  id: string;
  question: string;
  status: ApprovalStatus;
  requestedAt: string;
  resolvedAt?: string;
  expiresAt: string;
  /** Optional guidance the user attached when approving or rejecting. */
  userComment?: string;
}

/** `unverified`: a summary no LLM checked against the goal, so it must not claim success (SPEC-OUTCOME-001). */
export type OutcomeResult = "success" | "partial" | "failed" | "unverified";

/** How the outcome was produced. The server attaches it; the LLM is never asked for it. */
export type OutcomeSource = "llm" | "heuristic";

export interface CallOutcome {
  result: OutcomeResult;
  /** Always set on new outcomes. Optional only because tasks saved before this field existed lack it. */
  source?: OutcomeSource;
  summary: string;
  keyFacts: string[];
  followUps: string[];
  /** A date and time the call confirmed. Only on LLM `success`/`partial` outcomes; absent everywhere else (SPEC-FOLLOWUP-001). */
  appointment?: Appointment;
}

/** `startsAt`/`endsAt` are ISO 8601 date-times with an explicit offset (`Z` or `±hh:mm`). */
export interface Appointment {
  title: string;
  startsAt: string;
  endsAt?: string;
}

/**
 * Which call provider placed a task ("simulated", "kat", ...). A plain string so a new provider needs no
 * domain change; stored tasks keep whatever id they were created with.
 */
export type ProviderId = string;

export interface CallTaskInput {
  targetName: string;
  phoneNumber: string;
  goal: string;
  context?: string;
  language: Language;
  requesterName: string;
  callbackNumber?: string;
}

export interface CallTask extends CallTaskInput {
  id: string;
  /** Increments on every change. HTTP responses and stream events can arrive out of order; clients keep the highest. */
  version: number;
  status: TaskStatus;
  plan?: CallPlan;
  transcript: TranscriptEntry[];
  approvals: ApprovalRequest[];
  outcome?: CallOutcome;
  error?: string;
  provider: ProviderId;
  /** The provider's own id for the placed call (KAT callId). Lets a restarted server hang the call up. Absent for simulated calls and tasks saved before this field existed. */
  providerCallId?: string;
  createdAt: string;
  updatedAt: string;
  startedAt?: string;
  connectedAt?: string;
  endedAt?: string;
  /** The user tapped the plan card's single start button; the server places the call once planning finishes (SPEC-INTAKE-001). */
  autoStart?: boolean;
  /** Why the automatic start did not happen; cleared by a later successful manual plan approval. */
  autoStartBlocked?: AutoStartBlocked;
}

export interface AutoStartBlocked {
  code: string;
  message: string;
}

/** How a one-line request was interpreted: by the LLM or by the deterministic rules. */
export type IntakeSource = "llm" | "heuristic";

/** What the brain extracts from a (number-masked) one-line request. It never carries a phone number (REQ-007 (b)). */
export interface IntakeContent {
  targetName: string | null;
  goal: string;
  conditions: string[];
  context: string | null;
  source: IntakeSource;
  /** The place search term the brain proposes (SPEC-PLACE-001 REQ-023); absent when it has none. */
  placeQuery?: string;
}

/** The plan-card draft returned by POST /v1/intake. No task is created (SPEC-INTAKE-001 REQ-001, REQ-003). */
export interface IntakeDraft {
  targetName: string | null;
  /** E.164, taken only from the request text or from a counterparty who answered before. */
  phoneNumber: string | null;
  goal: string;
  conditions: string[];
  context: string | null;
  language: Language;
}

export type IntakeMissingField = "targetName" | "phoneNumber" | "goal";

export interface IntakeResult {
  draft: IntakeDraft;
  missing: IntakeMissingField[];
  phoneSource: "text" | "history" | null;
  numberIssue: "blocked" | null;
  source: IntakeSource;
  /** Place name or category only, for place search; never stored or logged (SPEC-PLACE-001 REQ-023, REQ-024). */
  placeQuery: string | null;
}

/** Execution options for task creation, kept apart from the task input itself. */
export interface CreateTaskOptions {
  autoStart?: boolean;
}

export const ACTIVE_CALL_STATUSES: readonly TaskStatus[] = ["dialing", "ringing", "in_progress"];
export const TERMINAL_STATUSES: readonly TaskStatus[] = ["completed", "failed", "canceled"];

export function isActiveCall(status: TaskStatus): boolean {
  return ACTIVE_CALL_STATUSES.includes(status);
}

export function isTerminal(status: TaskStatus): boolean {
  return TERMINAL_STATUSES.includes(status);
}
