# SPEC-DESIGN-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- owner_verdict: PASS-with-debt (owner decision 2026-11-26, iteration 3 PASS 0.90). N6 tonal-button colour handed to SPEC-SHELL-001
- plan_status: plan-audit iteration 3/3 PASS 0.90 (report .moai/reports/plan-audit/SPEC-DESIGN-001-review-3.md; scratch run +80 all passed); auditor recommends PASS-with-debt; N3 residue, N7, N8, D14 fixed in docs after the report
- audit_debt (optional): N4 dark neutral chip bg equals card colour (no pill outline); N5 dark container roles outside the §A.3 table keep fromSeed values; N6 FilledButton.tonal takes the filledButtonTheme #635BFF background (home_screen.dart:337 '내 정보 입력', follow_up_actions.dart:88 '다시 걸기' now look like primary buttons; contrast 4.70 ok) — owner to accept or hand to SHELL-001
- spec_version: 0.2.1
- plan_complete_at: 2026-11-26
- origin: split from SPEC-SHELL-001 0.2.0 REQ-013 per plan-audit iteration 1 tier recommendation (owner chose split, 2026-11-26)
- base_sha: c2e732d (plus uncommitted planning docs; run-phase records run_start_sha after SPEC-MODULE-001 completes)
- tier: M (16 files), harness: standard, methodology: tdd
- artifacts: spec.md, plan.md, acceptance.md, progress.md
- counts: 11 REQ / 14 AC (AC-001..AC-013 with AC-004a/b)
- depends_on: SPEC-MODULE-001
- open_decisions: OD-1 decided (text colours from 06 §3.2/§3.3); OD-2 ~ OD-4 DEFAULT (pending owner review)
- intended test change: app/test/theme_test.dart:29 seed value only; new app tests font_overflow_test.dart, design_contrast_test.dart — AC-011
- audit facts: primary #635BFF as text fails a11y (home TextButton 4.43, approval OutlinedButton 4.28) -> primary #4F46E5, #635BFF only as filled-button bg (white 4.7, recomputed); AppCard is Card elevation 0 (common.dart:61, app_theme.dart:37); card colour surfaceContainerLow (app_theme.dart:39) -> surfaceContainerLowest
- verified at plan time: status_chip.dart labels and pulsing dot (needsApproval -> '승인 대기', status.label otherwise; dot when isLiveCall || needsApproval); TaskStatus labels (call_models.dart); CardTone enum (app_theme.dart:66); seed + fromSeed (app_theme.dart:6, :24); theme_test.dart:29 asserts the old seed
- note: kolbi_ui plus one app/lib line (hang-up button foregroundColor onError, REQ-009 exception); kolbi_core, server unchanged

## §E.2 Run-phase Evidence

_<pending run-phase>_

## §E.3 Run-phase Audit-Ready Signal

_<pending run-phase>_

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
