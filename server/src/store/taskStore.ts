import * as nodeFs from "node:fs/promises";
import { dirname } from "node:path";
import type { CallTask } from "../domain/types.js";
import { logger as defaultLogger, type Logger } from "../logger.js";

/** The file system calls the store needs; injectable so tests can simulate disk failures. */
export interface StoreFs {
  readFile(path: string, encoding: "utf8"): Promise<string>;
  writeFile(path: string, data: string, encoding: "utf8"): Promise<void>;
  rename(from: string, to: string): Promise<void>;
  mkdir(path: string, options: { recursive: true }): Promise<unknown>;
}

export interface JsonFileTaskStoreOptions {
  fs?: StoreFs;
  logger?: Logger;
  debounceMs?: number;
}

export interface TaskStore {
  list(): CallTask[];
  get(id: string): CallTask | undefined;
  save(task: CallTask): void;
  delete(id: string): boolean;
  flush(): Promise<void>;
}

export class InMemoryTaskStore implements TaskStore {
  protected readonly tasks = new Map<string, CallTask>();

  list(): CallTask[] {
    return [...this.tasks.values()].sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }

  get(id: string): CallTask | undefined {
    return this.tasks.get(id);
  }

  save(task: CallTask): void {
    this.tasks.set(task.id, task);
  }

  delete(id: string): boolean {
    return this.tasks.delete(id);
  }

  async flush(): Promise<void> {}
}

/**
 * Keeps tasks in memory and persists them to a JSON file with a debounced,
 * atomic write (temp file + rename), so a crash never leaves a half-written file.
 */
export class JsonFileTaskStore extends InMemoryTaskStore {
  private timer: NodeJS.Timeout | undefined;
  /** Serializes writes. Never rejects, so one failed write cannot fail the next one. */
  private writing: Promise<void> = Promise.resolve();
  private readonly fs: StoreFs;
  private readonly logger: Logger;
  private readonly debounceMs: number;

  private constructor(
    private readonly path: string,
    options: JsonFileTaskStoreOptions,
  ) {
    super();
    this.fs = options.fs ?? nodeFs;
    this.logger = options.logger ?? defaultLogger;
    this.debounceMs = options.debounceMs ?? 300;
  }

  static async open(path: string, options: JsonFileTaskStoreOptions = {}): Promise<JsonFileTaskStore> {
    const store = new JsonFileTaskStore(path, options);
    try {
      const raw = await store.fs.readFile(path, "utf8");
      for (const task of JSON.parse(raw) as CallTask[]) store.tasks.set(task.id, { ...task, version: task.version ?? 0 });
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
    return store;
  }

  override save(task: CallTask): void {
    super.save(task);
    this.schedule();
  }

  override delete(id: string): boolean {
    const deleted = super.delete(id);
    if (deleted) this.schedule();
    return deleted;
  }

  override async flush(): Promise<void> {
    clearTimeout(this.timer);
    this.timer = undefined;
    await this.write();
  }

  /** Queues one write; the snapshot is taken when the write starts, so it holds the latest state. */
  private write(): Promise<void> {
    const run = this.writing.then(async () => {
      const snapshot = JSON.stringify(this.list(), null, 2);
      await this.fs.mkdir(dirname(this.path), { recursive: true });
      const tmp = `${this.path}.tmp`;
      await this.fs.writeFile(tmp, snapshot, "utf8");
      await this.fs.rename(tmp, this.path);
    });
    this.writing = run.catch(() => {});
    return run;
  }

  private schedule(): void {
    if (this.timer) return;
    this.timer = setTimeout(() => void this.flush().catch(() => {}), this.debounceMs);
  }
}
