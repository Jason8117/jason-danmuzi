# SPEC-SHELL-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- owner_verdict: PASS-with-debt (owner decision 2026-11-26, iteration 3 at 0.85; D1/D2 fixed; debt per audit_debt). Also owner chose: tonal buttons repainted in SHELL-001 (home_screen [내 정보 입력], follow_up_actions [다시 걸기]) — plan.md file table
- plan_status: plan-audit iteration 3/3 done (0.85 = Tier L threshold; FAIL only on blocking text defects D1/D2, both fixed after the report; auditor recommends PASS-with-debt; owner decision pending). Reports review-1..3.
- audit_debt (iteration 3, optional): D4 fixed, D5 header/citation fixed, D6 router-argument signature fixed, D7 R-12 fixed; open: D9 AC-018 grep does not check `goBranch(`; REQ-008/REQ-012/REQ-021 mix GEARS forms; D8 ASSIST plan openTask wording (fix after ASSIST iteration 3)
- spec_version: 0.3.1 (iteration-2 fixes)
- spec_version_0.3.0: (owner decision 2026-11-26: split tokens/font/status chip into SPEC-DESIGN-001, move shell to Tier L)
- spec_version_history: 0.1.0 (3-tab), 0.2.0 (design-review 5-slot)
- plan_complete_at: 2026-11-26
- base_sha: c2e732d (plus uncommitted planning docs; run-phase records run_start_sha after SPEC-MODULE-001 and SPEC-DESIGN-001 complete)
- tier: L (about 40 files), harness: standard, methodology: tdd
- artifacts: spec.md, plan.md, acceptance.md, design.md, research.md (+ research/go_router_spike_test.dart.txt, audit_branch_spike_test.dart.txt, open_task_spike_test.dart.txt), progress.md
- counts: 21 REQ / 21 AC
- depends_on: SPEC-MODULE-001, SPEC-DESIGN-001
- open_decisions: OD-1, OD-3 decided; OD-2, OD-4 ~ OD-8 DEFAULT (pending owner review)
- intended test changes: accessibility_test.dart home-order block (:614-619) and plan_card_test.dart back-navigation block (:194-196) — AC-021 table (research R2)
- verified at plan time: go_router 18.1.4 cross-branch behaviour by spike (research R1, cases A-H incl. G assertion and G2/G3 alternatives; goBranch cases X1-X6 and openTask cases Y1-Y3 re-run 2026-11-26, each with --plain-name); awaiting_approval = pre-call plan approval (stateMachine.ts:4); pendingApprovalsProvider covers every task with task.pendingApproval regardless of status (calls_controller.dart:115-120); CallTask fields (call_models.dart:262-278)
- audit iteration 1 must-fix mapping: D1 -> research R2 + AC-021 + design D2.3; D2 -> design D3 + AC-013; D3 -> SPEC-DESIGN-001 §A.2 + design D4; D4 -> design D2.2; D5 -> research R1 + design D1.2; D6 -> SPEC-DESIGN-001; D7 -> Tier L + split; D8 -> this file; D10 -> design D5 + REQ-016
- note: app + packages; no server change

## §E.2 Run-phase Evidence

_<pending run-phase>_

## §E.3 Run-phase Audit-Ready Signal

_<pending run-phase>_

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
