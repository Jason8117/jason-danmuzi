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

export interface ApprovalRequest {
  id: string;
  question: string;
  status: ApprovalStatus;
  requestedAt: string;
  resolvedAt?: string;
  expiresAt: string;
}

export type OutcomeResult = "success" | "partial" | "failed";

export interface CallOutcome {
  result: OutcomeResult;
  summary: string;
  keyFacts: string[];
  followUps: string[];
}

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
  provider: "simulated" | "twilio";
  createdAt: string;
  updatedAt: string;
  startedAt?: string;
  connectedAt?: string;
  endedAt?: string;
}

export const ACTIVE_CALL_STATUSES: readonly TaskStatus[] = ["dialing", "ringing", "in_progress"];
export const TERMINAL_STATUSES: readonly TaskStatus[] = ["completed", "failed", "canceled"];

export function isActiveCall(status: TaskStatus): boolean {
  return ACTIVE_CALL_STATUSES.includes(status);
}

export function isTerminal(status: TaskStatus): boolean {
  return TERMINAL_STATUSES.includes(status);
}
