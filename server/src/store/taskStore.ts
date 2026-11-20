import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import type { CallTask } from "../domain/types.js";

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
  private writing: Promise<void> = Promise.resolve();

  private constructor(private readonly path: string) {
    super();
  }

  static async open(path: string): Promise<JsonFileTaskStore> {
    const store = new JsonFileTaskStore(path);
    try {
      const raw = await readFile(path, "utf8");
      for (const task of JSON.parse(raw) as CallTask[]) store.tasks.set(task.id, task);
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
    const snapshot = JSON.stringify(this.list(), null, 2);
    this.writing = this.writing.then(async () => {
      await mkdir(dirname(this.path), { recursive: true });
      const tmp = `${this.path}.tmp`;
      await writeFile(tmp, snapshot, "utf8");
      await rename(tmp, this.path);
    });
    await this.writing;
  }

  private schedule(): void {
    if (this.timer) return;
    this.timer = setTimeout(() => void this.flush(), 300);
  }
}
