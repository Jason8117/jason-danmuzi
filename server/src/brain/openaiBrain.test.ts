import { afterEach, describe, expect, it, vi } from "vitest";
import type { CallTask, CallTaskInput, TranscriptEntry } from "../domain/types.js";
import { HeuristicBrain } from "./heuristicBrain.js";
import { OpenAiBrain } from "./openaiBrain.js";

const API_KEY = "sk-test-DO-NOT-LOG-1234";
const AT = "2026-11-21T10:00:00.000Z";
const CALLEE_SENTENCE = "그 시간엔 자리가 없습니다.";
const RAW_CONTENT = `not json: ${CALLEE_SENTENCE}`;

function recordingLogger() {
  const warns: { obj: object; msg: string }[] = [];
  return { warns, warn: (obj: object, msg: string) => warns.push({ obj, msg }) };
}

function line(id: string, speaker: TranscriptEntry["speaker"], text: string): TranscriptEntry {
  return { id, speaker, text, at: AT };
}

const input: CallTaskInput = {
  targetName: "라 파스타",
  phoneNumber: "+8221234567",
  goal: "금요일 저녁 7시 2명 예약",
  language: "ko",
  requesterName: "김민수",
};

const task: CallTask = {
  ...input,
  id: "t-1",
  version: 1,
  status: "summarizing",
  transcript: [line("t1", "callee", "네, 라 파스타입니다."), line("t2", "agent", "7시 예약 되나요?"), line("t3", "callee", CALLEE_SENTENCE)],
  approvals: [],
  provider: "simulated",
  createdAt: AT,
  updatedAt: AT,
  connectedAt: AT,
};

function completion(content: string | undefined, status = 200): Response {
  const message = content === undefined ? {} : { content };
  return new Response(JSON.stringify({ choices: [{ message }] }), { status });
}

function stubFetch(impl: () => Promise<Response>) {
  const fetchMock = vi.fn(impl);
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}

function setup() {
  const log = recordingLogger();
  return { log, brain: new OpenAiBrain(API_KEY, "gpt-test", log) };
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("OpenAiBrain (SPEC-OUTCOME-001)", () => {
  // AC-005 / REQ-001, REQ-006, REQ-009
  it.each([
    {
      name: "500 response",
      fetch: async () => new Response("upstream body: internal secret", { status: 500 }),
      reason: "http_status",
      status: 500,
    },
    {
      name: "timeout",
      fetch: async () => {
        throw new DOMException("The operation was aborted due to timeout", "TimeoutError");
      },
      reason: "timeout",
    },
    { name: "missing content", fetch: async () => completion(undefined), reason: "empty_content" },
    { name: "content is not JSON", fetch: async () => completion(RAW_CONTENT), reason: "invalid_json" },
    {
      name: "schema mismatch",
      fetch: async () =>
        completion(JSON.stringify({ result: "great", summary: CALLEE_SENTENCE, keyFacts: [], followUps: [] })),
      reason: "schema_mismatch",
    },
    {
      name: "network error",
      fetch: async () => {
        throw new TypeError("fetch failed");
      },
      reason: "network",
    },
  ])("falls back visibly when the summary LLM fails ($name)", async ({ fetch, reason, status }) => {
    stubFetch(fetch);
    const { brain, log } = setup();

    const outcome = await brain.summarize(task);

    expect(outcome.source).toBe("heuristic");
    expect(outcome.result).not.toBe("success");
    expect(log.warns).toHaveLength(1);
    const [warn] = log.warns;
    expect(warn!.obj).toMatchObject({ op: "summarize", taskId: "t-1", reason });
    if (status !== undefined) expect(warn!.obj).toMatchObject({ status });

    const logged = JSON.stringify(warn!.obj) + warn!.msg;
    expect(logged).not.toContain(API_KEY);
    expect(logged).not.toContain(CALLEE_SENTENCE);
    expect(logged).not.toContain("라 파스타입니다");
    expect(logged).not.toContain(RAW_CONTENT);
    expect(logged).not.toContain("upstream body");
    expect(logged).not.toContain("Unexpected token");
    expect(logged).not.toContain("is not valid JSON");
  });

  // AC-001, AC-006 / REQ-001, REQ-007
  it("a validated LLM outcome is marked as llm", async () => {
    const llm = { result: "success", summary: "7시 예약 완료", keyFacts: ["7시"], followUps: [] };
    stubFetch(async () => completion(JSON.stringify(llm)));
    const { brain, log } = setup();

    const outcome = await brain.summarize(task);

    expect(outcome).toEqual({ ...llm, source: "llm" });
    expect(log.warns).toHaveLength(0);

    const silent = await brain.summarize({ ...task, transcript: [] });
    expect(silent.source).toBe("llm");
  });

  // AC-007 / REQ-008, REQ-009
  it("logs which operation fell back during planning", async () => {
    stubFetch(async () => new Response("nope", { status: 500 }));
    const { brain, log } = setup();

    const plan = await brain.createPlan(input);

    expect(plan).toEqual(await new HeuristicBrain().createPlan(input));
    expect(log.warns).toHaveLength(1);
    expect(log.warns[0]!.obj).toMatchObject({ op: "plan", reason: "http_status", status: 500 });
    expect(JSON.stringify(log.warns[0]!.obj) + log.warns[0]!.msg).not.toContain(API_KEY);
  });

  // AC-008 / REQ-010
  it("the LLM schema only accepts the three LLM result values", async () => {
    stubFetch(async () =>
      completion(JSON.stringify({ result: "unverified", summary: "요약", keyFacts: [], followUps: [] })),
    );
    const { brain, log } = setup();

    const outcome = await brain.summarize(task);

    expect(outcome.source).toBe("heuristic");
    expect(log.warns).toHaveLength(1);
    expect(log.warns[0]!.obj).toMatchObject({ op: "summarize", reason: "schema_mismatch" });
  });
});
