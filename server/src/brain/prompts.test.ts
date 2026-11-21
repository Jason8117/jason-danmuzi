import { describe, expect, it } from "vitest";
import type { CallTask } from "../domain/types.js";
import { buildAgentInstructions } from "./prompts.js";

const AT = "2026-11-21T10:00:00.000Z";

const task: CallTask = {
  id: "t-1",
  version: 1,
  status: "queued",
  targetName: "라 파스타",
  phoneNumber: "+8221234567",
  goal: "영업시간과 주말 영업 여부 확인",
  language: "ko",
  requesterName: "김민수",
  transcript: [],
  approvals: [],
  provider: "simulated",
  createdAt: AT,
  updatedAt: AT,
};

// Live-call fix: the agent hung up while the goal's key fact (opening hours) was still unconfirmed,
// after fragmentary speech recognition. Assertions pin stable keywords, not the whole prompt.
describe("buildAgentInstructions end_call rules (SPEC-ARCH-001 live-call fix)", () => {
  const prompt = buildAgentInstructions(task);

  it("forbids end_call while a key fact is unconfirmed only because the callee was hard to understand", () => {
    expect(prompt).toMatch(/never call end_call while a key fact the goal needs is still unconfirmed/i);
    expect(prompt).toMatch(/hard to understand/i);
  });

  it("requires one short, polite re-ask for the single missing fact first", () => {
    expect(prompt).toMatch(/ask once more/i);
    expect(prompt).toMatch(/repeat or confirm/i);
  });

  it("lists the only three end conditions, including two failed re-asks", () => {
    expect(prompt).toMatch(/key facts are confirmed/i);
    expect(prompt).toMatch(/clearly refuses or cannot help/i);
    expect(prompt).toMatch(/re-asked for the same missing fact at least twice/i);
  });

  it("treats fragmentary or garbled callee text as a speech-recognition artifact", () => {
    expect(prompt).toMatch(/fragmentary or garbled/i);
    expect(prompt).toMatch(/speech-recognition artifact/i);
    expect(prompt).toMatch(/re-ask instead of/i);
  });

  it("keeps the read-back and thanks before end_call", () => {
    expect(prompt).toMatch(/read the key facts back, thank them, then call end_call/i);
  });
});
