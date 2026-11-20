import { EventEmitter } from "node:events";
import type { CallTask } from "../domain/types.js";

/**
 * Every change is broadcast as a full task snapshot. Clients replace their copy
 * instead of applying diffs, which keeps them correct after missed messages.
 */
export type ServerEvent =
  | { type: "task.updated"; task: CallTask }
  | { type: "task.deleted"; taskId: string };

export class EventBus {
  private readonly emitter = new EventEmitter().setMaxListeners(0);

  publish(event: ServerEvent): void {
    this.emitter.emit("event", event);
  }

  subscribe(listener: (event: ServerEvent) => void): () => void {
    this.emitter.on("event", listener);
    return () => this.emitter.off("event", listener);
  }
}
