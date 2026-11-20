# Project Interview

> Revised 2026-11-20 after the project owner changed the product direction (see "Direction Update"). The Stage A/B answers below were re-aligned to it. Earlier answers that conflict were replaced, not kept.

## Direction Update (owner statement, 2026-11-20)

1. Name: the app is renamed **콜비 (Kolbi)**. Former name: CallMate. The rename is applied to documentation only for now; code, package names, and paths (`callmate`, `callmate-server`, `callmate_dart`, ...) are unchanged until a separate rename task.
2. Purpose: act for the customer toward an enterprise's customer center and COMPLETE the business task (not merely place a call). A personal-assistant agent in the spirit of Pickle: it finishes real errands end to end on the user's behalf.
3. Platform role: Kolbi is the OUTBOUND-side agent of a hub platform that connects to the enterprise INBOUND agent being built in another project. The hub provides authentication, security, and routing between the two sides. The hub and the inbound agent are NOT in this repository.
4. Distribution: must be usable as an add-on or SDK so other apps can integrate it and build on it.
5. Hub auth and routing approach: standard protocols — A2A, MCP, OAuth, JWT, Ory Hydra.

Status of these items in this repository: none of items 3-5 is implemented. The only implemented parts are the Flutter app and the Fastify server described in the codebase analysis. `docs/04_SDK_ADDON_PLATFORM_ARCHITECTURE.md` and `docs/05_...` already propose an SDK/add-on platform (unimplemented); no document in the repo covers the hub, the enterprise inbound agent, A2A, MCP, OAuth, JWT, or Ory Hydra (verified by grep of docs/PRODUCT_ROADMAP.md, docs/04, docs/05 only; other docs were not searched).

## Stage A Round 1: Ownership, Purpose, and Goal
Question: From which angle should the documentation be written (current state and direction)?
Answer: Actively developed product. Document the current implemented state, and separately the target direction; mark every target item as not implemented.
Domain: ai-agent task-completion assistant (mobile app + backend) (auto-populated from codebase analysis, direction per owner statement)
Goal: Kolbi acts for a customer toward enterprise customer centers and completes the business task end to end, as the outbound agent of a hub platform, shipped both as a standalone app and as an add-on/SDK for other apps.

## Stage A Round 2: Constraints and Non-Goals
Question: Which constraints and non-goals should the documentation record?
Answer: Only the constraints confirmed in code (no additional constraints supplied).
Constraints:
- KAT Cloud is reachable only from Korean IPs (a Korea-reachable HTTPS tunnel is needed for PUBLIC_BASE_URL).
- Emergency and short codes (112, 119, 113, 114, 117, 118, 122, 125, 182) are blocked from dialing.
- Call limits: MAX_CONCURRENT_CALLS=2, MAX_CALLS_PER_DAY=30, MAX_CALL_DURATION_SEC=600, APPROVAL_TIMEOUT_SEC=90 (defaults).
- Persistence is a single JSON file (no database).
- No push notifications; mid-call approval alerts arrive only while the app is open and connected to the WebSocket.
- Real-call mode requires API_TOKEN.
- Authentication today is one shared Bearer API_TOKEN; there are no accounts, tenants, OAuth, JWT, or A2A/MCP endpoints.

## Stage A Round 3: Scope, Boundaries, and Documentation Priority
Question: What must the documentation capture most accurately, and where are the scope boundaries?
Answer: Architecture and module boundaries; scope = the implemented app + server, plus a clearly separated "target direction" section.
Scope:
- In scope (current state): app/ (Flutter) and server/ (Fastify/TypeScript) as implemented.
- In scope (target direction, labeled "not implemented"): Kolbi's purpose (task completion), its role as the outbound agent of the hub, the SDK/add-on distribution goal, and the intended standard protocols (A2A, MCP, OAuth, JWT, Ory Hydra) as stated by the owner.
- Out of scope: the hub platform and the enterprise inbound agent themselves (other project); detailed hub/protocol design; any claim about how Kolbi will map onto A2A/MCP/OAuth that the owner has not stated.
- Open question (not decided, do not invent an answer): whether enterprise connections will run over phone voice, over hub agent-to-agent channels, or both.
Documentation priority: architecture and module boundaries (server http -> services -> brain/providers/store; Flutter feature-first layers).

## Stage B Round 4: Verification, Surfaces, and Sharing
Verification: server `npm test` (vitest) and `npm run typecheck`; app `flutter analyze` and `flutter test`. No CI runs these (only label-sync workflow exists).
UI surface: has-ui (Flutter app); the server is headless (REST, WebSocket, webhooks).
External systems: OpenAI (Chat Completions, Realtime WebSocket), KAT Cloud (outbound 070 dialing, status webhook, media stream). Target (not implemented): the hub platform and enterprise inbound agent.
Team sharing: solo

## Notes for documentation writers
- Use the name 콜비 (Kolbi) in prose; mention "구 CallMate" once, and note that code and package identifiers still use `callmate`.
- Keep "현재 구현" and "목표 방향" in separate, clearly labeled sections. Never describe A2A, MCP, OAuth, JWT, Ory Hydra, the hub, or the SDK as implemented.
- Do not describe the real KAT + Realtime path as production-proven; it is environment-dependent.
- Do not quote or read server/data/ (contains real task data, phone numbers).
- .env.example omits DATA_FILE and SIMULATION_SPEED although server/src/config.ts reads both (KAT_API_BASE_URL is present but commented out).
- Roadmap Step A1 (mid-call approval comments) is implemented; the rest of docs/01-05 and PRODUCT_ROADMAP.md is proposal only.
- Facts from the Explore analysis were spot-verified by the orchestrator and plan-auditor iteration 1; line counts and local data state were not independently verified.
