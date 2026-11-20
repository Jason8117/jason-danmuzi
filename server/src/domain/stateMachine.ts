import type { TaskStatus } from "./types.js";

const TRANSITIONS: Record<TaskStatus, readonly TaskStatus[]> = {
  planning: ["awaiting_approval", "failed", "canceled"],
  awaiting_approval: ["dialing", "canceled"],
  dialing: ["ringing", "in_progress", "summarizing", "failed", "canceled"],
  ringing: ["in_progress", "summarizing", "failed", "canceled"],
  in_progress: ["summarizing", "failed", "canceled"],
  summarizing: ["completed", "failed"],
  completed: [],
  failed: [],
  canceled: [],
};

export class InvalidTransitionError extends Error {
  constructor(
    readonly from: TaskStatus,
    readonly to: TaskStatus,
  ) {
    super(`Cannot move task from "${from}" to "${to}"`);
  }
}

export function canTransition(from: TaskStatus, to: TaskStatus): boolean {
  return TRANSITIONS[from].includes(to);
}

export function assertTransition(from: TaskStatus, to: TaskStatus): void {
  if (!canTransition(from, to)) throw new InvalidTransitionError(from, to);
}
