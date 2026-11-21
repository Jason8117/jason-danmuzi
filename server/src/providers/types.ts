import type { ApprovalDecision, CallTask, Speaker } from "../domain/types.js";

export interface EndOptions {
  /** Set when the call could not be completed (no answer, busy, provider error). */
  error?: string;
}

/**
 * What a provider can do to a running call. The provider owns audio and
 * dialing; CallService owns state, persistence, approvals and summaries.
 */
export interface CallSession {
  readonly taskId: string;
  /** Latest task snapshot. */
  task(): CallTask;
  /** Aborted when the user hangs up or the call ends for any reason. */
  readonly signal: AbortSignal;
  markRinging(): void;
  markConnected(): void;
  appendTranscript(speaker: Speaker, text: string): void;
  /**
   * Pauses for the user's decision. Resolves with approved=false on rejection,
   * timeout, or hang-up. Optional comment is user guidance for the agent.
   */
  requestApproval(question: string): Promise<ApprovalDecision>;
  /** Reports the provider's external call id as soon as it is known, so it survives a restart. */
  recordProviderCallId(providerCallId: string): void;
  end(options?: EndOptions): void;
}

export interface CallProvider {
  readonly name: "simulated" | "kat";
  /** Starts dialing. Resolves once the call is initiated, not when it ends. */
  start(session: CallSession): Promise<void>;
  /** Hangs up an active call. Must be safe to call more than once. */
  hangup(taskId: string): Promise<void>;
  /**
   * Hangs up a call by its external id without any in-memory session (e.g. after a restart).
   * Optional: providers that never report a call id (simulated) do not implement it.
   */
  terminateByProviderCallId?(providerCallId: string): Promise<void>;
}
